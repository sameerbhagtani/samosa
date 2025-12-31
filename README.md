# 🥟 SAMOSA: A clean and minimal Arch Linux + Hyprland Setup

Welcome to the **SAMOSA** setup! This repository contains all my configuration files and a single script to automatically bootstrap a minimal **Arch Linux** installation into my complete, customized Wayland desktop environment based on **Hyprland**.

## 🚀 Installation

To get the complete SAMOSA experience, follow these three steps:

### Step 1: Base Arch Installation

Start with a minimal base installation of Arch Linux. If using the official `archinstall` script, select the following options (and leave anything not mentioned as-is):

| Section                        | Option                                         |
| ------------------------------ | ---------------------------------------------- |
| Mirrors and repositories       | Select regions > Your country                  |
| Disk Configuration             | Partitioning -> (Partition as you wish)        |
| Bootloader                     | Grub                                           |
| Hostname                       | Give any name to your computer                 |
| Authentication > Root Password | Set yours                                      |
| Authentication > User Account  | Add a user > Superuser: Yes > Confirm and exit |
| Applications > Bluetooth       | yes                                            |
| Applications > Audio           | `pipewire`                                     |
| Network Configuration          | Use `NetworkManager`                           |
| Timezone                       | Set yours                                      |

---

### Step 2: Reboot and run the install script

```bash
curl -L https://raw.githubusercontent.com/sameerbhagtani/samosa/main/install.sh | sh
```

---

### Step 3: Run the following command

> **NOTE:** Do not reboot. Perform this step right after step 2 without rebooting the system. Only reboot at the very end.

```bash
yay -S --needed visual-studio-code-bin brave-bin ttf-cascadia-code-nerd walker elephant elephant-providerlist elephant-desktopapplications elephant-calc elephant-clipboard elephant-symbols && elephant service enable
```

---
