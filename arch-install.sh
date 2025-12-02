#!/bin/bash
# ==============================================================================
#  Automated Arch Linux Installation Script (UEFI + GNOME Desktop)
#  - Security: No Root password (sudo only), Hashed user password.
#  - Compatibility: Auto-detects NVMe/SATA partition naming.
#  - Desktop: GNOME + Firefox included.
# ==============================================================================

set -euo pipefail

# --- CONFIGURATION ------------------------------------------------------------
TARGET_DISK="/dev/nvme0n1"

# --- HELPER FUNCTIONS ---------------------------------------------------------
print_msg() { echo -e "\n\033[1;32m>>> $1\033[0m"; }
print_warn() { echo -e "\n\033[1;33m>>> WARNING: $1\033[0m"; }

# --- PRE-FLIGHT CHECKS --------------------------------------------------------
if [ ! -d "/sys/firmware/efi/efivars" ]; then
    print_warn "This script requires the system to be booted in UEFI mode."
    exit 1
fi

# --- USER INPUT ---------------------------------------------------------------
print_msg "User Configuration"

# 1. Disk Selection
read -rp "Enter target disk (default: $TARGET_DISK): " input_disk
TARGET_DISK="${input_disk:-$TARGET_DISK}"

# 2. Partition Sizes
read -rp "Enter SWAP size in MiB (e.g., 4096): " SWAP_SIZE
if [[ ! "$SWAP_SIZE" =~ ^[0-9]+$ ]]; then echo "Error: Swap must be a number."; exit 1; fi

# 3. System Info
read -rp "Enter Hostname: " HOST_NAME
read -rp "Enter Username: " USER_NAME

# 4. Password (Secure Input)
while true; do
    read -rsp "Enter Password for user '$USER_NAME': " USER_PASS
    echo ""
    read -rsp "Confirm Password: " USER_PASS_CONFIRM
    echo ""
    [ "$USER_PASS" = "$USER_PASS_CONFIRM" ] && break
    echo "Passwords do not match. Please try again."
done

# 5. Localization
read -rp "Enter Timezone (e.g., Asia/Ho_Chi_Minh): " TIME_ZONE
read -rp "Enter Locale (default: en_US.UTF-8): " LOCALE_CONF
LOCALE_CONF="${LOCALE_CONF:-en_US.UTF-8}"

# --- SECURITY: PRE-HASH PASSWORD ----------------------------------------------
USER_PASS_HASH=$(openssl passwd -6 "$USER_PASS")

# --- PARTITION LOGIC ----------------------------------------------------------
if [[ "$TARGET_DISK" == *"nvme"* ]] || [[ "$TARGET_DISK" == *"mmcblk"* ]]; then
    PART_PREFIX="${TARGET_DISK}p"
else
    PART_PREFIX="${TARGET_DISK}"
fi

PART_EFI="${PART_PREFIX}1"
PART_SWAP="${PART_PREFIX}2"
PART_ROOT="${PART_PREFIX}3"

# --- CONFIRMATION -------------------------------------------------------------
print_warn "CRITICAL WARNING: ALL DATA ON $TARGET_DISK WILL BE ERASED."
print_warn "DO NOT USE THIS ON A DUAL-BOOT DRIVE WITH WINDOWS INSTALLED."
echo "------------------------------------------------"
echo "  Disk:      $TARGET_DISK"
echo "  User:      $USER_NAME"
echo "  Desktop:   GNOME + Firefox"
echo "------------------------------------------------"
read -p "Are you sure you want to continue? (y/N): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 1

# --- STEP 1: PARTITIONING -----------------------------------------------------
print_msg "Partitioning disk..."
timedatectl set-ntp true
parted -s "$TARGET_DISK" mklabel gpt \
  mkpart ESP fat32 1MiB 513MiB \
  set 1 esp on \
  mkpart primary linux-swap 513MiB "$((513 + SWAP_SIZE))MiB" \
  mkpart primary ext4 "$((513 + SWAP_SIZE))MiB" 100%

# --- STEP 2: FORMATTING -------------------------------------------------------
print_msg "Formatting partitions..."
mkfs.fat -F32 "$PART_EFI"
mkswap "$PART_SWAP"
mkfs.ext4 "$PART_ROOT"

# --- STEP 3: MOUNTING ---------------------------------------------------------
print_msg "Mounting partitions..."
mount "$PART_ROOT" /mnt
swapon "$PART_SWAP"
mkdir -p /mnt/boot/efi
mount "$PART_EFI" /mnt/boot/efi

# --- STEP 4: INSTALLATION (BASE + GNOME) --------------------------------------
print_msg "Installing Base System, GNOME, and Firefox..."
pacstrap /mnt base linux linux-firmware vim nano sudo \
  grub efibootmgr networkmanager git intel-ucode amd-ucode \
  gnome gnome-extra firefox

# --- STEP 5: FSTAB ------------------------------------------------------------
print_msg "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# --- STEP 6: CONFIGURATION SCRIPT ---------------------------------------------
print_msg "Configuring system..."
cat > /mnt/setup_system.sh <<EOF
#!/bin/bash
set -e

# Timezone & Clock
ln -sf /usr/share/zoneinfo/$TIME_ZONE /etc/localtime
hwclock --systohc

# Locale
sed -i "s/^#$LOCALE_CONF/$LOCALE_CONF/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE_CONF" > /etc/locale.conf

# Hostname
echo "$HOST_NAME" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOST_NAME.localdomain $HOST_NAME
HOSTS

# User & Sudo (Root Locked)
useradd -m -G wheel -s /bin/bash -p '$USER_PASS_HASH' $USER_NAME
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
passwd -l root

# Bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Services (Enable Network & GNOME Login)
systemctl enable NetworkManager
systemctl enable gdm

EOF

chmod +x /mnt/setup_system.sh

# --- STEP 7: FINALIZE ---------------------------------------------------------
print_msg "Entering chroot..."
arch-chroot /mnt /setup_system.sh

print_msg "Cleaning up..."
rm /mnt/setup_system.sh
umount -R /mnt
swapoff -a

print_msg "SUCCESS! Rebooting in 5s..."
sleep 5
reboot
