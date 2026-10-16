#!/usr/bin/env bash
CLASS="com.user.calendar"
pkill -f -- "--class=$CLASS" && exit 0
exec ghostty --class="$CLASS" --title="Calendar" -e calcurse
