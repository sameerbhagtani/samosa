#!/bin/bash
set -euo pipefail # Exit on error, unset variable, and pipe failure

REPO_ROOT=$(dirname "$(readlink -f "$0")")

# Define path variables for clarity
PACKAGE_LISTS="$REPO_ROOT/package_lists"
OTHER_FILES="$REPO_ROOT/other"
SYSTEM_CONFIGS="$REPO_ROOT/dotfiles/system_configs"
USER_CONFIGS="$REPO_ROOT/dotfiles/user_configs"

# --- Initial Checks and Setup ---

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run with sudo."
    exit 1
fi

# Determine the non-root user that called sudo
if [ -z "${SUDO_USER:-}" ]; then
    echo "Error: SUDO_USER variable is not set. Cannot determine target user."
    exit 1
fi

USER="$SUDO_USER"
USER_HOME="/home/$USER"
echo "Starting automated Samosa setup for user: $USER"

# --- Function Definitions ---
install_pacman_packages() {
    echo -e "\n--- Installing PACMAN Packages ---"
    local packages_file="$PACKAGE_LISTS/pacman_packages.txt"
    if [ -f "$packages_file" ]; then
        local packages=($(cat "$packages_file"))
        pacman -S --noconfirm --needed "${packages[@]}"
    else
        echo "Warning: $packages_file not found. Skipping pacman installs."
    fi
}

# install_aur_packages() {
#     echo -e "\n--- Installing AUR Packages via Yay ---"
#     local packages_file="$PACKAGE_LISTS/aur_packages.txt"
    
#     if [ -f "$packages_file" ]; then
#         echo "Executing yay as user: $USER"
#         sudo -u "$USER" yay -S --noconfirm --needed $(cat "$packages_file")
        
#         if [ $? -ne 0 ]; then
#             echo "Error: AUR package installation failed. Check if 'yay' is installed and in the user's PATH."
#         fi
#     else
#         echo "Warning: $packages_file not found. Skipping AUR installs."
#     fi
# }

install_flatpak_apps() {
    echo -e "\n--- Installing Flatpak Applications ---"
    local apps_file="$PACKAGE_LISTS/flatpak_apps.txt"
    if [ -f "$apps_file" ]; then
        echo "Enabling Flathub remote..."
        sudo -u "$USER" flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        
        local flatpak_apps=$(cat "$apps_file" | tr '\n' ' ')
        echo "Installing apps: $flatpak_apps"
        sudo -u "$USER" flatpak install flathub --noninteractive $flatpak_apps
    else
        echo "Warning: $apps_file not found. Skipping Flatpak installs."
    fi
}

# --- Execution Steps ---

echo -e "\n--- Installing Core Utilities (git, rsync, base-devel) ---"
pacman -S --noconfirm --needed git rsync base-devel

# Enable Multilib and Sync
echo -e "\n--- Enabling Multilib Repository ---"
if [ -f "$SYSTEM_CONFIGS/etc-pacman.conf" ]; then
    cp "$SYSTEM_CONFIGS/etc-pacman.conf" /etc/pacman.conf
    echo "Using custom pacman.conf. Syncing repositories..."
    pacman -Sy --noconfirm # Sync after enabling multilib
else
    echo "Warning: Custom etc-pacman.conf not found. Attempting sed edit for multilib."
    sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
    pacman -Sy --noconfirm
fi

# Install Yay
echo -e "\n--- Installing Yay ---"
if ! sudo -u "$USER" command -v yay &> /dev/null; then
    echo "Attempting to install Yay as user: $USER"
    sudo -u "$USER" sh -c "
        INSTALL_DIR='/tmp/yay'
        git clone https://aur.archlinux.org/yay.git \$INSTALL_DIR || exit 1
        cd \$INSTALL_DIR
        makepkg -si --noconfirm || exit 1
        rm -rf \$INSTALL_DIR
    "
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install Yay. Check the output above."
        exit 1
    fi
else
    echo "Yay is already installed."
fi

# Install Core and Required Packages
install_pacman_packages
# install_aur_packages

# --- Configure iwd and Disable wpa_supplicant ---
echo -e "\n--- Configuring NetworkManager to use iwd and disabling wpa_supplicant ---"

mkdir -p /etc/NetworkManager/conf.d/
echo -e "[device]\nwifi.backend=iwd" | tee /etc/NetworkManager/conf.d/wifi-backend-iwd.conf

systemctl stop wpa_supplicant.service
systemctl disable wpa_supplicant.service
systemctl mask wpa_supplicant.service
echo "iwd configuration complete."

# Enable ly Display Manager
echo -e "\n--- Enabling ly Service ---"
systemctl enable ly.service

# Add User to Groups
echo -e "\n--- Adding $USER to necessary groups (video, audio, input) ---"
usermod -aG video,audio,input,network,uucp "$USER"

# System Configuration Edits
echo -e "\n--- Copying System Configuration Files to /etc/ ---"
cp "$SYSTEM_CONFIGS/etc-vconsole.conf" /etc/vconsole.conf
cp "$SYSTEM_CONFIGS/etc-systemd-logind.conf" /etc/systemd/logind.conf
cp "$SYSTEM_CONFIGS/etc-ly-config.ini" /etc/ly/config.ini

# Copy all User Configs
echo -e "\n--- Copying User Configs (Dotfiles) ---"
sudo -u "$USER" rsync -a "$USER_CONFIGS/." "$USER_HOME/"

# Place wallpaper in ~/Pictures
echo -e "--- Copying wallpapers to $USER_HOME/Pictures ---"
sudo -u "$USER" mkdir -p "$USER_HOME/Pictures"
cp -r "$OTHER_FILES/wallpapers" "$USER_HOME/Pictures/"

# Append to bashrc
echo -e "\n--- Appending content to ~/.bashrc ---"
cat "$OTHER_FILES/bashrc_append.txt" >> "$USER_HOME/.bashrc"

# Fix ownership for all copied user files
echo -e "--- Fixing ownership of user files ---"
chown -R "$USER:$USER" "$USER_HOME/.config" "$USER_HOME/.local" "$USER_HOME/.bashrc" "$USER_HOME/Pictures"

# Make auto-run scripts executable
echo -e "--- Setting Permissions for power-menu ---"
chmod +x "$USER_HOME/.local/bin/power-menu"
chmod +x "$USER_HOME/.local/bin/change-wallpaper"
chmod +x "$USER_HOME/.local/bin/restore-wallpaper"

# Enable Elephant services
# echo -e "\n--- Enabling Elephant Services ---"
# runuser -l "$USER" -c "elephant service enable"

# if [ $? -ne 0 ]; then
#     echo "Elephant service enable command failed."
# fi

# Flatpak Applications
install_flatpak_apps

# GRUB Configuration
echo -e "\n--- Updating GRUB Configuration ---"
sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo -e "\n\n***************************************"
echo "*** Setup Complete! ***"
echo "*** Please run the following command and then reboot to enjoy Samosa: ***"
echo "yay -S --needed visual-studio-code-bin brave-bin ttf-cascadia-code-nerd walker elephant-calc elephant-clipboard elephant-symbols && elephant service enable"
echo "***************************************"