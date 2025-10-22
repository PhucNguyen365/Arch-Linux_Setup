#!/bin/bash
# ===========================================================
#  Automated Arch Linux Installation Script (UEFI)
#  Author: Technical + GPT-5
# ===========================================================

set -euo pipefail
set -x  # Print each command (debug mode)

# --- CONFIGURATION SECTION ---------------------------------------------------
DISK="/dev/nvme0n1"             # Target installation disk
EFI_SIZE="512MiB"               # EFI partition size
SWAP_SIZE="2GiB"                # Swap partition size
HOSTNAME="archlinux"
USERNAME="technical"
USERPASS="technical365"         # <-- Change this to your preferred user password
ROOTPASS="root365"              # <-- Change this to your preferred root password
TIMEZONE="Asia/Ho_Chi_Minh"
LOCALE="en_US.UTF-8"
# -----------------------------------------------------------------------------

echo ">>> WARNING: ALL DATA on $DISK will be ERASED!"
read -p "Are you sure you want to continue? (y/N): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 1

# --- STEP 1: Partition the disk (GPT) ----------------------------------------
parted -s "$DISK" mklabel gpt \
  mkpart ESP fat32 1MiB $EFI_SIZE set 1 esp on \
  mkpart primary linux-swap $EFI_SIZE $(echo "$EFI_SIZE + $SWAP_SIZE" | bc) \
  mkpart primary ext4 $(echo "$EFI_SIZE + $SWAP_SIZE" | bc) 100%

# --- STEP 2: Format partitions -----------------------------------------------
mkfs.fat -F32 ${DISK}p1
mkswap ${DISK}p2
mkfs.ext4 ${DISK}p3

# --- STEP 3: Mount partitions -------------------------------------------------
mount ${DISK}p3 /mnt
swapon ${DISK}p2
mkdir -p /mnt/boot/efi
mount ${DISK}p1 /mnt/boot/efi

# --- STEP 4: Install base system ---------------------------------------------
pacstrap /mnt base linux linux-firmware vim nano sudo \
  grub efibootmgr networkmanager xorg gnome

# --- STEP 5: Generate fstab ---------------------------------------------------
genfstab -U /mnt >> /mnt/etc/fstab

# --- STEP 6: Create post-installation script ---------------------------------
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
arch-chroot /mnt /root/post-install.sh
