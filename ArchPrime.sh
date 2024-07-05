#!/usr/bin/env -S bash -e

# Fixing annoying issue that breaks GitHub Actions
# shellcheck disable=SC2001

# Cleaning the TTY.
clear

# Cosmetics (colours for text).
BOLD='\e[1m'
BRED='\e[91m'
BBLUE='\e[34m'
BGREEN='\e[92m'
BYELLOW='\e[93m'
RESET='\e[0m'

# Pretty print (function).
info_print () {
    echo -e "${BOLD}${BGREEN}[ ${BYELLOW}•${BGREEN} ] $1${RESET}"
}

# Pretty print for input (function).
input_print () {
    echo -ne "${BOLD}${BYELLOW}[ ${GREEN}•${BYELLOW} ] $1${RESET}"
}

# Alert user of bad input (function).
error_print () {
    echo -e "${BOLD}${BRED}[ ${BBLUE}•${BRED} ] $1${RESET}"
}

# Virtualization check (function).
virt_check () {
    hypervisor=$(systemd-detect-virt)
    case $hypervisor in
        kvm )   info_print "KVM has been detected, setting up guest tools."
                pacstrap /mnt qemu-guest-agent &>/dev/null
                systemctl enable qemu-guest-agent --root=/mnt &>/dev/null
                ;;
        vmware  )   info_print "VMWare Workstation/ESXi has been detected, setting up guest tools."
                    pacstrap /mnt open-vm-tools >/dev/null
                    systemctl enable vmtoolsd --root=/mnt &>/dev/null
                    systemctl enable vmware-vmblock-fuse --root=/mnt &>/dev/null
                    ;;
        oracle )    info_print "VirtualBox has been detected, setting up guest tools."
                    pacstrap /mnt virtualbox-guest-utils &>/dev/null
                    systemctl enable vboxservice --root=/mnt &>/dev/null
                    ;;
        microsoft ) info_print "Hyper-V has been detected, setting up guest tools."
                    pacstrap /mnt hyperv &>/dev/null
                    systemctl enable hv_fcopy_daemon --root=/mnt &>/dev/null
                    systemctl enable hv_kvp_daemon --root=/mnt &>/dev/null
                    systemctl enable hv_vss_daemon --root=/mnt &>/dev/null
                    ;;
    esac
}

# Selecting a kernel to install (function).
kernel_selector () {
    info_print "List of kernels:"
    info_print "1) Stable: Vanilla Linux kernel with a few specific Arch Linux patches applied"
    info_print "2) Hardened: A security-focused Linux kernel"
    info_print "3) Longterm: Long-term support (LTS) Linux kernel"
    info_print "4) Zen Kernel: A Linux kernel optimized for desktop usage"
    input_print "Please select the number of the corresponding kernel (e.g. 1): " 
    read -r kernel_choice
    case $kernel_choice in
        1 ) kernel="linux"
            return 0;;
        2 ) kernel="linux-hardened"
            return 0;;
        3 ) kernel="linux-lts"
            return 0;;
        4 ) kernel="linux-zen"
            return 0;;
        * ) error_print "You did not enter a valid selection, please try again."
            return 1
    esac
}

# Selecting a way to handle internet connection (function).
network_selector () {
    info_print "Network utilities:"
    info_print "1) IWD: Utility to connect to networks written by Intel (WiFi-only, built-in DHCP client)"
    info_print "2) NetworkManager: Universal network utility (both WiFi and Ethernet, highly recommended)"
    info_print "3) wpa_supplicant: Utility with support for WEP and WPA/WPA2 (WiFi-only, DHCPCD will be automatically installed)"
    info_print "4) dhcpcd: Basic DHCP client (Ethernet connections or VMs)"
    info_print "5) I will do this on my own (only advanced users)"
    input_print "Please select the number of the corresponding networking utility (e.g. 1): "
    read -r network_choice
    if ! ((1 <= network_choice <= 5)); then
        error_print "You did not enter a valid selection, please try again."
        return 1
    fi
    return 0
}

# Installing the chosen networking method to the system (function).
network_installer () {
    case $network_choice in
        1 ) info_print "Installing and enabling IWD."
            pacstrap /mnt iwd >/dev/null
            systemctl enable iwd --root=/mnt &>/dev/null
            ;;
        2 ) info_print "Installing and enabling NetworkManager."
            pacstrap /mnt networkmanager >/dev/null
            systemctl enable NetworkManager --root=/mnt &>/dev/null
            ;;
        3 ) info_print "Installing and enabling wpa_supplicant and dhcpcd."
            pacstrap /mnt wpa_supplicant dhcpcd >/dev/null
            systemctl enable wpa_supplicant --root=/mnt &>/dev/null
            systemctl enable dhcpcd --root=/mnt &>/dev/null
            ;;
        4 ) info_print "Installing dhcpcd."
            pacstrap /mnt dhcpcd >/dev/null
            systemctl enable dhcpcd --root=/mnt &>/dev/null
    esac
}

