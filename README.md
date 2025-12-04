# 🏹 Automated Arch Linux Installer (GNOME Edition)

A secure, automated Bash script to install Arch Linux with the **GNOME Desktop Environment**.
Designed for speed, simplicity, and security on UEFI systems.

![System](https://img.shields.io/badge/System-UEFI%20Only-blue.svg)
![Distro](https://img.shields.io/badge/Distro-Arch%20Linux-1793d1.svg)

---

## ⚠️ CRITICAL SAFETY WARNINGS

### 1. DATA DESTRUCTION
🔴 **DANGER:** This script will **FORMAT AND WIPE THE ENTIRE TARGET DISK**.
* All data on the selected disk (e.g., `/dev/nvme0n1` or `/dev/sda`) will be **PERMANENTLY LOST**.
* **Backup your data** before proceeding.
* The script includes a safety check: it will list available disks and require you to type the target name manually.

### 2. NO DUAL-BOOT SUPPORT
⛔ **DO NOT USE** this script on a drive containing Windows or another OS.
* This installer expects to use the **whole drive**.
* Attempting to dual-boot on the same disk with this script **WILL DESTROY WINDOWS**.
* **Safe Usage:** Use on a fresh/empty SSD/HDD or inside a Virtual Machine.

---

## 📦 What's Inside?

By running this script, you get a fully configured system with:

* **Core:** Arch Linux Base, Latest Kernel, Linux Firmware.
* **Hardware Support:** Auto-detection for NVMe/SATA and Intel/AMD Microcode.
* **Desktop Environment:** GNOME 40+ (Modern, Wayland-ready).
* **Network:** NetworkManager, Firefox Web Browser.
* **Security:**
    * **Root account:** Locked by default (password disabled).
    * **User account:** Sudo privileges with hashed password storage.
* **Tools:** `vim`, `nano`, `git`, `base-devel` (ready for AUR).

---

## 💾 Partition Layout

The script uses `parted` to create a **GPT** partition table with the following layout:

| Partition | Size | Type | Mount Point | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Partition 1** | 512 MiB | FAT32 | `/boot/efi` | EFI System Partition (Bootloader) |
| **Partition 2** | User Defined | Linux Swap | `[SWAP]` | Swap space (RAM overflow) |
| **Partition 3** | Remaining | EXT4 | `/` | Root File System (OS & Data) |

> **Note:** The script automatically handles naming for NVMe (`nvme0n1p1`) and SATA/SSD (`sda1`).

---

## 📋 System Requirements

* **Boot Mode:** UEFI (Legacy BIOS/CSM is **NOT** supported).
* **Architecture:** x86_64 (64-bit).
* **Internet:** Active connection required (Ethernet or Wi-Fi).
* **Storage:** Minimum 20GB disk space recommended.
* **Power:** Plug in your charger (installation takes 10-20 mins).

---

## 🚀 Installation Guide

### Step 1: Prepare the Media
1.  Download the official [Arch Linux ISO](https://archlinux.org/download/).
2.  Flash it to a USB drive using **Rufus** or **Etcher**.
3.  Boot your computer from the USB in **UEFI Mode** (Disable Secure Boot if necessary).

### Step 2: Connect to Internet
The script needs to download packages.
* **Ethernet:** Plug in the cable (usually connects automatically).
* **Wi-Fi:** Use the command `iwctl` to connect.
