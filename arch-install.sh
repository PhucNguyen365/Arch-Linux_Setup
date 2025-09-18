#!/bin/bash

set -euo pipefail
set -x

pacstrap /mnt base linux linux-firmware grub networkmanager sudo xorg gnome ibus ibus-unikey \
vim nano firefox openssh open-vm-tools gtkmm3 gnome-extra

genfstab -U /mnt >> /mnt/etc/fstab 

cat > /mnt/root/post-install.sh <<'EOF'
#!/bin/bash

set -euo pipefail
set -x

ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "en_US.UTF-8" > /etc/locale.conf

echo "archinux" > /etc/hostname
cat > /etc/hosts <<EOT
127.0.0.1    localhost
::1          localhost
127.0.1.1    archlinux.localdomain archlinux
EOT

echo "root:technical" | chpasswd

grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
systemctl enable gdm
systemctl enable sshd
systemctl enable vmtoolsd.service
systemctl enable vmware-vmblock-fuse.service

pacman -Syu --noconfirm

useradd -m -G wheel technical
echo "technical:Phucdz2356" | chpasswd

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
EOF

chmod +x /mnt/root/post-install.sh

cat /root/arch-setup.sh > /mnt/root/arch-setup.sh.bak

arch-chroot /mnt /root/post-install.sh
