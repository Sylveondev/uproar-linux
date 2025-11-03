#!/bin/sh

# This is the text based interface for Uproar.

echo "===(1/5) Partitioning and base system installation===
First thing first, Uproar needs to know where to install the system.
Warning: Uproar will erase the entire disk, so enter the correct disk."
sleep 3
echo "---"
fdisk -l
echo "---
Enter the disk to write to (For example: sda, mmcblk0)"
read DISK
if [ -n /dev/$DISK ]; then
  echo "Okay, Uproar will be installed to $DISK."
else
  echo "Disk does not exist in the file system."
  exit
fi
echo "---"
if [ -d "/sys/firmware/efi" ]; then
    echo "The system is running in UEFI mode, so the disk will be created in the GPT format."
    sleep 2
    echo "Partitioning with fdisk..."
    echo -e "g\nn\n1\n\n+1G\nn\n2\n\n\nw" | fdisk /dev/$DISK
    echo "Partitioning is complete. Formatting partitions..."
    mkfs.vfat -F 32 /dev/"$DISK"1
    mkfs.ext4 /dev/"$DISK"2
    MAINPART=/dev/"$DISK"2
    BOOTPART=/dev/"$DISK"1
    mount $MAINPART /mnt
    mount --mkdir /dev/"$DISK"1 /mnt/boot
else
    echo "The system is running in BIOS (Legacy) mode, so the disk will be created in the MBR format."
    sleep 2
    echo "Partitioning with fdisk..."
    echo -e "o\nn\np\n1\n\n\nw" | fdisk /dev/$DISK
    echo "Partitioning is complete."
    mkfs.ext4 /dev/"$DISK"1
    MAINPART=/dev/"$DISK"1
    mount $MAINPART /mnt
fi
pacstrap -K /mnt base linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash -c "
pacman -S --noconfirm nano
echo '

===(2/5) Region configuration===
You will now configure your locale settings. When you are ready, press Enter.'
read
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
nano /etc/locale.gen
locale-gen
echo uproar > /etc/hostname
echo '

===(3/5) User configuration===
Next step, we will setup the root user password and create your user. First up, enter a new password for root.'
passwd
echo 'Next, enter your desired username.'
read USERNAME
useradd -m $USERNAME
echo Now enter the password for the user $USERNAME.
passwd $USERNAME
echo 'Good, finishing the installation now.'
echo '---'
mkinitcpio -P
echo '

===(4/5) Desktop profiles===
You will now choose the desktop environment you wish to use.
The following desktops have been configured specifically for Uproar.

1. xfce4
2. jwm
3. hyprland

Choose a number you wish to use.'
read DESKTOP
if [ '$DESKTOP' == '1' ]; then
    echo 'xfce4 will be installed.'
    pacman -S --noconfirm ly
fi
if [ -d '/sys/firmware/efi' ]; then
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=esp --bootloader-id=GRUB
else
    pacman -S --noconfirm grub
    grub-install --target=i386-pc /dev/$DISK
fi
exit
"
echo 'Uproar has finished installing. Restarting in 10 seconds...'
sleep 10
systemctl reboot