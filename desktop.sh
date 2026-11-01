#!/bin/bash

echo '
You will now choose the configuration you wish to use.
The following desktops have been configured specifically for Uproar.
More desktops will be added in the near future.

--- Desktops ---
1. xfce4 (Main configuration for Uproar)

--- Extras ---
(none)

Choose a number you wish to use.'

if ! read -r -p "Desktop choice: " DESKTOP; then
    echo "Could not read desktop choice." >&2
    exit 1
fi

if [ "$DESKTOP" != "1" ]; then
    echo "Invalid choice. Select 1 for xfce4." >&2
    exit 1
fi

if ! arch-chroot /mnt /bin/bash -s -- "$DESKTOP" <<'CHROOT_SCRIPT'
set -e

case "$1" in
    1)
        echo 'xfce4 will be installed.'
        pacman -S --noconfirm xfce4 xfce4-goodies xorg mousepad firefox networkmanager network-manager-applet pulseaudio
        systemctl enable NetworkManager

        mkdir -p \
            /usr/share/backgrounds/xfce \
            /usr/share/uproar \
            /etc/xdg/xfce4/panel \
            /etc/xdg/xfce4/xfconf/xfce-perchannel-xml

        curl --fail --location --show-error --output /usr/share/backgrounds/xfce/uproar-default.png \
            https://uproar.sylveondev.xyz/images/defaultbg.png
        curl --fail --location --show-error --output /usr/share/uproar/icon.png \
            https://uproar.sylveondev.xyz/images/logo.png
        curl --fail --location --show-error --output /etc/xdg/xfce4/panel/default.xml \
            https://uproar.sylveondev.xyz/configs/xfce4-panel.xml
        curl --fail --location --show-error --output /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml \
            https://uproar.sylveondev.xyz/configs/xfce4-desktop.xml
        curl --fail --location --show-error --output /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
            https://uproar.sylveondev.xyz/configs/xsettings.xml
        ;;
    *)
        echo "Invalid desktop choice in chroot." >&2
        exit 1
        ;;
esac
CHROOT_SCRIPT
then
    echo "Desktop setup failed inside the target system." >&2
    exit 1
fi
