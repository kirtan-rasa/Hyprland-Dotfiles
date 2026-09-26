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

### 📦 Components

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

### ✨ Recent additions

- **WiFi menu for waybar** — a `custom/wifi` module (`WaybarWifi.sh`) shows signal strength and connection status in the bar; left-click opens a rofi menu (`WifiMenu.sh`) to scan, connect, forget networks, or drop into `nmtui` for advanced settings. Right-click toggles WiFi on/off. Needs `NetworkManager` (`nmcli`).
- **Ghostty** replaced Kitty as the default terminal.
- **Per-workspace app assignments** — autostart apps (browser, Telegram, Spotify, Figma, Bitwarden, KDE Connect, FlClashX, etc.) now land on dedicated workspaces via Hyprland window rules.

---

### Installation

```bash
git clone https://github.com/kirtan-rasa/Hyprland-Dotfiles.git
cd Hyprland-Dotfiles
chmod +x install.sh
./install.sh
```