# Function to select desktop environment
desktop_selector () {
    info_print "Desktop environments:"
    info_print "1) GNOME"
    info_print "2) KDE Plasma"
    info_print "3) Xfce"
    input_print "Please select the number of the corresponding desktop environment (e.g. 1): "
    read -r desktop_choice
    case $desktop_choice in
        1 ) desktop_packages="gnome gnome-extra"
            ;;
        2 ) desktop_packages="plasma-meta"
            ;;
        3 ) desktop_packages="xfce4 xfce4-goodies"
            ;;
        * ) error_print "You did not enter a valid selection, proceeding without a desktop environment."
            return
            ;;
    esac

    # Install the selected desktop environment
    info_print "Installing $desktop_packages."
    pacstrap /mnt $desktop_packages >/dev/null
}

# User enters a password for the LUKS Container (function).
lukspass_selector () {
    input_print "Please enter a password for the LUKS container (you're not going to see the password): "
    read -r -s password
    if [[ -z "$password" ]]; then
        echo
        error_print "You need to enter a password for the LUKS Container, please try again."
        return 1
    fi
    echo
    input_print "Please enter the password for the LUKS container again (you're not going to see the password): "
    read -r -s password2
    echo
    if [[ "$password" != "$password2" ]]; then
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Setting up a password for the user account (function).
userpass_selector () {
    input_print "Please enter name for a user account (enter empty to not create one): "
    read -r username
    if [[ -z "$username" ]]; then
        return 0
    fi
    input_print "Please enter a password for $username (you're not going to see the password): "
    read -r -s userpass
    if [[ -z "$userpass" ]]; then
        echo
        error_print "You need to enter a password for $username, please try again."
        return 1
    fi
    echo
    input_print "Please enter the password again (you're not going to see it): " 
    read -r -s userpass2
    echo
    if [[ "$userpass" != "$userpass2" ]]; then
        echo
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Setting up a password for the root account (function).
rootpass_selector () {
    input_print "Please enter a password for the root user (you're not going to see it): "
    read -r -s rootpass
    if [[ -z "$rootpass" ]]; then
        echo
        error_print "You need to enter a password for the root user, please try again."
        return 1
    fi
    echo
    input_print "Please enter the password again (you're not going to see it): " 
    read -r -s rootpass2
    echo
    if [[ "$rootpass" != "$rootpass2" ]]; then
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Microcode detector (function).
microcode_detector () {
    CPU=$(grep vendor_id /proc/cpuinfo)
    if [[ "$CPU" == *"AuthenticAMD"* ]]; then
        info_print "An AMD CPU has been detected, the AMD microcode will be installed."
        microcode="amd-ucode"
    elif [[ "$CPU" == *"GenuineIntel"* ]]; then
        info_print "An Intel CPU has been detected, the Intel microcode will be installed."
        microcode="intel-ucode"
    fi
}

# Partitioning and mounting (function)
partition_setup () {
    info_print "Setting up partitions..."
    
    # Example: Create a single LUKS encrypted partition for simplicity
    lsblk
    input_print "Enter the disk to partition (e.g., /dev/sda): "
    read -r disk
    
    # Create partitions
    parted "$disk" mklabel gpt
    parted "$disk" mkpart primary fat32 1MiB 512MiB
    parted "$disk" set 1 esp on
    parted "$disk" mkpart primary ext4 512MiB 100%
    
    # Setup LUKS
    echo -n "$password" | cryptsetup luksFormat "${disk}2" -
    echo -n "$password" | cryptsetup open "${disk}2" cryptroot -
    
    # Format partitions
    mkfs.fat -F32 "${disk}1"
    mkfs.ext4 /dev/mapper/cryptroot
    
    # Mount partitions
    mount /dev/mapper/cryptroot /mnt
    mkdir /mnt/boot
    mount "${disk}1" /mnt/boot
    
    info_print "Partitions have been set up and mounted."
}

# If you are not root, you cannot run this script.
if [[ "$EUID" -ne 0 ]]; then
    error_print "This script must be run as root, exiting."
    exit 1
fi

info_print "Running pre-flight checks..."

# Microcode detection.
microcode_detector

# Virtualization detection.
virt_check

info_print "The pre-flight checks are now complete."

# Printing the welcome message.
info_print "Welcome to the guided installation of Arch Linux."
info_print "Please select options by entering the corresponding number."

# Partition setup
partition_setup

while ! kernel_selector; do
    continue
done

while ! network_selector; do
    continue
done

while ! userpass_selector; do
    continue
done

while ! rootpass_selector; do
    continue
done

while ! lukspass_selector; do
    continue
done

# Select and install desktop environment
desktop_selector

info_print "Installing kernel and bootloader."
pacstrap /mnt base "$kernel" "$microcode" linux-firmware grub grub-btrfs efibootmgr sudo >/dev/null

info_print "Generating an fstab."
genfstab -U /mnt >> /mnt/etc/fstab

info_print "Setting up networking."
network_installer

info_print "Installation is now complete. Please reboot into your new system."
