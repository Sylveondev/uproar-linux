#!/bin/sh

echo "(1/2) Uproar needs to increase the ramdisk size to 1gb so the installer can be installed.\n\nPress Enter to continue..."
read
clear
echo ":: Expanding ramdisk"
mount -o remount,size=1G /run/archiso/cowspace
clear
read
echo "(2/2) Uproar will now install the needed tools to open the installer.\n\nPress Enter to continue..."
read
clear
echo ":: Installing dependencies"
pacman -Sy --noconfirm --quiet --noprogressbar xorg-server xorg-xinit fluxbox
echo ":: Configuring"
curl -o- https://uproar.sylveondev.xyz/configs/xinitrc.sh >> /root/.xinitrc
clear
echo ":: Starting installer"
xinit