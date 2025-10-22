#!/bin/bash
# ===========================================================
#  Automated Arch Linux Installation Script (UEFI)
#  Author: Technical
# ===========================================================

set -euo pipefail
set -x  # Debug mode

# --- CONFIGURATION -----------------------------------------------------------
DISK="/dev/nvme0n1"   # Default target disk (NVMe). Change here if needed.

# --- USER INPUT --------------------------------------------------------------
read -rp "Enter SWAP partition size (in MiB, 1024 MiB = 1 GiB): " SWAP_SIZE
read -rp "Enter ROOT partition size (in MiB, or press Enter to use remaining space): " ROOT_SIZE
ROOT_SIZE=${ROOT_SIZE:-100%}

read -rp "Enter hostname: " HOSTNAME
read -rp "Enter username: " USERNAME
read -rsp "Enter password for user '$USERNAME': " USERPASS
echo ""
read -rsp "Enter password for root: " ROOTPASS
echo ""
read -rp "Enter timezone: " TIMEZONE
read -rp "Enter locale: " LOCALE
# -----------------------------------------------------------------------------

echo ">>> WARNING: ALL DATA on $DISK will be ERASED!"
read -p "Are you sure you want to continue? (y/N): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 1

# --- STEP 0: Update keyring ---------------------------------------------------
echo ">>> Updating Arch Linux keyring..."
pacman -Sy --noconfirm archlinux-keyring

# --- STEP 1: Partition the disk (GPT) ----------------------------------------
EFI_END=513
SWAP_START=$EFI_END
SWAP_END=$((SWAP_START + SWAP_SIZE))
ROOT_START=$SWAP_END

echo ""
echo "Partition layout preview:"
echo "EFI  : 1–513 MiB"
echo "SWAP : ${SWAP_START}–${SWAP_END} MiB"
echo "ROOT : ${ROOT_START}–$ROOT_SIZE"
echo ""
read -p "Proceed with these partitions? (y/N): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 1

echo ">>> Creating partitions on $DISK..."
parted -s "$DISK" mklabel gpt \
  mkpart ESP fat32 1MiB ${EFI_END}MiB \
  set 1 esp on \
  mkpart primary linux-swap ${SWAP_START}MiB ${SWAP_END}MiB \
  mkpart primary ext4 ${ROOT_START}MiB $ROOT_SIZE

# --- STEP 2: Format partitions ------------------------------------------------
echo ">>> Formatting partitions..."
mkfs.fat -F32 ${DISK}p1
mkswap ${DISK}p2
mkfs.ext4 ${DISK}p3

# --- STEP 3: Mount partitions -------------------------------------------------
echo ">>> Mounting partitions..."
mount ${DISK}p3 /mnt
swapon ${DISK}p2
mkdir -p /mnt/boot/efi
mount ${DISK}p1 /mnt/boot/efi

# --- STEP 4: Install base system ---------------------------------------------
echo ">>> Installing base system..."
pacstrap /mnt base linux linux-firmware vim nano sudo \
  grub efibootmgr networkmanager gnome firefox

# --- STEP 5: Generate fstab ---------------------------------------------------
echo ">>> Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# --- STEP 6: Create post-installation script ---------------------------------
echo ">>> Creating post-installation configuration script..."
cat > /mnt/root/post-install.sh <<EOF
#!/bin/bash
set -euo pipefail
set -x

# --- Timezone & Clock ---
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# --- Locale ---
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# --- Hostname & Hosts ---
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOT
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOT

# --- Root password ---
echo "root:$ROOTPASS" | chpasswd

# --- GRUB Installation (UEFI) ---
mkdir -p /boot/efi
mount ${DISK}p1 /boot/efi
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# --- Enable essential services ---
systemctl enable NetworkManager
systemctl enable gdm

# --- Create normal user ---
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
EOF

chmod +x /mnt/root/post-install.sh

# --- STEP 7: Enter chroot and finalize installation --------------------------
echo ">>> Entering chroot to finalize setup..."
arch-chroot /mnt /root/post-install.sh

# --- STEP 8: Update the new system -------------------------------------------
echo ">>> Updating installed system..."
arch-chroot /mnt pacman -Syu --noconfirm

# --- STEP 9: Cleanup ----------------------------------------------------------
echo ">>> Cleaning up..."
swapoff -a || true
umount -R /mnt || true
echo ">>> Installation complete! Rebooting in 5 seconds..."
sleep 5 && reboot
