# Automated Arch Linux Installer (GNOME Edition)

A simple, secure, and automated Bash script to install Arch Linux with the **GNOME Desktop Environment** and **Firefox**. 

> **Designed for UEFI systems.**

## ⚠️ CRITICAL WARNINGS - READ BEFORE USE

### 1. DATA DESTRUCTION
🔴 **THIS SCRIPT WILL FORMAT THE ENTIRE TARGET DISK.** All data on the selected disk (e.g., `/dev/nvme0n1` or `/dev/sda`) will be **PERMANENTLY ERASED**.

### 2. DUAL-BOOT HAZARD
⛔ **DO NOT USE THIS SCRIPT ON A DUAL-BOOT DRIVE.** If you have Windows installed on your hard drive and you try to install Arch Linux on the *same* drive using this script, **IT WILL DELETE WINDOWS**.
* **Recommended:** Use a completely empty disk or a dedicated drive for Linux.
* **Virtual Machines:** Safe to use in VirtualBox, VMware, etc.

---

## ✨ Features

* **Automated Partitioning:** Auto-detects NVMe/SSD/HDD naming schemes (GPT/UEFI).
* **Secure by Design:**
    * **Root account is locked** by default (no password).
    * Creates a `sudo` user with a **hashed password** (password is never stored in plain text during install).
* **Ready-to-use:** Installs **GNOME**, **Firefox**, `vim`, `git`, and essential drivers (`intel-ucode`/`amd-ucode`).
* **Interactive:** Asks for Hostname, Username, Password, and Timezone.

## 🚀 Installation Guide

### Prerequisites
1.  **Arch Linux ISO** (booted in UEFI mode).
2.  **Internet Connection** (Ethernet or Wi-Fi connected via `iwctl`).

### How to Run

1.  Boot into the Arch Linux Live ISO.
2.  Connect to the internet.
3.  Download and run the script:

```bash
# Download the script (assuming you hosted it on GitHub/Raw)
curl -O [https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/arch-install.sh](https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/arch-install.sh)

# Make it executable
chmod +x arch-install.sh

# Run it
./arch-install.sh
