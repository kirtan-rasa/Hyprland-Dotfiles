#!/usr/bin/env bash
#
# install.sh — installer for Hyprland-Dotfiles
#

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$REPO_DIR/.config"
CONFIG_DST="$HOME/.config"
WALLPAPER_DST="$HOME/Pictures/Wallpapers"
WALLPICKER_DIR="$REPO_DIR/wallpicker-rs"
WALLPICKER_HOME="$HOME/wallpicker-rs"
BIN_DST="$HOME/.local/bin"
FONT_DIR="$HOME/.local/share/fonts"

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$1"; exit 1; }

# ---------------------------------------------------------------------------
# 0. sanity checks
# ---------------------------------------------------------------------------
[[ -d "$CONFIG_SRC" ]] || die "no .config found next to this script — run from the repo root"
command -v dnf >/dev/null 2>&1 || warn "dnf not found — skipping package install, doing dotfiles/build only"

# ---------------------------------------------------------------------------
# 1. COPR repositories
# ---------------------------------------------------------------------------
if command -v dnf >/dev/null 2>&1; then
    log "enabling COPR repositories"

    # ghostty terminal
    sudo dnf copr enable -y scottames/ghostty

    # Hyprland
    sudo dnf copr enable -y lionheartp/Hyprland
else
    warn "dnf not found — skipping COPR setup"
fi

# ---------------------------------------------------------------------------
# 2. packages (Fedora/dnf)
# ---------------------------------------------------------------------------
PKGS=(
    ghostty
    hyprland hypridle hyprlock
    waybar
    rofi-wayland
    dunst
    fastfetch
    cava
    NetworkManager NetworkManager-tui
    rustup
    gcc gcc-c++ make pkgconf-pkg-config
    gtk4-devel gtk4-layer-shell-devel
    cairo-devel pango-devel gdk-pixbuf2-devel graphene-devel glib2-devel
    grim slurp wl-clipboard
    flameshot
    curl wget unzip fontconfig
)

if command -v dnf >/dev/null 2>&1; then
    log "installing packages via dnf"
    sudo dnf install -y "${PKGS[@]}"
else
    warn "not on Fedora — install these manually: ${PKGS[*]}"
fi

log "note: ghostty replaces kitty as the default terminal"
log "note: several autostart apps need manual/flatpak install if you want them:"
log "      zen browser, telegram, anytype, spotify, figma-linux, bitwarden, kdeconnect-app, FlClashX (VPN), vicinae"

# ---------------------------------------------------------------------------
# 3. awww (wallpaper daemon, via lionheartp/Hyprland or cargo)
# ---------------------------------------------------------------------------
if ! command -v awww >/dev/null 2>&1; then
    log "installing awww"

    if command -v dnf >/dev/null 2>&1; then
        # lionheartp/Hyprland may carry awww; try it first
        if sudo dnf install -y awww 2>/dev/null; then
            log "installed awww via dnf"
        else
            warn "awww not available in enabled repos — falling back to cargo"
        fi
    fi

    # fallback: build from source via cargo
    if ! command -v awww >/dev/null 2>&1; then
        if command -v cargo >/dev/null 2>&1; then
            log "building awww from source via cargo"
            cargo install awww --locked || warn "cargo install awww failed — install it manually"
        else
            warn "cargo not available — cannot build awww from source"
        fi
    fi
else
    log "awww already installed, skipping"
fi

# ---------------------------------------------------------------------------
# 4. rust toolchain
# ---------------------------------------------------------------------------
if ! command -v cargo >/dev/null 2>&1; then
    if command -v rustup >/dev/null 2>&1; then
        log "setting up rust toolchain"
        rustup default stable
    else
        die "cargo not found and rustup unavailable — install rust manually"
    fi
fi

