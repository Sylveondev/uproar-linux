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
    mkdir -p /mnt/boot/efi
    mount --mkdir /dev/"$DISK"1 /mnt/boot/efi
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
exit
"

echo 'Next, enter your desired username.'
read USERNAME
arch-chroot /mnt /bin/bash -c "
useradd -m $USERNAME
echo Now enter the password for the user $USERNAME.
passwd $USERNAME
echo 'Good, finishing the installation now.'
echo '---'
mkinitcpio -P
exit
"
echo '

===(4/5) Desktop profiles===
You will now choose the desktop environment you wish to use.
The following desktops have been configured specifically for Uproar.
More desktops will be added in the near future.

1. xfce4

Choose a number you wish to use.'
read DESKTOP
arch-chroot /mnt /bin/bash -c "
if [ '$DESKTOP' == '1' ]; then
    echo 'xfce4 will be installed.'
    pacman -S --noconfirm ly xfce4 xfce4-goodies xorg mousepad firefox networkmanager network-manager-applet pulseaudio
    systemctl enable NetworkManager
    systemctl enable ly
    curl -o /usr/share/backgrounds/xfce/uproar-default.png https://images2.imgbox.com/47/d4/Jlp1kCAz_o.png
    mkdir /usr/share/uproar
    curl -o /usr/share/uproar/icon.png https://images2.imgbox.com/84/58/RYhvmWX2_o.png
    mkdir /etc
    curl -o /etc/xdg/xfce4/panel/default.xml https://uproar.sylveondev.xyz/configs/xfce4-panel.xml
    curl -o /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml https://uproar.sylveondev.xyz/configs/xfce4-desktop.xml
    curl -o /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml https://uproar.sylveondev.xyz/configs/xsettings.xml
fi
if [ -d '/sys/firmware/efi' ]; then
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/mnt/boot/efi --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
else
    pacman -S --noconfirm grub
    grub-install --target=i386-pc /dev/$DISK
    grub-mkconfig -o /boot/grub/grub.cfg
fi
exit
"
echo '---
You will now be sent to a chroot of your newly installed system.
This is so you can perform any final tasks like installing drivers and packages to make sure everything is ready to go.
When you are ready, type "exit" to restart your pc and start using your new installation.
---'
arch-chroot /mnt
echo 'Uproar has finished installing. Restarting in 5 seconds...'
sleep 5
systemctl reboot