#!/bin/bash
# Automated Arch Linux installation script (simplified & safe)

set -euo pipefail

# Enable debug if needed
DEBUG=false
$DEBUG && set -x

echo "[INFO] Installing essential packages..."
pacstrap /mnt base linux linux-firmware grub networkmanager sudo xorg gnome \
ibus ibus-unikey vim nano firefox openssh open-vm-tools gtkmm3 gnome-extra
echo "[INFO] Pacstrap done"

echo "[INFO] Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
echo "[INFO] fstab generated"

# Create post-install script
cat > /mnt/root/post-install.sh <<'EOF'
#!/bin/bash
set -euo pipefail

echo "[INFO] Configuring timezone..."
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
hwclock --systohc

echo "[INFO] Configuring locale..."
grep -q "en_US.UTF-8 UTF-8" /etc/locale.gen || echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "en_US.UTF-8" > /etc/locale.conf

echo "[INFO] Configuring hostname and hosts..."
echo "archlinux" > /etc/hostname
cat > /etc/hosts <<EOT
127.0.0.1    localhost
::1          localhost
127.0.1.1    archlinux.localdomain archlinux
EOT

echo "[INFO] Setting root password..."
read -sp "Enter root password: " ROOT_PASS
echo
echo "root:$ROOT_PASS" | chpasswd

echo "[INFO] Installing GRUB..."
read -p "Enter the disk to install GRUB (e.g., /dev/sda): " DISK
[[ -b "$DISK" ]] || { echo "Invalid disk: $DISK"; exit 1; }
grub-install "$DISK"
grub-mkconfig -o /boot/grub/grub.cfg

echo "[INFO] Enabling services..."
systemctl enable NetworkManager gdm sshd vmtoolsd.service vmware-vmblock-fuse.service

echo "[INFO] Creating user 'technical'..."
useradd -m -G wheel technical
read -sp "Enter password for user 'technical': " USER_PASS
echo
echo "technical:$USER_PASS" | chpasswd

echo "[INFO] Granting sudo privileges to wheel group..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
EOF

# Make post-install script executable
chmod +x /mnt/root/post-install.sh

# Backup original script if exists
[ -f /root/arch-setup.sh ] && cp /root/arch-setup.sh /mnt/root/arch-setup.sh.bak

# Ensure /mnt is mounted
mountpoint -q /mnt || { echo "/mnt is not a valid mount point. Aborting."; exit 1; }

echo "[INFO] Entering chroot to run post-install script..."
arch-chroot /mnt /root/post-install.sh
echo "[INFO] Post-install script completed successfully!"
