#!/usr/bin/env bash
# Waybar custom module: WiFi status
# Outputs JSON: {"text": ..., "tooltip": ..., "class": ..., "percentage": ...}

# Nerd Font icons (by signal level)
ICON_OFF="󰤭"        # wifi disabled
ICON_NONE="󰤯"       # enabled but not connected
ICON_ETH="󰈀"        # ethernet
ICONS=("󰤟" "󰤢" "󰤥" "󰤨")   # weak -> strong

# Escape a string for JSON (\, ", newlines)
esc() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    printf '%s' "$s"
}

json() {
    # $1 text, $2 tooltip, $3 class, $4 percentage
    # Newlines in the tooltip are passed as a literal \n inside the string
    printf '{"text": "%s", "tooltip": "%s", "class": "%s", "percentage": %s}\n' \
        "$(esc "$1")" "$(esc "$2")" "$(esc "$3")" "${4:-0}"
}

# Is there a wifi adapter at all
if ! nmcli -t -f TYPE device | grep -q '^wifi$'; then
    # No wifi — check ethernet
    if nmcli -t -f TYPE,STATE device | grep -q '^ethernet:connected$'; then
        json "$ICON_ETH" "Ethernet connected" "ethernet" 100
    else
        json "$ICON_OFF" "No network adapters" "disconnected" 0
    fi
    exit 0
fi

# Is WiFi disabled?
if [ "$(nmcli radio wifi)" != "enabled" ]; then
    json "$ICON_OFF" "WiFi is off"$'\n'"Left click — menu" "off" 0
    exit 0
fi

# Active wifi connection
IFACE=$(nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '$2=="wifi" && $3=="connected" {print $1; exit}')

if [ -z "$IFACE" ]; then
    # Fall back to ethernet
    if nmcli -t -f TYPE,STATE device | grep -q '^ethernet:connected$'; then
        json "$ICON_ETH" "Ethernet connected" "ethernet" 100
    else
        json "$ICON_NONE" "WiFi is on, not connected"$'\n'"Left click — menu" "disconnected" 0
    fi
    exit 0
fi

# Active network data
# Format: IN-USE:SSID:SIGNAL:SECURITY
LINE=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list ifname "$IFACE" 2>/dev/null | grep '^\*' | head -n1)
SSID=$(echo "$LINE" | awk -F: '{print $2}')
SIGNAL=$(echo "$LINE" | awk -F: '{print $3}')
SEC=$(echo "$LINE" | awk -F: '{print $4}')
SIGNAL=${SIGNAL:-0}
IP=$(nmcli -g IP4.ADDRESS device show "$IFACE" | head -n1)

# Pick icon by signal level
if   [ "$SIGNAL" -ge 75 ]; then IDX=3
elif [ "$SIGNAL" -ge 50 ]; then IDX=2
elif [ "$SIGNAL" -ge 25 ]; then IDX=1
else IDX=0; fi

# Class for styling
if   [ "$SIGNAL" -lt 25 ]; then CLASS="weak"
else CLASS="connected"; fi

TIP="<b>${SSID}</b>"$'\n'"Signal: ${SIGNAL}%"$'\n'"Security: ${SEC:-open}"$'\n'"IP: ${IP}"$'\n'"Interface: ${IFACE}"
json "${ICONS[$IDX]}" "$TIP" "$CLASS" "$SIGNAL"
