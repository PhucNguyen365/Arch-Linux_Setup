#!/bin/bash

set -euo pipefail   # Exit if command fails, unset variable used, or pipeline fails
set -x              # Print commands as they are executed (debug mode)

# Install base system and additional packages into /mnt
pacstrap /mnt base linux linux-firmware grub networkmanager openssh xorg \
    gnome lightdm lightdm-gtk-greeter open-vm-tools gtkmm3 vim nano sudo 

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

# Install GRUB bootloader (BIOS Legacy, target disk = /dev/sda)
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

# Enable essential services
systemctl enable NetworkManager
systemctl enable gdm
systemctl enable sshd
systemctl enable vmtoolsd.service
systemctl enable vmware-vmblock-fuse.service
EOF

# Make post-install script executable
chmod +x /mnt/root/post-install.sh

# Backup this setup script into the new system
cat /root/arch-setup.sh >> /mnt/root/arch-setup.sh.bak

# Enter the new system and run the post-install script
arch-chroot /mnt /root/post-install.sh
