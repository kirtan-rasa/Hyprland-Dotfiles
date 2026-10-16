#!/usr/bin/env bash
#
# install.sh — installer for Hyprland-Dotfiles
#

set -Eeuo pipefail
shopt -s nullglob

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$REPO_DIR/.config"
CONFIG_DST="$HOME/.config"
WALLPAPER_DST="$HOME/Pictures/Wallpapers"
WALLPICKER_DIR="$REPO_DIR/wallpicker-rs"
WALLPICKER_HOME="$HOME/wallpicker-rs"
BIN_DST="$HOME/.local/bin"
FONT_DIR="$HOME/.local/share/fonts"
STAMP="$(date +%Y%m%d%H%M%S)"

TOTAL_STEPS=9
STEP=0
WARNINGS=()

# ---------------------------------------------------------------------------
# output helpers
# ---------------------------------------------------------------------------
log()  { printf '\033[1;32m[+]\033[0m %s\n' "$1"; }
note() { printf '\033[1;34m[i]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; WARNINGS+=("$1"); }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$1"; exit 1; }

trap 'printf "\033[1;31m[x]\033[0m failed at line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

banner() {
    printf '\n\033[1;36m'
    cat <<'EOF'
  ╭────────────────────────────────────╮
  │    Hyprland-Dotfiles · installer   │
  ╰────────────────────────────────────╯
EOF
    printf '\033[0m\033[2m  %s\033[0m\n' "$REPO_DIR"
}

step() {
    STEP=$((STEP + 1))
    printf '\n\033[1;35m[%d/%d]\033[0m \033[1m%s\033[0m\n' "$STEP" "$TOTAL_STEPS" "$1"
}

# run "label" cmd args...  — runs quietly with a spinner, shows the log tail on failure
run() {
    local label="$1" logf pid rc=0 i=0
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    shift
    logf="$(mktemp /tmp/dotfiles-install.XXXXXX.log)"

    "$@" >"$logf" 2>&1 &
    pid=$!

    if [[ -t 1 ]]; then
        while kill -0 "$pid" 2>/dev/null; do
            printf '\r\033[1;36m%s\033[0m %s' "${frames[i % 10]}" "$label"
            i=$((i + 1))
            sleep 0.1
        done
        printf '\r\033[K'
    fi

    wait "$pid" || rc=$?
    if (( rc == 0 )); then
        log "$label"
        rm -f "$logf"
    else
        printf '\033[1;31m[x]\033[0m %s\n' "$label"
        tail -n 15 "$logf" | sed 's/^/    /'
        printf '    \033[2mfull log: %s\033[0m\n' "$logf"
    fi
    return "$rc"
}

# symlink $1 -> $2, backing up whatever is already at $2
link_item() {
    local src="$1" target="$2" backup
    if [[ -L "$target" && "$(readlink -f "$target")" == "$(readlink -f "$src")" ]]; then
        return 0
    fi
    if [[ -e "$target" || -L "$target" ]]; then
        backup="${target}.bak.${STAMP}"
        note "backing up existing $target -> $backup"
        mv "$target" "$backup"
    fi
    ln -s "$src" "$target"
    log "linked $(basename "$target")"
}

# ---------------------------------------------------------------------------
# sanity checks
# ---------------------------------------------------------------------------
banner

[[ $EUID -ne 0 ]] || die "don't run this as root — it installs into \$HOME (sudo is called where needed)"
[[ -d "$CONFIG_SRC" ]] || die "no .config found next to this script — run from the repo root"

HAVE_DNF=0
if command -v dnf >/dev/null 2>&1; then
    HAVE_DNF=1
    note "sudo is needed for packages — asking once"
    sudo -v || die "sudo authentication failed"
else
    warn "dnf not found — skipping package install, doing dotfiles/build only"
fi

# ---------------------------------------------------------------------------
# 1. COPR repositories
# ---------------------------------------------------------------------------
step "Repositories"
if (( HAVE_DNF )); then
    if ! dnf copr --help >/dev/null 2>&1; then
        run "installing the dnf copr plugin" sudo dnf install -y dnf5-plugins \
            || run "installing the dnf copr plugin (fallback)" sudo dnf install -y dnf-plugins-core \
            || warn "could not install the dnf copr plugin"
    fi

    # ghostty terminal, Hyprland
    for repo in scottames/ghostty lionheartp/Hyprland; do
        run "enabling COPR $repo" sudo dnf copr enable -y "$repo" \
            || warn "could not enable COPR $repo"
    done
else
    note "skipped (no dnf)"
fi

# ---------------------------------------------------------------------------
# 2. packages (Fedora/dnf)
# ---------------------------------------------------------------------------
step "Packages"
PKGS=(
    ghostty
    hyprland hypridle hyprlock
    waybar
    dunst
    fastfetch
    cava
    calcurse
    python3 pavucontrol
    NetworkManager NetworkManager-tui
    rustup
    gcc gcc-c++ make pkgconf-pkg-config
    gtk4-devel gtk4-layer-shell-devel
    cairo-devel pango-devel gdk-pixbuf2-devel graphene-devel glib2-devel
    grim slurp wl-clipboard
    flameshot
    curl wget unzip fontconfig
    cargo
)

if (( HAVE_DNF )); then
    # --skip-unavailable: one missing package must not abort the whole install
    run "installing ${#PKGS[@]} packages via dnf" sudo dnf install -y --skip-unavailable "${PKGS[@]}" \
        || warn "dnf reported errors while installing packages"

    # rofi: the wayland fork was merged back upstream, so the package name depends on the release
    if ! command -v rofi >/dev/null 2>&1; then
        if dnf info rofi-wayland >/dev/null 2>&1; then rofi_pkg=rofi-wayland; else rofi_pkg=rofi; fi
        run "installing $rofi_pkg" sudo dnf install -y "$rofi_pkg" \
            || warn "rofi could not be installed"
    fi

    missing=()
    for p in "${PKGS[@]}"; do
        rpm -q "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    (( ${#missing[@]} == 0 )) || warn "packages not installed: ${missing[*]}"
else
    warn "not on Fedora — install these manually: rofi ${PKGS[*]}"
fi

note "ghostty replaces kitty as the default terminal"
note "autostart apps to install manually/via flatpak if you want them:"
note "    zen browser, telegram, anytype, spotify, figma-linux, bitwarden, kdeconnect-app, FlClashX (VPN), vicinae"

# ---------------------------------------------------------------------------
# 3. rust toolchain (must come before anything that calls cargo)
# ---------------------------------------------------------------------------
step "Rust toolchain"
export PATH="$BIN_DST:$HOME/.cargo/bin:$PATH"

if command -v rustup >/dev/null 2>&1 && ! rustup show active-toolchain >/dev/null 2>&1; then
    run "setting up rust toolchain (stable)" rustup default stable
fi
command -v cargo >/dev/null 2>&1 || die "cargo not found — install rust manually"
log "cargo ready"

# ---------------------------------------------------------------------------
# 4. awww (wallpaper daemon, via lionheartp/Hyprland or cargo)
# ---------------------------------------------------------------------------
step "awww (wallpaper daemon)"
if command -v awww >/dev/null 2>&1; then
    log "awww already installed, skipping"
else
    awww_ok=0
    if (( HAVE_DNF )) && dnf info awww >/dev/null 2>&1; then
        run "installing awww via dnf" sudo dnf install -y awww && awww_ok=1
    fi
    if (( ! awww_ok )); then
        # --root ~/.local puts the binaries next to wallpicker, in $BIN_DST
        run "building awww from source (cargo, takes a while)" \
            cargo install awww --locked --root "$HOME/.local" \
            || warn "cargo install awww failed — install it manually"
    fi
fi
command -v awww-daemon >/dev/null 2>&1 || warn "awww-daemon not found in PATH — wallpapers won't start"

# ---------------------------------------------------------------------------
# 5. symlink dotfiles (.config/*)
# ---------------------------------------------------------------------------
step "Dotfiles"
mkdir -p "$CONFIG_DST"
for entry in "$CONFIG_SRC"/*; do
    link_item "$entry" "$CONFIG_DST/$(basename "$entry")"
done

# .zshrc / .vimrc at repo root, if present
for rc in .zshrc .vimrc; do
    [[ -f "$REPO_DIR/$rc" ]] && link_item "$REPO_DIR/$rc" "$HOME/$rc"
done
log "dotfiles linked"

# ---------------------------------------------------------------------------
# 6. wallpapers
# ---------------------------------------------------------------------------
step "Wallpapers"
if [[ -d "$REPO_DIR/wallpapers" ]]; then
    mkdir -p "$WALLPAPER_DST"
    cp -n "$REPO_DIR"/wallpapers/* "$WALLPAPER_DST"/ || true
    log "wallpapers copied to $WALLPAPER_DST"
else
    note "no wallpapers directory, skipping"
fi

# ---------------------------------------------------------------------------
# 7. build wallpicker-rs (sources are copied to ~, the repo stays untouched)
# ---------------------------------------------------------------------------
step "wallpicker-rs"
if [[ -d "$WALLPICKER_DIR" ]]; then
    mkdir -p "$WALLPICKER_HOME"
    cp -a "$WALLPICKER_DIR/." "$WALLPICKER_HOME/"
    log "sources synced to $WALLPICKER_HOME"

    if run "building wallpicker-rs (release)" \
        cargo build --release --manifest-path "$WALLPICKER_HOME/Cargo.toml"; then
        BIN_PATH="$WALLPICKER_HOME/target/release/wallpicker"
        if [[ -f "$BIN_PATH" ]]; then
            install -Dm755 "$BIN_PATH" "$BIN_DST/wallpicker"
            log "installed wallpicker to $BIN_DST/wallpicker"
        else
            warn "build succeeded but binary not found at $BIN_PATH — check target/release manually"
        fi
    else
        warn "wallpicker-rs build failed — see the log above"
    fi

    case ":$PATH:" in
        *":$BIN_DST:"*) ;;
        *) warn "$BIN_DST is not on your PATH — add: export PATH=\"\$PATH:$BIN_DST\"" ;;
    esac
else
    warn "wallpicker-rs directory not found, skipping"
fi

# ---------------------------------------------------------------------------
# 8. Fonts (JetBrainsMono Nerd Fonts + Apple Color Emoji)
# ---------------------------------------------------------------------------
step "Fonts"
mkdir -p "$FONT_DIR"

FONTS=("JetBrainsMono" "JetBrainsMonoNL")

for font in "${FONTS[@]}"; do
    dest="$FONT_DIR/$font"
    if compgen -G "$dest/*.ttf" >/dev/null; then
        log "$font already installed, skipping"
        continue
    fi

    tmp_zip="$(mktemp "/tmp/${font}-nerd-font.XXXXXX.zip")"
    url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font}.zip"

    if ! run "downloading $font" curl -fsSL -o "$tmp_zip" "$url"; then
        warn "failed to download $font — skipping"
        rm -f "$tmp_zip"
        continue
    fi

    mkdir -p "$dest"
    unzip -oq "$tmp_zip" -d "$dest"
    rm -f "$tmp_zip"
    log "installed $font"
done

EMOJI_DIR="$FONT_DIR/AppleColorEmoji"
EMOJI_FILE="$EMOJI_DIR/AppleColorEmoji-Linux.ttf"
EMOJI_URL="https://github.com/samuelngs/apple-emoji-ttf/releases/latest/download/AppleColorEmoji-Linux.ttf"

if [[ -f "$EMOJI_FILE" ]]; then
    log "Apple Color Emoji already installed, skipping"
else
    mkdir -p "$EMOJI_DIR"
    if run "downloading Apple Color Emoji (~110 MB)" curl -fsSL -o "$EMOJI_FILE" "$EMOJI_URL"; then
        log "installed Apple Color Emoji"
    else
        rm -f "$EMOJI_FILE"
        warn "failed to download Apple Color Emoji — skipping"
    fi
fi

if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$FONT_DIR" >/dev/null 2>&1 \
        && log "font cache rebuilt" \
        || warn "fc-cache failed, run manually: fc-cache -f"
fi
# ---------------------------------------------------------------------------
# 9. permissions on helper scripts (every .sh / .py in the repo's .config)
# ---------------------------------------------------------------------------
step "Permissions"
while IFS= read -r -d '' script; do
    chmod +x "$script"
done < <(find "$CONFIG_SRC" -type f \( -name '*.sh' -o -name '*.py' \) -not -path '*/.git/*' -print0)
log "helper scripts are executable"

# ---------------------------------------------------------------------------
# done
# ---------------------------------------------------------------------------
echo
if (( ${#WARNINGS[@]} > 0 )); then
    printf '\033[1;33m[!] %d warning(s):\033[0m\n' "${#WARNINGS[@]}"
    printf '    - %s\n' "${WARNINGS[@]}"
    echo
fi
log "done in $((SECONDS / 60))m $((SECONDS % 60))s. Log out/in or restart Hyprland to pick everything up."
