#!/bin/bash

# Set up some variables
DISK="/dev/sdX" # Replace with your target disk
HOSTNAME="archlinux"
USERNAME="user"
PASSWORD="password"

# Update system clock
timedatectl set-ntp true

# Partition the disk
sgdisk -Z ${DISK} # Wipe all partitions
sgdisk -n 1:0:+550M -t 1:ef00 ${DISK} # EFI system partition
sgdisk -n 2:0:0 -t 2:8300 ${DISK} # Linux filesystem

# Format the partitions
mkfs.fat -F32 ${DISK}1
mkfs.ext4 ${DISK}2

# Mount the filesystem
mount ${DISK}2 /mnt
mkdir /mnt/boot
mount ${DISK}1 /mnt/boot

# Install essential packages
pacstrap /mnt base linux linux-firmware vim

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Change root into the new system
arch-chroot /mnt /bin/bash <<EOF

# Set the time zone
ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
hwclock --systohc

# Generate locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "${HOSTNAME}" > /etc/hostname
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    ${HOSTNAME}.localdomain ${HOSTNAME}" >> /etc/hosts

# Set root password
echo "root:${PASSWORD}" | chpasswd

# Install necessary packages
pacman -Sy --noconfirm grub efibootmgr networkmanager

# Install and configure GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Enable NetworkManager
systemctl enable NetworkManager

# Create a user
useradd -m -G wheel -s /bin/bash ${USERNAME}
echo "${USERNAME}:${PASSWORD}" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

EOF

# Unmount all partitions
umount -R /mnt

# Reboot
echo "Installation complete. Rebooting..."
reboot
