#!/bin/bash

# This is the text based interface for Uproar.

# Uproar is a Arch Linux installer that is designed specifically for low end devices.
# While it uses customized branding, I do not consider it to be a distribution.
# Any contributions are greatly appreciated.

# Designed by SylveonDev, 2025-2026

RELEASE="9-23-2026"
LOGO=" 
      ^ ^
    =(OwO)=       Uproar Linux
     (     )/     -- Updated $RELEASE --
       | |"

normalizeDeviceName () {
    case "$1" in
        /dev/*) printf '%s\n' "${1#/dev/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

isBlockDeviceName () {
    case "$1" in
        ''|*[!A-Za-z0-9._-]*) return 1 ;;
    esac
    [ -b "/dev/$1" ]
}

echo "Uproar is free software, and comes with ABSOLUTELY NO WARRANTY. Usage of this software is at your own risk.
Uproar is experimental software and is not guaranteed to work on all devices. It is highly recommended to have some
level of experience with Linux before using this software.

To continue, press Enter."
read -r

partDisk () {
    clear
    echo "$LOGO"
    echo "
    ----------------------------------------------------
    -                 Disk partitioner                 -
    ----------------------------------------------------
    "
    lsblk
    read -r -p "Enter the disk to modify (For example: sda, sdc): " DISK
    DISK=$(normalizeDeviceName "$DISK")
    if ! isBlockDeviceName "$DISK"; then
        echo "Disk does not exist or is not a valid device."
        read -r -p "Press Enter to return to the main menu."
        MainMenu
        return 1
    fi

    echo "Okay, you will now be sent to fdisk to modify your disk.
        
        You will need to create a 1gb partition for the boot partition, and the rest can be used for the root partition.
        Uproar will format the partitions automatically,

        "
    sleep 2
    if ! fdisk "/dev/$DISK"; then
        echo "Partitioning failed."
        read -r -p "Press Enter to return to the main menu."
        MainMenu
        return 1
    fi

    lsblk
    read -r -p "Where do you want the boot partition to be? (For example: sda1, sdc1): " BOOTPART
    BOOTPART=$(normalizeDeviceName "$BOOTPART")
    read -r -p "Where do you want the root partition to be? (For example: sda2, sdc2): " ROOTPART
    ROOTPART=$(normalizeDeviceName "$ROOTPART")
    if ! isBlockDeviceName "$BOOTPART" || ! isBlockDeviceName "$ROOTPART" ||
        [ "$BOOTPART" = "$ROOTPART" ] || [ "$BOOTPART" = "$DISK" ] || [ "$ROOTPART" = "$DISK" ]; then
        echo "Boot and root must be two distinct, existing partition devices."
        read -r -p "Press Enter to return to the main menu."
        MainMenu
        return 1
    fi

    echo "Formatting partitions..."
    if ! mkfs.vfat -F 32 "/dev/$BOOTPART" || ! mkfs.ext4 "/dev/$ROOTPART"; then
        echo "Partition formatting failed."
        read -r -p "Press Enter to return to the main menu."
        MainMenu
        return 1
    fi

    echo "Mounting partitions..."
    if ! mount "/dev/$ROOTPART" /mnt; then
        echo "Could not mount the root partition."
        read -r -p "Press Enter to return to the main menu."
        MainMenu
        return 1
    fi
    if [ -d "/sys/firmware/efi" ]; then
        BOOT_MOUNT=/mnt/boot/efi
    else
        BOOT_MOUNT=/mnt/boot
    fi
    if ! mkdir -p "$BOOT_MOUNT" || ! mount "/dev/$BOOTPART" "$BOOT_MOUNT"; then
        echo "Could not mount the boot partition."
        umount /mnt
        read -r -p "Press Enter to return to the main menu."
        MainMenu
        return 1
    fi
    MainMenu
}

updateCerts () {
    clear
    echo "$LOGO"
    echo "
    ----------------------------------------------------
    -              Update certificates                 -
    ----------------------------------------------------
    "
    echo "Updating certificates..."
    if ! pacman -Sy --noconfirm ca-certificates; then
        echo "Certificate update failed."
        read -r -p "Press Enter to return to the main menu."
        MainMenu
        return 1
    fi
    echo "Certificates updated successfully."
    read -r -p "Press Enter to return to the main menu."
    MainMenu
}

installUproar () {
    clear
    echo "$LOGO"
    echo "
    ----------------------------------------------------
    -                 Install Uproar                   -
    ----------------------------------------------------
    "
    echo "Installing Uproar..."
    if [ ! -d "/sys/firmware/efi" ] && ! isBlockDeviceName "${DISK:-}"; then
        echo "Select a valid target disk with the disk partitioner before installing in BIOS mode."
        read -r -p "Press Enter to return to the main menu."
        MainMenu
        return 1
    fi
    sleep 2
    if ! pacstrap -K /mnt base linux linux-firmware; then
        echo "Base system installation failed."
        read -r -p "Press Enter to return to the main menu."
        MainMenu
        return 1
    fi
    if ! genfstab -U /mnt >> /mnt/etc/fstab; then
        echo "Could not write the filesystem table."
        read -r -p "Press Enter to return to the main menu."
        MainMenu
        return 1
    fi
    CHROOT_SCRIPT=$(cat <<'CHROOT_SCRIPT'
    set -e
    pacman -S --noconfirm nano
    echo '===(2/5) Region configuration===
You will now configure your locale settings. When you are ready, press Enter.'
    read -r
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    hwclock --systohc
    nano /etc/locale.gen
    locale-gen
    echo uproar > /etc/hostname
    echo '===(3/5) User configuration==='
    read -r -p "Enter a username for the new user: " USERNAME
    if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
        echo "Invalid username."
        exit 1
    fi
    useradd -m "$USERNAME"
    echo "Now enter the password for the user $USERNAME."
    passwd "$USERNAME"
    echo '===(4/5) Bootloader installation==='
    if [ -d "/sys/firmware/efi" ]; then
        echo 'Installing GRUB bootloader for UEFI...'
        pacman -S --noconfirm grub efibootmgr
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
        grub-mkconfig -o /boot/grub/grub.cfg
    else
        echo 'Installing GRUB bootloader for BIOS...'
        pacman -S --noconfirm grub
        grub-install --target=i386-pc "/dev/$1"
        grub-mkconfig -o /boot/grub/grub.cfg
    fi
    echo '===(5/5) Finalizing installation==='
    echo 'Finishing up the installation...'
    pacman -S --noconfirm ly brightnessctl
    systemctl enable ly@tty1.service
    systemctl disable getty@tty1.service
    mkinitcpio -P
    echo 'Installation complete. You can now reboot into your new Uproar installation.'
    exit
CHROOT_SCRIPT
)
    if ! arch-chroot /mnt /bin/bash -c "$CHROOT_SCRIPT" uproar-install "$DISK"; then
        echo "Installation failed inside the target system."
        read -r -p "Press Enter to return to the main menu."
        MainMenu
        return 1
    fi
    exit
}

chrootHelper () {
    clear
    echo "$LOGO"
    echo "
    ----------------------------------------------------
    -                 Chroot helper                    -
    ----------------------------------------------------
    "
    echo "This helper will allow you to chroot into your Uproar installation."
    lsblk
    read -r -p "Enter the boot partition (For example: sda1, sdc1): " BOOTPART
    BOOTPART=$(normalizeDeviceName "$BOOTPART")
    read -r -p "Enter the root partition (For example: sda2, sdc2): " ROOTPART
    ROOTPART=$(normalizeDeviceName "$ROOTPART")
    if ! isBlockDeviceName "$BOOTPART" || ! isBlockDeviceName "$ROOTPART" || [ "$BOOTPART" = "$ROOTPART" ]; then
        echo "Boot and root must be two distinct, existing partition devices."
        read -r -p "Press Enter to return to the main menu."
        MainMenu
        return 1
    fi

    if ! mount "/dev/$ROOTPART" /mnt; then
        echo "Could not mount the root partition."
        read -r -p "Press Enter to return to the main menu."
        MainMenu
        return 1
    fi
    if [ -d "/sys/firmware/efi" ]; then
        BOOT_MOUNT=/mnt/boot/efi
    else
        BOOT_MOUNT=/mnt/boot
    fi
    if ! mkdir -p "$BOOT_MOUNT" || ! mount "/dev/$BOOTPART" "$BOOT_MOUNT"; then
        echo "Could not mount the boot partition."
        umount /mnt
        read -r -p "Press Enter to return to the main menu."
        MainMenu
        return 1
    fi
    if ! arch-chroot /mnt /bin/bash; then
        echo "Could not enter the chroot environment."
    fi
    umount "$BOOT_MOUNT" || echo "Warning: could not unmount $BOOT_MOUNT."
    umount /mnt || echo "Warning: could not unmount /mnt."
    echo "You have exited the chroot environment."
    read -r -p "Press Enter to return to the main menu."
    MainMenu
}


MainMenu () {
    clear
    echo "$LOGO"
    echo "
    ----------------------------------------------------
    -                   Main Menu                      -
    ----------------------------------------------------
    - 1) Disk partitioner                              -
    - 2) Update certificates                           -
    - 3) Install Uproar                                -
    - 4) Chroot helper                                 -
    - 5) Exit                                          -
    ----------------------------------------------------
    "
    read -r -p "Enter your choice: " CHOICE
    case $CHOICE in
        1) partDisk ;;
        2) updateCerts ;;
        3) installUproar ;;
        4) chrootHelper ;;
        5) exit ;;
        *) echo "Invalid choice. Please try again." ; MainMenu ;;
    esac
}

MainMenu