<div align="center">

![GitHub Repo stars](https://img.shields.io/github/stars/kirtan-rasa/Hyprland-Dotfiles?style=for-the-badge&color=cba6f7)
![GitHub last commit](https://img.shields.io/github/last-commit/kirtan-rasa/Hyprland-Dotfiles?style=for-the-badge&color=b4befe)
![GitHub repo size](https://img.shields.io/github/repo-size/kirtan-rasa/Hyprland-Dotfiles?style=for-the-badge&color=cba6f7)

</div>

<h3 align="center">
  <img src="https://github.com/JaKooLit/Telegram-Animated-Emojis/blob/main/Activity/Sparkles.webp" alt="Sparkles" width="38" height="38" />
  Simple Hyprland Dotfiles
  <img src="https://github.com/JaKooLit/Telegram-Animated-Emojis/blob/main/Activity/Sparkles.webp" alt="Sparkles" width="38" height="38" />
</h3>

---

This is my personal Hyprland configuration — **light, simple, and constantly improving**.


---

### 📦Components

| Component | Purpose |
|-----------|---------|
| **Waybar** | Status bar, incl. a custom WiFi module |
| **Rofi** | App launcher, power menu, and a nmcli-based WiFi connection menu |
| **Ghostty** | Terminal emulator |
| **Cava** | Audio visualizer |
| **Hyprlock** | Lock screen |
| **Hypridle** | Idle management |
| **Dunst** | Notification daemon |
| **Fastfetch** | System info fetch |
| **wallpicker-rs** | Custom wallpaper picker (GTK4 + layer-shell, written in Rust) |

### 👀Recent additions

**Waybar:**
- Replace the built-in clock with a custom module: hover shows a
  compact month calendar, click opens calcurse in a floating window

**Installer:**
- Set up Rust before anything that calls cargo
- Build wallpicker-rs from a copy in `~/` instead of moving it out of
  the repo, so reruns work
- Skip unavailable packages and make COPR failures non-fatal
- Install awww into `~/.local,` Apple Color Emoji, and calcurse
- Skip fonts that are already installed
- Add banner, step counter, spinner and a warning summary

---

### ❗Requirements
- Fedora Linux (or fedora-based)
- Wayland session
- `git`, `base-devel`

---

### 🏁Installation

```bash
git clone https://github.com/kirtan-rasa/Hyprland-Dotfiles.git
cd Hyprland-Dotfiles
chmod +x install.sh
./install.sh
```
