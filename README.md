# dots

Personal dotfiles for Arch Linux / CachyOS — GNOME desktop, Catppuccin Mocha themed.

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
| **Shell** | GNOME Shell (with extensions: Dash to Dock, Blur My Shell, Vitals, auto-move-windows) |
| **Launcher** | GNOME app grid (Super key) |
| **Lock screen** | GNOME built-in lock screen |
| **Terminal** | Kitty |
| **Browser** | LibreWolf |
| **Editor** | VSCodium |
| **Shell** | Zsh with oh-my-zsh (bullet-train theme) |
| **Color Theme** | Catppuccin Mocha |

## Structure

```
.config/
├── alacritty/          Alacritty terminal config
├── gnome/              GNOME settings script (apply-settings.sh)
├── VSCodium/           VSCodium editor settings
└── wallpapers/         Wallpaper images
.oh-my-zsh/             Custom oh-my-zsh theme
.zshrc                  Zsh configuration
```

## Features

### Keybinds
- **Super** — App grid (GNOME launcher)
- **Super + L** — Lock screen (GNOME)
- **Super + Q** — Close window
- **Print** / **Super + Print** — Region / window screenshot (gnome-screenshot)
- **Super + Return** — Terminal (Kitty)
- **Super + E** — File manager (Nautilus)
- **Super + T** — Editor (VSCodium)
- **Super + W** — Browser (LibreWolf)
- **Super + 1-0** — Switch workspaces
- **Super + Shift + 1-0** — Move window to workspace

### Workspace Layout
| WS | App |
|----|-----|
| 1 | LibreWolf |
| 2 | Alacritty |
| 3 | VSCodium |
| 4 | Bitwarden |

### Colors
Catppuccin Mocha throughout — terminal, editor, shell UI, and accent colors.

### Git
- SSH agent handled via Bitwarden SSH agent socket
- Git wrapper script at `.config/git-ssh-wrapper.sh`
- VSCodium configured to use the wrapper for GUI git operations

## Dependencies

- **GNOME Shell** — Desktop shell (with extensions: Dash to Dock, Blur My Shell, Vitals, auto-move-windows)
- **Kitty** — Terminal emulator
- **LibreWolf** — Web browser
- **VSCodium** — Code editor
- **Nautilus** — File manager
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
