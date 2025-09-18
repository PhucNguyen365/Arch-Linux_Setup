#!/bin/bash

# This script automates the installation of Arch Linux.
# Please ensure you have read the README.md file and completed the necessary
# pre-installation steps (partitioning, formatting, and mounting).

set -euo pipefail

# Enable debug if needed
DEBUG=false
if $DEBUG; then
    set -x
fi

# Install essential packages
pacstrap /mnt base linux linux-firmware grub networkmanager sudo xorg gnome ibus ibus-unikey \
vim nano firefox openssh open-vm-tools gtkmm3 gnome-extra || { echo "Pacstrap failed"; exit 1; }

# Generate fstab file
genfstab -U /mnt >> /mnt/etc/fstab || { echo "Failed to generate fstab"; exit 1; }

# Create post-install script
cat > /mnt/root/post-install.sh <<'EOF'
#!/bin/bash

set -euo pipefail

# Configure timezone
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
hwclock --systohc

# Configure language
if ! grep -q "en_US.UTF-8 UTF-8" /etc/locale.gen; then
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
fi
locale-gen
echo "en_US.UTF-8" > /etc/locale.conf

# Configure hostname
if [ ! -f /etc/hostname ]; then
    echo "archlinux" > /etc/hostname
fi
cat > /etc/hosts <<EOT
127.0.0.1    localhost
::1          localhost
127.0.1.1    archlinux.localdomain archlinux
EOT

# Set root password
read -sp "Enter root password: " ROOT_PASS
echo
echo "root:$ROOT_PASS" | chpasswd || { echo "Failed to set root password"; exit 1; }

# Install GRUB
read -p "Enter the disk to install GRUB (e.g., /dev/sda): " DISK
if [ ! -b "$DISK" ]; then
    echo "Invalid disk: $DISK"
    exit 1
fi
grub-install "$DISK" || { echo "GRUB installation failed"; exit 1; }
grub-mkconfig -o /boot/grub/grub.cfg || { echo "Failed to generate GRUB config"; exit 1; }

# Enable services
systemctl enable NetworkManager gdm sshd vmtoolsd.service vmware-vmblock-fuse.service

# Create a new user
useradd -m -G wheel technical
read -sp "Enter password for user 'technical': " USER_PASS
echo
echo "technical:$USER_PASS" | chpasswd || { echo "Failed to set user password"; exit 1; }

# Grant sudo privileges to the wheel group
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
EOF

# Check if post-install.sh exists
if [ ! -f /mnt/root/post-install.sh ]; then
    echo "Post-install script not found. Aborting."
    exit 1
fi

# Check if the script is executable
if [ ! -x /mnt/root/post-install.sh ]; then
    echo "Post-install script is not executable. Fixing permissions."
    chmod +x /mnt/root/post-install.sh || { echo "Failed to make post-install script executable."; exit 1; }
fi

# Backup the script if it exists
if [ -f /root/arch-setup.sh ]; then
    cp /root/arch-setup.sh /mnt/root/arch-setup.sh.bak
fi

# Check chroot environment
if ! mountpoint -q /mnt; then
    echo "/mnt is not a valid mount point. Aborting."
    exit 1
fi

# Chroot and run post-install
arch-chroot /mnt /root/post-install.sh || { echo "Post-install script failed"; exit 1; }
