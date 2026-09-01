#!/bin/bash

CHOICE=$(printf "󰐥 Shutdown\n󰜉 Reboot\n󰤄 Suspend\n󰍃 Logout\n󰌾 Hibernate" | wofi --dmenu --prompt "Power")

case "$CHOICE" in
    "󰐥 Shutdown")
        systemctl poweroff
        ;;
    "󰜉 Reboot")
        systemctl reboot
        ;;
    "󰤄 Suspend")
        systemctl suspend
        ;;
    "󰍃 Logout")
        hyprctl dispatch exit
        ;;
    "󰌾 Hibernate")
        systemctl hibernate
        ;;
esac
