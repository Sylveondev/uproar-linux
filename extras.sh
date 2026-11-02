#!/bin/bash

# This is the text based interface for Uproar.
# This script is to run inside of the target system after the installation is complete.
# Do not run it inside of the live environment, as it will not work properly.

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




installDesktop () {
    clear
    echo '
You will now choose the configuration you wish to use.
The following desktops have been configured specifically for Uproar.
More desktops will be added in the near future.

--- Desktops ---
1. xfce4 (Main configuration for Uproar)
2. cinnamon

--- Extras ---
(none)

Choose a number you wish to use.'

    if ! read -r -p "Desktop choice: " DESKTOP; then
        echo "Could not read desktop choice." >&2
        return 1
    fi

    case "$DESKTOP" in
    1)
        echo 'xfce4 will be installed.'
        if ! pacman -S --noconfirm xfce4 xfce4-goodies xorg mousepad firefox networkmanager network-manager-applet pulseaudio; then
            echo "Could not install XFCE packages." >&2
            return 1
        fi
        if ! systemctl enable NetworkManager; then
            echo "Could not enable NetworkManager." >&2
            return 1
        fi
        if ! mkdir -p \
            /usr/share/backgrounds/xfce \
            /usr/share/uproar \
            /etc/xdg/xfce4/panel \
            /etc/xdg/xfce4/xfconf/xfce-perchannel-xml; then
            echo "Could not create XFCE configuration directories." >&2
            return 1
        fi

        if ! curl --fail --location --show-error --output /usr/share/backgrounds/xfce/uproar-default.png \
            https://uproar.sylveondev.xyz/images/defaultbg.png
        then
            echo "Could not download the XFCE background." >&2
            return 1
        fi
        if ! curl --fail --location --show-error --output /usr/share/uproar/icon.png \
            https://uproar.sylveondev.xyz/images/logo.png
        then
            echo "Could not download the Uproar icon." >&2
            return 1
        fi
        if ! curl --fail --location --show-error --output /etc/xdg/xfce4/panel/default.xml \
            https://uproar.sylveondev.xyz/configs/xfce4-panel.xml
        then
            echo "Could not download the XFCE panel configuration." >&2
            return 1
        fi
        if ! curl --fail --location --show-error --output /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml \
            https://uproar.sylveondev.xyz/configs/xfce4-desktop.xml
        then
            echo "Could not download the XFCE desktop configuration." >&2
            return 1
        fi
        if ! curl --fail --location --show-error --output /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
            https://uproar.sylveondev.xyz/configs/xsettings.xml
        then
            echo "Could not download the XFCE settings configuration." >&2
            return 1
        fi
        ;;
    2)
        echo 'Cinnamon will be installed.'
        if ! pacman -S --noconfirm cinnamon xorg mousepad firefox networkmanager network-manager-applet pulseaudio; then
            echo "Could not install Cinnamon packages." >&2
            return 1
        fi
        if ! systemctl enable NetworkManager; then
            echo "Could not enable NetworkManager." >&2
            return 1
        fi
        ;;
    *)
        echo "Invalid choice. Select 1 for XFCE or 2 for Cinnamon." >&2
        return 1
        ;;
    esac

    echo "Desktop installation completed."
    read -r -p "Press Enter to return to the main menu."
}

installSoftware () {
    clear
    echo "
    ----------------------------------------------------
    -                 Software Installer               -
    ----------------------------------------------------
    "
    echo "This feature is currently under development."
    read -r -p "Press Enter to return to the main menu."
}

dualBootHelper () {
    clear
    echo "$LOGO"
    echo "
    ----------------------------------------------------
    -                 Dual Boot Helper                 -
    ---------------------------------------------------- 
    "
    if ! pacman -S --noconfirm os-prober; then
        echo "Could not install os-prober." >&2
        return 1
    fi
    if [ ! -f /etc/default/grub ]; then
        echo "GRUB configuration file /etc/default/grub was not found." >&2
        return 1
    fi
    if grep -q '^GRUB_DISABLE_OS_PROBER=' /etc/default/grub; then
        if ! sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub; then
            echo "Could not enable os-prober in /etc/default/grub." >&2
            return 1
        fi
    elif ! printf '\nGRUB_DISABLE_OS_PROBER=false\n' >> /etc/default/grub; then
        echo "Could not add the os-prober setting to /etc/default/grub." >&2
        return 1
    fi
    if ! grub-mkconfig -o /boot/grub/grub.cfg; then
        echo "Could not regenerate the GRUB configuration." >&2
        return 1
    fi
    echo "Dual-boot detection is enabled in the GRUB configuration."
    read -r -p "Press Enter to return to the main menu."
}

MainMenu () {
    while true; do
        clear
        echo "$LOGO"
        echo "
    ----------------------------------------------------
    -                  Extras Menu                     -
    ----------------------------------------------------
    - 1) Install desktop                               -
    - 2) Install software                              -
    - 3) Dual boot helper                              -
    - 4) Exit                                          -
    ----------------------------------------------------
    "
        if ! read -r -p "Enter your choice: " CHOICE; then
            echo "Could not read menu choice." >&2
            return 1
        fi
        case "$CHOICE" in
            1)
                if ! installDesktop; then
                    read -r -p "Desktop installation failed. Press Enter to return to the menu."
                fi
                ;;
            2) installSoftware ;;
            3)
                if ! dualBootHelper; then
                    read -r -p "Dual-boot setup failed. Press Enter to return to the menu."
                fi
                ;;
            4) return 0 ;;
            *) echo "Invalid choice. Please try again." ; read -r -p "Press Enter to continue." ;;
        esac
    done
}

MainMenu