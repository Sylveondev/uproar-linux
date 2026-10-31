#!/bin/sh

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

echo "Uproar is free software, and comes with ABSOLUTELY NO WARRANTY. Usage of this software is at your own risk.
Uproar is experimental software and is not guaranteed to work on all devices. It is highly recommended to have some
level of experience with Linux before using this software.

To continue, press Enter."
read

partDisk () {
    clear
    echo "$LOGO"
    echo "
    ----------------------------------------------------
    -                 Disk partitioner                 -
    ----------------------------------------------------
    "
    lsblk
    echo "
    ...
    Enter the disk to modify (For example: sda, sdc)"
    read DISK
    if [ -n /dev/$DISK ]; then
        echo "Okay, you will now be sent to fdisk to modify your disk.
        
        You will need to create a 1gb partition for the boot partition, and the rest can be used for the root partition.
        Uproar will format the partitions automatically,

        "
        sleep 2
        fdisk /dev/$DISK
        lsblk
        read -p "Where do you want the boot partition to be? (For example: sda1, sdc1)" BOOTPART
        read -p "Where do you want the root partition to be? (For example: sda2, sdc2)" ROOTPART
        echo "Formatting partitions..."
        mkfs.vfat -F 32 /dev/$BOOTPART
        mkfs.ext4 /dev/$ROOTPART
        echo "Mounting partitions..."
        if [ -d "/sys/firmware/efi" ]; then
            mount /dev/$ROOTPART /mnt
            mkdir -p /mnt/boot/efi
            mount --mkdir /dev/$BOOTPART /mnt/boot/efi
        else
            mount /dev/$ROOTPART /mnt
            mkdir -p /mnt/boot
            mount /dev/$BOOTPART /mnt/boot
        fi
        MainMenu
    else
        echo "Disk does not exist in the file system..."
        read -p "Press Enter to return to the main menu."
        MainMenu
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
    pacman -Sy --noconfirm ca-certificates
    echo "Certificates updated successfully."
    read -p "Press Enter to return to the main menu."
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
    sleep 2
    pacstrap -K /mnt base linux linux-firmware
    genfstab -U /mnt >> /mnt/etc/fstab
    arch-chroot /mnt /bin/bash -c "
    pacman -S --noconfirm nano
    echo '===(2/5) Region configuration===
You will now configure your locale settings. When you are ready, press Enter.'
    read
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    hwclock --systohc
    nano /etc/locale.gen
    locale-gen
    echo uproar > /etc/hostname
    echo '===(3/5) User configuration==='
    read -p 'Enter a username for the new user: ' USERNAME
    useradd -m $USERNAME
    echo 'Now enter the password for the user $USERNAME.'
    passwd $USERNAME
    echo '===(4/5) Bootloader installation==='
    if [ -d "/sys/firmware/efi" ]; then
        echo 'Installing GRUB bootloader for UEFI...'
        pacman -S --noconfirm grub efibootmgr
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
        grub-mkconfig -o /boot/grub/grub.cfg
    else
        echo 'Installing GRUB bootloader for BIOS...'
        pacman -S --noconfirm grub
        grub-install --target=i386-pc /dev/$DISK
        grub-mkconfig -o /boot/grub/grub.cfg
    fi
    echo '===(5/5) Finalizing installation==='
    echo 'Finishing up the installation...'
    mkinitcpio -P
    echo 'Installation complete. You can now reboot into your new Uproar installation.'
    exit
    "
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
    read -p "Enter the root partition (For example: sda2, sdc2): " ROOTPART
    mount /dev/$ROOTPART /mnt
    arch-chroot /mnt /bin/bash
    unmount /mnt
    echo "You have exited the chroot environment."
    read -p "Press Enter to return to the main menu."
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
    read -p "Enter your choice: " CHOICE
    case $CHOICE in
        1) partDisk ;;
        2) updateCerts ;;
        3) installUproar ;;
        4) chrootHelper ;;
        5) exit ;;
        *) echo "Invalid choice. Please try again." ; MainMenu ;;
    esac
}