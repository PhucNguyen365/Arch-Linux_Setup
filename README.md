# Automated Arch Linux Installer (GNOME Edition)

**TARGET SYSTEM:** UEFI Only (64-bit)

---

## ⚠️ CRITICAL SAFETY WARNINGS

### 1. DATA DESTRUCTION
🔴 **WARNING:** This script will **FORMAT AND ERASE THE ENTIRE DISK** you select (e.g., `/dev/nvme0n1` or `/dev/sda`).
* **Back up your data** before running this script.
* There is no "Undo" button after the confirmation prompt.

### 2. NO DUAL-BOOT SUPPORT
⛔ **DO NOT USE** this script if you have Windows (or another OS) on the same drive.
* This script is designed to take over the **entire drive**.
* Attempting to use this on a dual-boot setup **WILL DELETE WINDOWS**.
* **Safe Usage:** Use on a completely empty SSD/HDD or inside a Virtual Machine (VirtualBox, VMware, KVM).

---

## 📦 What's Inside?

By running this script, you will get a fully configured system with:
* **Base System:** Arch Linux (Latest Kernel), Linux Firmware.
* **Security:** Root account locked (sudo only), Hashed passwords.
* **Desktop:** GNOME 40+, GDM (Login Manager).
* **Apps:** Firefox, Vim, Nano, Git, NetworkManager.
* **Drivers:** Auto-install for Intel/AMD Microcode.

---

## 🚀 Installation Instructions

### Step 1: Prepare
1.  Download the **Arch Linux ISO**.
2.  Flash it to a USB drive (using Rufus or Etcher).
3.  Boot your computer from the USB in **UEFI Mode** (Disable Secure Boot if necessary).

### Step 2: Connect to Internet
The script requires an active internet connection.
# Connect to Wi-Fi (if using Ethernet, skip this)
iwctl
