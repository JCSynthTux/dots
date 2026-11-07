# dots

Personal dotfiles for Arch Linux / CachyOS — Hyprland + Noctalia desktop, Catppuccin Mocha themed.

## Quick Start

```bash
git clone git@github.com:JCSynthTux/dots.git ~/Projects/dots
```

Then symlink the config dirs you use into `~/.config`, e.g.
`ln -sfn ~/Projects/dots/.config/kitty ~/.config/kitty`. If a destination already
exists as a real directory, back it up and remove it first — `ln -sfn` replaces
symlinks, not directories. The local-GPU extras document their own symlinks in
`.config/llama-swap/README.md`.

## Overview

| Component | What |
|-----------|------|
| **WM/Compositor** | Hyprland (Lua config via CachyOS DSL) |
| **Shell** | Noctalia (control center, notifications, OSD, wallpaper) |
| **Bar** | Waybar |
| **Launcher** | Hyprlauncher |
| **Lock screen** | Hyprlock |
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
│   ├── hyprlauncher.conf  Hyprlauncher config (Hyprlang)
│   ├── hyprlock.conf      Hyprlock lock screen config
│   ├── hyprtoolkit.conf   Hyprtoolkit theme (Catppuccin Mocha)
│   └── config/         Split modules (keybinds, monitors, windowrules, etc.)
├── noctalia/           Desktop shell (control center, notifications, lock screen)
├── waybar/             Top bar (replaces Noctalia bar)
├── VSCodium/           VSCodium editor settings
└── wallpapers/         Wallpaper images
.oh-my-zsh/             Custom oh-my-zsh theme
.zshrc                  Zsh configuration
```

## Features

### Keybinds
- **Super + Space** — App launcher (hyprlauncher)
- **Super + .** — Launcher (type `.` for emoji/unicode)
- **Super + L** — Lock screen (hyprlock)
- **Super + Shift + L** — Lock + suspend
- **Super + Ctrl + L** — Lock + hibernate
- **Sleep key** — Lock + suspend
- **Super + Q** — Close window
- **Print** / **Super + Print** — Region / window screenshot (grim + slurp)
- **Super + V** — Clipboard picker (cliphist + hyprlauncher)
- **Super + Enter** — Terminal (Alacritty)
- **Super + W** — Browser (Chromium)
- **Super + E** — File manager (Dolphin)
- **Super + T** — Editor (VSCodium)
- **Super + H** — Hide window (scratchpad)
- **Super + 1-0** — Switch workspaces
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
- **noctalia** — Desktop shell (control center, notifications)
- **waybar** — Top bar
- **hyprlauncher** — App launcher
- **hyprlock** — Lock screen
- **playerctl** — Media player control (waybar mpris module)
- **Kitty** — Terminal emulator
- **Chromium** — Web browser
- **VSCodium** — Code editor
- **dolphin** — File manager
- **oh-my-zsh** — Zsh framework
- **JetbrainsMono Nerd Font** — Monospace font
- **Bitwarden** — Password manager with SSH agent

## Local GPU serving (llama.cpp)

OpenCode can also run fully local: `llama-server` (llama.cpp) behind
**llama-swap**, which keeps one model resident and hot-swaps per request on an
RX 9060 XT (16 GB, RDNA4). The fleet is role-specialized across three models —
Qwen3.8-27B for orchestration, GLM-4.7-Flash for coding/exploring/testing, and
Devstral Small 2 24B for review — so swaps land only on phase boundaries.

The local variant ships as inert copies — `opencode.local-gpu.jsonc` and
`agents-local-gpu/` — copied in place over the tracked cloud files to activate,
and restored with `git checkout --` to go back. Build, model downloads, the VRAM
budget, the smoke test, and the exact recipe live in
`.config/llama-swap/README.md`; the unit is
`.config/systemd/user/llama-swap.service`.

Kept as copies until the RX 9060 XT is in hand.