# ---------------------------------------------------------------------------
# 5. symlink dotfiles (.config/*)
# ---------------------------------------------------------------------------
mkdir -p "$CONFIG_DST"
log "linking .config entries into $CONFIG_DST"
for entry in "$CONFIG_SRC"/*; do
    name="$(basename "$entry")"
    target="$CONFIG_DST/$name"

    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -L "$target" && "$(readlink -f "$target")" == "$(readlink -f "$entry")" ]]; then
            continue
        fi
        backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
        warn "backing up existing $target -> $backup"
        mv "$target" "$backup"
    fi

    ln -s "$entry" "$target"
    log "linked $name"
done

# .zshrc / .vimrc at repo root, if present
for rc in .zshrc .vimrc; do
    if [[ -f "$REPO_DIR/$rc" ]]; then
        target="$HOME/$rc"
        if [[ -L "$target" && "$(readlink -f "$target")" == "$(readlink -f "$REPO_DIR/$rc")" ]]; then
            continue
        fi
        if [[ -e "$target" || -L "$target" ]]; then
            backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
            warn "backing up existing $target -> $backup"
            mv "$target" "$backup"
        fi
        ln -s "$REPO_DIR/$rc" "$target"
        log "linked $rc"
    fi
done

# ---------------------------------------------------------------------------
# 6. wallpapers
# ---------------------------------------------------------------------------
if [[ -d "$REPO_DIR/wallpapers" ]]; then
    mkdir -p "$WALLPAPER_DST"
    log "copying wallpapers to $WALLPAPER_DST"
    cp -n "$REPO_DIR"/wallpapers/* "$WALLPAPER_DST"/ || true
fi

# ---------------------------------------------------------------------------
# 7. build wallpicker-rs and move to home directory
# ---------------------------------------------------------------------------
if [[ -d "$WALLPICKER_DIR" ]]; then
    log "building wallpicker-rs (release)"
    (cd "$WALLPICKER_DIR" && cargo build --release)

    BIN_PATH="$WALLPICKER_DIR/target/release/wallpicker"
    if [[ -f "$BIN_PATH" ]]; then
        # move to home directory first (backup if it already exists)
        if [[ -e "$WALLPICKER_HOME" ]]; then
            backup="$WALLPICKER_HOME.bak.$(date +%Y%m%d%H%M%S)"
            warn "backing up existing $WALLPICKER_HOME -> $backup"
            mv "$WALLPICKER_HOME" "$backup"
        fi
        log "moving $WALLPICKER_DIR -> $WALLPICKER_HOME"
        mv "$WALLPICKER_DIR" "$WALLPICKER_HOME"

        # repoint to the new binary location
        BIN_PATH="$WALLPICKER_HOME/target/release/wallpicker"
        mkdir -p "$BIN_DST"
        install -Dm755 "$BIN_PATH" "$BIN_DST/wallpicker"
        log "installed wallpicker to $BIN_DST/wallpicker"
        case ":$PATH:" in
            *":$BIN_DST:"*) ;;
            *) warn "$BIN_DST is not on your PATH — add: export PATH=\"\$PATH:$BIN_DST\"" ;;
        esac
    else
        warn "build succeeded but binary not found at $BIN_PATH — check target/release manually"
    fi
else
    warn "wallpicker-rs directory not found, skipping"
fi

# ---------------------------------------------------------------------------
# 8. Nerd Fonts (JetBrainsMono + JetBrainsMonoNL)
# ---------------------------------------------------------------------------
log "installing JetBrainsMono Nerd Fonts"
mkdir -p "$FONT_DIR"

FONTS=("JetBrainsMono" "JetBrainsMonoNL")

for font in "${FONTS[@]}"; do
    tmp_zip="$(mktemp "/tmp/${font}-nerd-font.XXXXXX.zip")"
    url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font}.zip"

    log "downloading $font"
    if ! curl -fsSL -o "$tmp_zip" "$url"; then
        warn "failed to download $font — skipping"
        rm -f "$tmp_zip"
        continue
    fi

    dest="$FONT_DIR/$font"
    mkdir -p "$dest"
    log "extracting $font -> $dest"
    unzip -oq "$tmp_zip" -d "$dest"
    rm -f "$tmp_zip"
    log "installed $font"
done

if command -v fc-cache >/dev/null 2>&1; then
    log "rebuilding font cache"
    fc-cache -fv >/dev/null 2>&1 || warn "fc-cache failed, run manually: fc-cache -fv"
fi

# ---------------------------------------------------------------------------
# 9. permissions on helper scripts
# ---------------------------------------------------------------------------
for script in \
    "$CONFIG_DST/hypr/power_menu.sh" \
    "$CONFIG_DST/hypr/scripts/WaybarCava.sh" \
    "$CONFIG_DST/rofi/powermenu.sh" \
    "$CONFIG_DST/waybar/scripts/WaybarWifi.sh" \
    "$CONFIG_DST/waybar/scripts/WifiMenu.sh"
do
    if [[ -e "$script" ]]; then
        chmod +x "$script"
    fi
done

log "done. log out/in or restart Hyprland to pick everything up."
