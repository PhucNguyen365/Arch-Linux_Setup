#!/bin/bash
# ==============================================================================
#  Automated Arch Linux Installation Script (UEFI + GNOME Desktop)
#  Simple, Clean, and Destructive.
# ==============================================================================

set -euo pipefail

# --- CONFIGURATION ------------------------------------------------------------
TARGET_DISK="/dev/nvme0n1"

# --- HELPER FUNCTIONS ---------------------------------------------------------
print_msg() { echo -e "\n\033[1;32m>>> $1\033[0m"; }
print_warn() { echo -e "\n\033[1;33m>>> WARNING: $1\033[0m"; }
print_err() { echo -e "\n\033[1;31m>>> ERROR: $1\033[0m"; exit 1; }

# --- PRE-FLIGHT CHECKS --------------------------------------------------------
# 1. Check UEFI
if [ ! -d "/sys/firmware/efi/efivars" ]; then
    print_err "System is NOT booted in UEFI mode. Aborting."
fi

# 2. Check Internet
print_msg "Checking internet connection..."
ping -c 1 archlinux.org >/dev/null 2>&1 || print_err "No internet connection. Please connect via 'iwctl' first."

# 3. Cleanup previous runs (Fix ChatGPT suggestion #3)
print_msg "Cleaning up previous mounts if any..."
swapoff -a || true
umount -R /mnt || true

# --- USER INPUT ---------------------------------------------------------------
print_msg "User Configuration"

# Disk Selection & Validation (Fix ChatGPT suggestion #2)
lsblk
echo ""
read -rp "Enter target disk (default: $TARGET_DISK): " input_disk
TARGET_DISK="${input_disk:-$TARGET_DISK}"

if [ ! -b "$TARGET_DISK" ]; then
    print_err "Disk $TARGET_DISK does not exist. Please check lsblk."
fi

# Partition Sizes
read -rp "Enter SWAP size in MiB (e.g., 4096): " SWAP_SIZE
if [[ ! "$SWAP_SIZE" =~ ^[0-9]+$ ]]; then print_err "Swap size must be a number."; fi

# User Info
read -rp "Enter Hostname: " HOST_NAME
read -rp "Enter Username: " USER_NAME

# Password
while true; do
    read -rsp "Enter Password for user '$USER_NAME': " USER_PASS
    echo ""
    read -rsp "Confirm Password: " USER_PASS_CONFIRM
    echo ""
    [ "$USER_PASS" = "$USER_PASS_CONFIRM" ] && break
    echo "Passwords do not match. Try again."
done

# Localization
read -rp "Enter Timezone (e.g., Asia/Ho_Chi_Minh): " TIME_ZONE
read -rp "Enter Locale (default: en_US.UTF-8): " LOCALE_CONF
LOCALE_CONF="${LOCALE_CONF:-en_US.UTF-8}"

# Hash Password
USER_PASS_HASH=$(openssl passwd -6 "$USER_PASS")

# --- PARTITION LOGIC ----------------------------------------------------------
# Auto-detect NVMe naming
if [[ "$TARGET_DISK" == *"nvme"* ]] || [[ "$TARGET_DISK" == *"mmcblk"* ]]; then
    PART_PREFIX="${TARGET_DISK}p"
else
    PART_PREFIX="${TARGET_DISK}"
fi

PART_EFI="${PART_PREFIX}1"
PART_SWAP="${PART_PREFIX}2"
PART_ROOT="${PART_PREFIX}3"

# --- FINAL CONFIRMATION -------------------------------------------------------
print_warn "CRITICAL: ALL DATA ON $TARGET_DISK WILL BE WIPED."
print_warn "THIS CANNOT BE UNDONE."
echo "------------------------------------------------"
echo "  Target Disk: $TARGET_DISK"
echo "  User:        $USER_NAME"
echo "------------------------------------------------"
read -p "Type 'yes' to proceed: " confirm
[[ "$confirm" == "yes" ]] || exit 1

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

# --- STEP 4: INSTALLATION -----------------------------------------------------
print_msg "Installing Base System & GNOME..."
pacstrap /mnt base linux linux-firmware vim nano sudo \
  grub efibootmgr networkmanager base-devel git intel-ucode amd-ucode \
  gnome gnome-extra firefox

print_msg "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# --- STEP 5: CONFIGURATION ----------------------------------------------------
print_msg "Configuring system..."
cat > /mnt/setup_system.sh <<EOF
#!/bin/bash
set -e

# Timezone
ln -sf /usr/share/zoneinfo/$TIME_ZONE /etc/localtime
hwclock --systohc

# Locale (Fix ChatGPT suggestion #1 - More robust sed)
sed -i "s/^#$LOCALE_CONF UTF-8/$LOCALE_CONF UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE_CONF" > /etc/locale.conf

# Hostname
echo "$HOST_NAME" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOST_NAME.localdomain $HOST_NAME
HOSTS

# User & Security
useradd -m -G wheel -s /bin/bash -p '$USER_PASS_HASH' $USER_NAME
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
passwd -l root

# Bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
# Disable os-prober explicitly to speed up update-grub and avoid errors
echo "GRUB_DISABLE_OS_PROBER=true" >> /etc/default/grub 
grub-mkconfig -o /boot/grub/grub.cfg

# Services (Enable Bluetooth/Avahi as suggested for better GNOME exp)
systemctl enable NetworkManager
systemctl enable gdm
systemctl enable bluetooth
systemctl enable avahi-daemon

EOF

chmod +x /mnt/setup_system.sh

# --- STEP 6: FINALIZE ---------------------------------------------------------
print_msg "Entering chroot..."
arch-chroot /mnt /setup_system.sh

print_msg "Cleaning up..."
rm /mnt/setup_system.sh
umount -R /mnt
swapoff -a

print_msg "DONE! System rebooting in 5s..."
sleep 5
reboot
