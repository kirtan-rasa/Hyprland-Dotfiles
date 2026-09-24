#!/usr/bin/env bash
# WiFi control menu for waybar (rofi + nmcli)

THEME="$HOME/.config/rofi/wifi.rasi"
TERMINAL="${TERMINAL:-kitty}"

# Nerd Font icons
I_ON="󰖩"
I_OFF="󰖪"
I_SCAN="󰑓"
I_LOCK="󰌾"
I_OPEN="󰌿"
I_CONN="󰄬"
I_FORGET="󰩺"
I_EDIT="󰒓"
I_DISC="󰅖"
SIGNAL_ICONS=("󰤟" "󰤢" "󰤥" "󰤨")

notify() { command -v notify-send >/dev/null && notify-send -a "WiFi" -i network-wireless "$1" "$2"; }

rofi_menu() {
    # $1 — prompt, rest — extra rofi params; list is read from stdin
    local prompt="$1"; shift
    rofi -dmenu -i -p "$prompt" -theme "$THEME" "$@"
}

signal_icon() {
    local s=$1
    if   [ "$s" -ge 75 ]; then echo "${SIGNAL_ICONS[3]}"
    elif [ "$s" -ge 50 ]; then echo "${SIGNAL_ICONS[2]}"
    elif [ "$s" -ge 25 ]; then echo "${SIGNAL_ICONS[1]}"
    else echo "${SIGNAL_ICONS[0]}"; fi
}

# ---------------------------------------------------------------- Connect
connect_to() {
    local ssid="$1" security="$2"

    # Saved profile — connect without a password
    if nmcli -t -f NAME connection show | grep -Fxq "$ssid"; then
        if nmcli connection up id "$ssid" >/dev/null 2>&1; then
            notify "Connected" "$ssid"
        else
            notify "Error" "Failed to connect to $ssid"
        fi
        return
    fi

    # Open network
    if [ -z "$security" ] || [ "$security" = "--" ]; then
        if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
            notify "Connected" "$ssid"
        else
            notify "Error" "Failed to connect to $ssid"
        fi
        return
    fi

    # Secured network — ask for password
    local pass
    pass=$(rofi -dmenu -password -p "Password for $ssid" -theme "$THEME" \
                -mesg "Enter — connect, Esc — cancel" < /dev/null)
    [ -z "$pass" ] && return

    if nmcli device wifi connect "$ssid" password "$pass" >/dev/null 2>&1; then
        notify "Connected" "$ssid"
    else
        # Remove the broken profile if one got created
        nmcli connection delete id "$ssid" >/dev/null 2>&1
        notify "Error" "Wrong password or network unavailable: $ssid"
    fi
}

# ---------------------------------------------------------- Network actions
network_actions() {
    local ssid="$1" active="$2"
    local opts=""

    if [ "$active" = "yes" ]; then
        opts="$I_DISC  Disconnect"
    else
        opts="$I_CONN  Connect"
    fi

    if nmcli -t -f NAME connection show | grep -Fxq "$ssid"; then
        opts+=$'\n'"$I_FORGET  Forget network"
    fi

    local choice
    choice=$(printf '%s' "$opts" | rofi_menu "$ssid" -lines 3)
    case "$choice" in
        *"Disconnect"*)     nmcli connection down id "$ssid" >/dev/null 2>&1 && notify "Disconnected" "$ssid" ;;
        *"Connect"*)        return 10 ;;   # signal to caller: connect
        *"Forget"*)         nmcli connection delete id "$ssid" >/dev/null 2>&1 && notify "Network forgotten" "$ssid" ;;
    esac
    return 0
}

# ------------------------------------------------------------------ Main menu
main_menu() {
    local state
    state=$(nmcli radio wifi)

    # WiFi is off — only offer to turn it on
    if [ "$state" != "enabled" ]; then
        local c
        c=$(printf '%s  Turn on WiFi\n' "$I_ON" | rofi_menu "WiFi is off")
        [ -n "$c" ] && nmcli radio wifi on && notify "WiFi" "Enabled" && sleep 1.5 && main_menu
        return
    fi

    # Rescan in the background and grab a fresh list
    nmcli device wifi rescan >/dev/null 2>&1

    declare -A SEC_MAP ACTIVE_MAP
    local entries=""
    local seen=""

    # IN-USE:SSID:SIGNAL:SECURITY  (sorted by signal)
    while IFS=: read -r inuse ssid signal sec; do
        # nmcli escapes colons in SSID as \:
        [ -z "$ssid" ] && continue
        case "$seen" in *"|$ssid|"*) continue ;; esac
        seen+="|$ssid|"

        local sicon lock mark
        sicon=$(signal_icon "${signal:-0}")
        if [ -z "$sec" ] || [ "$sec" = "--" ]; then lock="$I_OPEN"; else lock="$I_LOCK"; fi
        if [ "$inuse" = "*" ]; then mark="$I_CONN "; ACTIVE_MAP["$ssid"]="yes"; else mark="   "; fi

        SEC_MAP["$ssid"]="$sec"
        entries+="${mark}${sicon}  ${ssid}  ${lock}  ${signal}%"$'\n'
    done < <(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null \
             | sed 's/\\:/∶/g' | sort -t: -k3 -nr)

    local header="$I_SCAN  Refresh list"$'\n'"$I_EDIT  Advanced settings (nmtui)"$'\n'"$I_OFF  Turn off WiFi"
    local choice
    choice=$(printf '%s\n%s' "$header" "$entries" | sed '/^$/d' | rofi_menu "WiFi")

    [ -z "$choice" ] && exit 0

    case "$choice" in
        *"Refresh list"*)
            nmcli device wifi rescan >/dev/null 2>&1
            sleep 1.5
            main_menu
            return ;;
        *"Advanced settings"*)
            $TERMINAL -e nmtui &
            return ;;
        *"Turn off WiFi"*)
            nmcli radio wifi off && notify "WiFi" "Disabled"
            return ;;
    esac

    # Extract SSID from the selected line:
    # format: "<mark><sicon>  SSID  <lock>  NN%"
    local ssid
    ssid=$(echo "$choice" | sed -E 's/^(󰄬 |   )//; s/^[^ ]+  //; s/  [^ ]+  [0-9]+%$//')
    ssid=${ssid//∶/:}

    network_actions "$ssid" "${ACTIVE_MAP[$ssid]}"
    if [ $? -eq 10 ]; then
        connect_to "$ssid" "${SEC_MAP[$ssid]}"
    fi
}

main_menu
