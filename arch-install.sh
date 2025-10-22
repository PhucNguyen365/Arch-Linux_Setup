#!/bin/bash
# ===========================================================
#  Automated Arch Linux Installation Script (UEFI)
#  Author: Technical (Interactive Secure Version)
# ===========================================================

set -euo pipefail
set -x  # Debug mode

# --- USER INPUT SECTION ------------------------------------------------------

read -rp "Enter target disk (e.g., /dev/nvme0n1 or /dev/sda): " DISK
read -rp "Enter EFI partition size (e.g., 512MiB): " EFI_SIZE
read -rp "Enter SWAP partition size (e.g., 2GiB): " SWAP_SIZE
read -rp "Enter hostname for this system: " HOSTNAME
read -rp "Enter username for regular user: " USERNAME
read -rsp "Enter password for user '$USERNAME': " USERPASS
echo ""
read -rsp "Enter password for root: " ROOTPASS
echo ""
read -rp "Enter timezone (e.g., Asia/Ho_Chi_Minh): " TIMEZONE
read -rp "Enter locale (e.g., en_US.UTF-8): " LOCALE

# -----------------------------------------------------------------------------

echo ">>> WARNING: ALL DATA on $DISK will be ERASED!"
read -p "Are you sure you want to continue? (y/N): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 1

# --- STEP 0: Update keyring (for old ISO compatibility) ----------------------
echo ">>> Updating Arch Linux keyring..."
pacman -Sy --noconfirm archlinux-keyring

# --- STEP 1: Partition the disk (GPT) ----------------------------------------
echo ">>> Partitioning $DISK ..."
parted -s "$DISK" mklabel gpt \
  mkpart ESP fat32 1MiB $EFI_SIZE \
  set 1 esp on \
  mkpart primary linux-swap $EFI_SIZE $(echo "$EFI_SIZE" | sed 's/MiB//' | awk '{print $1+2048}')MiB \
  mkpart primary ext4 2561MiB 100%

# --- STEP 2: Format partitions -----------------------------------------------
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
  grub efibootmgr networkmanager gnome

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

# --- STEP 8: Update the newly installed system -------------------------------
echo ">>> Updating the new Arch Linux installation..."
arch-chroot /mnt pacman -Syu --noconfirm

# --- STEP 9: Cleanup and reboot ----------------------------------------------
echo ">>> Cleaning up..."
swapoff -a || true
umount -R /mnt || true
echo ">>> Installation complete! Rebooting in 5 seconds..."
sleep 5 && reboot
