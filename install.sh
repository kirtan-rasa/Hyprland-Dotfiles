#!/usr/bin/env bash
#
# install.sh — installer for Hyprland-Dotfiles
#
# Run from the repo root:
#   cd Hyprland-Dotfiles && ./install.sh
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$REPO_DIR/.config"
CONFIG_DST="$HOME/.config"
WALLPAPER_DST="$HOME/Pictures/Wallpapers"
WALLPICKER_DIR="$REPO_DIR/wallpicker-rs"
BIN_DST="$HOME/.local/bin"

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$1"; exit 1; }

# ---------------------------------------------------------------------------
# 0. sanity checks
# ---------------------------------------------------------------------------
[[ -d "$CONFIG_SRC" ]] || die "no .config found next to this script — run from the repo root"
command -v dnf >/dev/null 2>&1 || warn "dnf not found — skipping package install, doing dotfiles/build only"

# ---------------------------------------------------------------------------
# 1. packages (Fedora/dnf)
# ---------------------------------------------------------------------------
PKGS=(
    hyprland hypridle hyprlock
    waybar
    rofi-wayland
    kitty
    dunst
    fastfetch
    cava
    rustup
    gcc gcc-c++ make pkgconf-pkg-config
    gtk4-devel gtk4-layer-shell-devel
    cairo-devel pango-devel gdk-pixbuf2-devel graphene-devel glib2-devel
    grim slurp wl-clipboard      # common Hyprland helpers, remove if unused
)

if command -v dnf >/dev/null 2>&1; then
    log "installing packages via dnf"
    sudo dnf install -y "${PKGS[@]}"
else
    warn "not on Fedora — install these manually: ${PKGS[*]}"
fi

# ---------------------------------------------------------------------------
# 2. rust toolchain
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
# 3. symlink dotfiles (.config/*)
# ---------------------------------------------------------------------------
mkdir -p "$CONFIG_DST"
log "linking .config entries into $CONFIG_DST"
for entry in "$CONFIG_SRC"/*; do
    name="$(basename "$entry")"
    target="$CONFIG_DST/$name"

    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -L "$target" && "$(readlink -f "$target")" == "$(readlink -f "$entry")" ]]; then
            continue  # already correctly linked
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
# 4. wallpapers
# ---------------------------------------------------------------------------
if [[ -d "$REPO_DIR/wallpapers" ]]; then
    mkdir -p "$WALLPAPER_DST"
    log "copying wallpapers to $WALLPAPER_DST"
    cp -n "$REPO_DIR"/wallpapers/* "$WALLPAPER_DST"/ 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 5. build wallpicker-rs
# ---------------------------------------------------------------------------
if [[ -d "$WALLPICKER_DIR" ]]; then
    log "building wallpicker-rs (release)"
    (cd "$WALLPICKER_DIR" && cargo build --release)

    BIN_PATH="$WALLPICKER_DIR/target/release/wallpicker"
    if [[ -f "$BIN_PATH" ]]; then
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
# 6. permissions on helper scripts
# ---------------------------------------------------------------------------
for script in \
    "$CONFIG_DST/hypr/power_menu.sh" \
    "$CONFIG_DST/hypr/scripts/WaybarCava.sh" \
    "$CONFIG_DST/rofi/powermenu.sh"
do
    [[ -e "$script" ]] && chmod +x "$script"
done

log "done. log out/in or restart Hyprland to pick everything up."
