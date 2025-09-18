#!/bin/bash
# Arch Linux setup script (modular & resumeable)
set -euo pipefail

STEP_FILE=/mnt/root/.install_step
LOG_FILE=/mnt/root/install.log
DEBUG=false
$DEBUG && set -x

echo "[INFO] Starting Arch Linux setup" | tee -a "$LOG_FILE"

# Initialize checkpoint file
touch "$STEP_FILE"

# Helper function to run each step
run_step() {
    local step_name=$1
    shift
    if grep -qx "$step_name" "$STEP_FILE" 2>/dev/null; then
        echo "[SKIP] $step_name already done" | tee -a "$LOG_FILE"
    else
        echo "[INFO] Running $step_name..." | tee -a "$LOG_FILE"
        "$@" 2>&1 | tee -a "$LOG_FILE"
        echo "$step_name" >> "$STEP_FILE"
        echo "[INFO] $step_name done" | tee -a "$LOG_FILE"
    fi
}

# 1️⃣ Install essential packages
run_step "pacstrap_base" pacstrap /mnt base linux linux-firmware grub networkmanager sudo \
xorg gnome ibus ibus-unikey vim nano firefox openssh open-vm-tools gtkmm3 gnome-extra

# 2️⃣ Generate fstab
run_step "generate_fstab" genfstab -U /mnt >> /mnt/etc/fstab

# 3️⃣ Create post-install script
run_step "create_post_install" bash -c "cat > /mnt/root/post-install.sh <<'EOF'
#!/bin/bash
set -euo pipefail

echo \"[INFO] Configuring timezone...\"
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
hwclock --systohc

echo \"[INFO] Configuring locale...\"
grep -q 'en_US.UTF-8 UTF-8' /etc/locale.gen || echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
echo 'en_US.UTF-8' > /etc/locale.conf

echo \"[INFO] Configuring hostname and hosts...\"
echo 'archlinux' > /etc/hostname
cat > /etc/hosts <<EOT
127.0.0.1    localhost
::1          localhost
127.0.1.1    archlinux.localdomain archlinux
EOT

echo \"[INFO] Setting root password...\"
read -sp 'Enter root password: ' ROOT_PASS
echo
echo \"root:\$ROOT_PASS\" | chpasswd

echo \"[INFO] Installing GRUB...\"
read -p 'Enter the disk to install GRUB (e.g., /dev/sda): ' DISK
[[ -b \"\$DISK\" ]] || { echo \"Invalid disk: \$DISK\"; exit 1; }
grub-install \"\$DISK\"
grub-mkconfig -o /boot/grub/grub.cfg

echo \"[INFO] Enabling services...\"
systemctl enable NetworkManager gdm sshd vmtoolsd.service vmware-vmblock-fuse.service

echo \"[INFO] Creating user 'technical'...\"
useradd -m -G wheel technical
read -sp 'Enter password for user technical: ' USER_PASS
echo
echo \"technical:\$USER_PASS\" | chpasswd

echo \"[INFO] Granting sudo privileges to wheel group...\"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
EOF"

# Make post-install script executable
run_step "chmod_post_install" chmod +x /mnt/root/post-install.sh

# 4️⃣ Backup original setup script (optional)
run_step "backup_script" [ -f /root/arch-setup.sh ] && cp /root/arch-setup.sh /mnt/root/arch-setup.sh.bak

# 5️⃣ Check /mnt mount
run_step "check_mount" mountpoint -q /mnt || { echo "/mnt is not mounted"; exit 1; }

# 6️⃣ Run post-install in chroot
run_step "post_install_chroot" arch-chroot /mnt /root/post-install.sh

echo "[INFO] Arch Linux setup completed successfully!" | tee -a "$LOG_FILE"
