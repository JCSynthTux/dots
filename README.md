# dots

Personal dotfiles for Arch Linux / CachyOS — Hyprland + Noctalia desktop, Catppuccin Mocha themed.

## Quick Start

```bash
git clone git@github.com:JCSynthTux/dots.git ~/dots
cd ~/dots
./install.sh --all
```

Flags: `--link` (symlink configs), `--packages` (install deps), `--fonts` (JetBrainsMono Nerd Font), `--all` (everything).

## Overview

| Component | What |
|-----------|------|
| **WM/Compositor** | Hyprland (Lua config via CachyOS DSL) |
| **Shell** | Noctalia (bar, dock, launcher, notifications, wallpaper, OSD, lock screen) |
| **Terminal** | Kitty |
| **Browser** | Chromium |
| **Editor** | VSCodium |
| **Shell** | Zsh with oh-my-zsh (bullet-train theme) |
| **Color Theme** | Catppuccin Mocha |

## Structure

```
.config/
├── alacritty/          Alacritty terminal config
├── hypr/               Hyprland compositor config
│   ├── hyprland.lua    Entry point
│   └── config/         Split modules (keybinds, monitors, windowrules, etc.)
├── noctalia/           Desktop shell (bar, dock, launcher, notifications)
├── VSCodium/           VSCodium editor settings
└── wallpapers/         Wallpaper images
.oh-my-zsh/             Custom oh-my-zsh theme
.zshrc                  Zsh configuration
```

## Features

### Keybinds
- **Super + Space** — App launcher (noctalia)
- **Super + Q** — Close window
- **Super + Enter** — Terminal (Alacritty)
- **Super + W** — Browser (Chromium)
- **Super + E** — File manager (Dolphin)
- **Super + T** — Editor (VSCodium)
- **Super + H** — Hide window (scratchpad)
- **Super + 1-0** — Switch workspaces
- **Super + Shift + W** — Wallpaper toggle
- **Super + Shift + S** / **Super + S** — Scratchpad

### Workspace Layout
| WS | App |
|----|-----|
| 1 | Chromium |
| 2 | Alacritty |
| 3 | VSCodium |
| 4 | Bitwarden |

### Colors
Catppuccin Mocha throughout — terminal, editor, shell UI, window borders, and accent colors.

### Monitor Setup
- Laptop eDP-1 is the default display
- External monitor via USB-C dock auto-detects and becomes primary with laptop extended to the right
- Resets cleanly when unplugged

### Git
- SSH agent handled via Bitwarden SSH agent socket
- Git wrapper script at `.config/git-ssh-wrapper.sh`
- VSCodium configured to use the wrapper for GUI git operations

## Dependencies

- **Hyprland** — Wayland compositor
- **noctalia** — Desktop shell
- **Kitty** — Terminal emulator
- **Chromium** — Web browser
- **VSCodium** — Code editor
- **dolphin** — File manager
- **oh-my-zsh** — Zsh framework
- **JetbrainsMono Nerd Font** — Monospace font
- **Bitwarden** — Password manager with SSH agent
