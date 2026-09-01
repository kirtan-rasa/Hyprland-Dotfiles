#!/usr/bin/env bash

THEME="$HOME/.config/rofi/powermenu.rasi"

sleep_icon="󰤄"        # Sleep
reboot_icon="󰜉"       # Reboot
logout_icon="󰍃"       # Logout
hibernate_icon="󰒲"    # Hibernate
shutdown_icon="⏻"      # Shutdown

options="$sleep_icon  Suspend\n$reboot_icon  Reboot\n$logout_icon  Log Out\n$hibernate_icon  Hybrnate\n$shutdown_icon  Shutdown"

chosen=$(echo -e "$options" | rofi -dmenu \
    -i \
    -p "" \
    -theme "$THEME" \
    -no-custom \
    -selected-row 0)


case "$chosen" in
    *"Suspend"*)
        systemctl suspend
        ;;
    *"Reboot"*)
        systemctl reboot
        ;;
    *"Log Out"*)

        hyprctl dispatch exit
        ;;
    *"Hybrnate"*)
        systemctl hibernate
        ;;
    *"Shutdown"*)
        systemctl poweroff
        ;;
    *)
        exit 0
        ;;
esac
