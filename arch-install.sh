#!/bin/bash

set -euo pipefail   # Exit if command fails, unset variable used, or pipeline fails
set -x              # Print commands as they are executed (debug mode)

# Install base system and additional packages into /mnt
pacstrap /mnt base linux linux-firmware grub efibootmgr networkmanager xorg \
gnome vim nano sudo 

# Generate fstab for mounted partitions
genfstab -U /mnt >> /mnt/etc/fstab 

# Create post-install script inside the new system
cat > /mnt/root/post-install.sh <<'EOF'

#!/bin/bash

set -euo pipefail
set -x

# Set timezone and sync hardware clock
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
hwclock --systohc

# Configure locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname and hosts file
echo "archlinux" > /etc/hostname
cat > /etc/hosts <<EOT
127.0.0.1   localhost
::1         localhost
127.0.1.1   archlinux.localdomain archlinux
EOT

# Set root password
echo "root:technical365" | chpasswd

# --- GRUB Installation for UEFI on NVMe ---
# Mount the EFI system partition (assuming /dev/nvme0n1p1 is EFI and formatted FAT32)
mkdir -p /boot/efi
mount /dev/nvme0n1p1 /boot/efi

# Install GRUB for UEFI
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB

# Generate GRUB configuration
grub-mkconfig -o /boot/grub/grub.cfg

# Enable essential services
systemctl enable NetworkManager
systemctl enable gdm

EOF

# Make post-install script executable
chmod +x /mnt/root/post-install.sh

# Backup this setup script into the new system
cat /root/arch-setup.sh >> /mnt/root/arch-setup.sh.bak

# Enter the new system and run the post-install script
arch-chroot /mnt /root/post-install.sh
