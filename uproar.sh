#!/bin/sh

echo "(1/3) Uproar needs to increase the ramdisk size to 1gb so the installer can be installed.\n\nSleeping for 5 seconds..."
sleep 5
echo ":: Expanding ramdisk"
mount -o remount,size=1G /run/archiso/cowspace
echo "(2/3) Uproar will now install the needed tools to open the installer. Sleeping for 5 seconds..."
sleep 5
echo ":: Installing dependencies"
pacman -Sy --noconfirm --quiet --noprogressbar xorg-server xorg-xinit fluxbox tk
echo ":: Configuring"
curl -o- https://uproar.sylveondev.xyz/configs/xinitrc.sh >> /root/.xinitrc
curl -o- https://uproar.sylveondev.xyz/installer.py >> /root/installer.py
clear
echo "(3/3) Starting graphic installer. Please wait..."
sleep 2
xinit