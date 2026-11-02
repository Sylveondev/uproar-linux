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

isPartitionOfDisk () {
    local partition="$1"
    local disk="$2"
    local partition_type parent_name disk_name

    partition_type=$(lsblk -dnro TYPE "/dev/$partition" 2>/dev/null) || return 1
    [ "$partition_type" = "part" ] || return 1
    parent_name=$(lsblk -dnro PKNAME "/dev/$partition" 2>/dev/null) || return 1
    disk_name=$(basename "$(readlink -f "/dev/$disk")") || return 1
    [ "$parent_name" = "$disk_name" ]
}

partitionsShareDisk () {
    local boot_parent root_parent

    boot_parent=$(lsblk -dnro PKNAME "/dev/$1" 2>/dev/null) || return 1
    root_parent=$(lsblk -dnro PKNAME "/dev/$2" 2>/dev/null) || return 1
    [ -n "$boot_parent" ] && [ "$boot_parent" = "$root_parent" ]
}

isMountedDeviceAt () {
    local device="$1"
    local mountpoint="$2"
    local mounted_source

    mountpoint -q "$mountpoint" || return 1
    mounted_source=$(findmnt -rn -e -o SOURCE --mountpoint "$mountpoint") || return 1
    [ "$(readlink -f "$mounted_source")" = "$(readlink -f "/dev/$device")" ]
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
        return 1
    fi
    if [ "$(lsblk -dnro TYPE "/dev/$DISK" 2>/dev/null)" != "disk" ]; then
        echo "Select a whole disk, not a partition."
        return 1
    fi

    echo "Okay, you will now be sent to fdisk to modify your disk.
        
        You will need to create a 1gb partition for the boot partition, and the rest can be used for the root partition.
        Uproar will format the partitions automatically,

        "
    sleep 2
    if ! fdisk "/dev/$DISK"; then
        echo "Partitioning failed."
        return 1
    fi

    lsblk
    read -r -p "Where do you want the boot partition to be? (For example: sda1, sdc1): " BOOTPART
    BOOTPART=$(normalizeDeviceName "$BOOTPART")
    read -r -p "Where do you want the root partition to be? (For example: sda2, sdc2): " ROOTPART
    ROOTPART=$(normalizeDeviceName "$ROOTPART")
    if ! isBlockDeviceName "$BOOTPART" || ! isBlockDeviceName "$ROOTPART" ||
        [ "$BOOTPART" = "$ROOTPART" ] ||
        ! isPartitionOfDisk "$BOOTPART" "$DISK" ||
        ! isPartitionOfDisk "$ROOTPART" "$DISK"; then
        echo "Boot and root must be distinct partitions of the selected disk."
        return 1
    fi

    echo "Formatting partitions..."
    if ! mkfs.vfat -F 32 "/dev/$BOOTPART" || ! mkfs.ext4 "/dev/$ROOTPART"; then
        echo "Partition formatting failed."
        return 1
    fi

    echo "Mounting partitions..."
    if ! mount "/dev/$ROOTPART" /mnt; then
        echo "Could not mount the root partition."
        return 1
    fi
    if [ -d "/sys/firmware/efi" ]; then
        BOOT_MOUNT=/mnt/boot/efi
    else
        BOOT_MOUNT=/mnt/boot
    fi
    if ! mkdir -p "$BOOT_MOUNT" || ! mount "/dev/$BOOTPART" "$BOOT_MOUNT"; then
        echo "Could not mount the boot partition."
        umount /mnt || echo "Warning: could not unmount /mnt."
        return 1
    fi
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
        return 1
    fi
    echo "Certificates updated successfully."
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
    if ! isBlockDeviceName "${DISK:-}" ||
        ! isPartitionOfDisk "${BOOTPART:-}" "${DISK:-}" ||
        ! isPartitionOfDisk "${ROOTPART:-}" "${DISK:-}"; then
        echo "Select and partition a valid target disk before installing."
        return 1
    fi
    if [ -d "/sys/firmware/efi" ]; then
        BOOT_MOUNT=/mnt/boot/efi
    else
        BOOT_MOUNT=/mnt/boot
    fi
    if ! isMountedDeviceAt "$ROOTPART" /mnt ||
        ! isMountedDeviceAt "$BOOTPART" "$BOOT_MOUNT"; then
        echo "The selected root and boot partitions must be mounted at /mnt and $BOOT_MOUNT."
        return 1
    fi
    sleep 2
    if ! pacstrap -K /mnt base linux linux-firmware; then
        echo "Base system installation failed."
        return 1
    fi
    FSTAB_TMP=$(mktemp /mnt/etc/fstab.XXXXXX) || {
        echo "Could not create a temporary filesystem table."
        return 1
    }
    if ! genfstab -U /mnt > "$FSTAB_TMP"; then
        rm -f "$FSTAB_TMP"
        echo "Could not write the filesystem table."
        return 1
    fi
    if ! mv "$FSTAB_TMP" /mnt/etc/fstab; then
        rm -f "$FSTAB_TMP"
        echo "Could not install the generated filesystem table."
        return 1
    fi
    CHROOT_SCRIPT=$(cat <<'CHROOT_SCRIPT'
    set -e
    pacman -S --noconfirm nano polkit
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
    echo "Now enter a new password for root."
    passwd
    pacman -S --noconfirm sudo
    echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers
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
    pacman -S --noconfirm ly brightnessctl networkmanager
    systemctl enable ly@tty1.service
    systemctl disable getty@tty1.service
    systemctl enable NetworkManager
    EXTRAS_TMP=$(mktemp /usr/bin/uproar-extras.sh.XXXXXX)
    trap 'rm -f "$EXTRAS_TMP"' EXIT
    curl --fail --location --show-error --output "$EXTRAS_TMP" https://uproar.sylveondev.xyz/extras.sh
    install -m 755 "$EXTRAS_TMP" /usr/bin/uproar-extras.sh
    rm -f "$EXTRAS_TMP"
    mkinitcpio -P
    echo '-----------
    Installation complete. You can now reboot into your new Uproar installation.

    Notes:
    - After rebooting, you can run the command "sudo uproar-extras.sh" to install a desktop environment and other extras.
    - The password for sudo commands is your password. The root password is mainly for the root user at login.
    - If you need to chroot into your installation, run this script again from the live environment and select the chroot helper option.
    - To dual boot uproar, run "sudo uproar-extras.sh" and select dual boot helper.'
    exit
CHROOT_SCRIPT
)
    if ! arch-chroot /mnt /bin/bash -c "$CHROOT_SCRIPT" uproar-install "$DISK"; then
        echo "Installation failed inside the target system."
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
    if ! isBlockDeviceName "$BOOTPART" || ! isBlockDeviceName "$ROOTPART" ||
        [ "$BOOTPART" = "$ROOTPART" ] ||
        [ "$(lsblk -dnro TYPE "/dev/$BOOTPART" 2>/dev/null)" != "part" ] ||
        [ "$(lsblk -dnro TYPE "/dev/$ROOTPART" 2>/dev/null)" != "part" ] ||
        ! partitionsShareDisk "$BOOTPART" "$ROOTPART"; then
        echo "Boot and root must be distinct, existing partition devices."
        return 1
    fi

    if ! mount "/dev/$ROOTPART" /mnt; then
        echo "Could not mount the root partition."
        return 1
    fi
    if [ -d "/sys/firmware/efi" ]; then
        BOOT_MOUNT=/mnt/boot/efi
    else
        BOOT_MOUNT=/mnt/boot
    fi
    if ! mkdir -p "$BOOT_MOUNT" || ! mount "/dev/$BOOTPART" "$BOOT_MOUNT"; then
        echo "Could not mount the boot partition."
        umount /mnt || echo "Warning: could not unmount /mnt."
        return 1
    fi
    CHROOT_STATUS=0
    if ! arch-chroot /mnt /bin/bash; then
        echo "Could not enter the chroot environment."
        CHROOT_STATUS=1
    fi
    if ! umount "$BOOT_MOUNT"; then
        echo "Warning: could not unmount $BOOT_MOUNT."
        CHROOT_STATUS=1
    fi
    if ! umount /mnt; then
        echo "Warning: could not unmount /mnt."
        CHROOT_STATUS=1
    fi
    if [ "$CHROOT_STATUS" -eq 0 ]; then
        echo "You have exited the chroot environment."
    fi
    return "$CHROOT_STATUS"
}


MainMenu () {
    while true; do
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
        if ! read -r -p "Enter your choice: " CHOICE; then
            echo "Could not read menu choice." >&2
            return 1
        fi
        ACTION_STATUS=0
        case "$CHOICE" in
            1) partDisk || ACTION_STATUS=$? ;;
            2) updateCerts || ACTION_STATUS=$? ;;
            3) installUproar || ACTION_STATUS=$? ;;
            4) chrootHelper || ACTION_STATUS=$? ;;
            5) return 0 ;;
            *) echo "Invalid choice. Please try again." ; read -r -p "Press Enter to continue." ;;
        esac
        if [ "$ACTION_STATUS" -ne 0 ]; then
            read -r -p "Action failed. Press Enter to return to the menu."
        fi
    done
}

MainMenu