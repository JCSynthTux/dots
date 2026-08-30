# AGENTS.md — Dotfiles Repository Guide

## Project Overview

This is a **CachyOS (Arch-based) dotfiles repository** for a desktop environment focused on **productivity (coding, DevOps) and gaming**. The stack is built on **Hyprland** (Wayland compositor) with **Waybar** as the top bar, **Hyprlauncher** as the app launcher, **Hyprlock** as the lock screen, and **Noctalia** as the desktop shell (control center, notifications, OSD), unified under the **Catppuccin Mocha** color theme.

## Repository Structure

```
dots/
├── .config/
│   ├── alacritty/           # Legacy terminal config (superseded by Kitty)
│   ├── git-ssh-wrapper.sh   # Git SSH wrapper for Bitwarden SSH agent
│   ├── hypr/                # Hyprland compositor config (modular Lua)
│   │   ├── hyprland.lua    # Entry point — requires 11 sub-modules
│   │   ├── hyprlauncher.conf  # Hyprlauncher config (Hyprlang)
│   │   ├── hyprlock.conf      # Hyprlock lock screen config
│   │   ├── hyprtoolkit.conf   # Hyprtoolkit theme — Catppuccin Mocha (shared by hyprlauncher)
│   │   ├── config/         # Split config modules (see table below)
│   │   ├── scripts/        # Python monitor hot-plug script
│   │   └── xdph.conf       # XDG Desktop Portal for Hyprland
│   ├── kitty/              # Kitty terminal config (primary terminal)
│   ├── noctalia/           # Noctalia desktop shell config (control center, notifications, OSD)
│   ├── waybar/             # Top bar (config.jsonc + style.css, Catppuccin Mocha)
│   ├── VSCodium/           # VSCodium editor settings
│   └── wallpapers/         # 4 wallpaper images
├── .oh-my-zsh/             # Custom oh-my-zsh theme (bullet-train)
├── .opencode/              # OpenCode AI assistant config (not dotfiles)
├── .zshrc                   # Zsh shell configuration
├── install.sh              # Deployment/bootstrap script
├── AGENTS.md               # This file
└── README.md               # User-facing documentation
```

## Hyprland Config Modules (`.config/hypr/config/`)

| Module | Purpose |
|--------|---------|
| `animations.lua` | Bezier curves and spring animations (**all disabled**) |
| `autostart.lua` | Startup: dbus env sync, Noctalia shell, xhost |
| `colors.lua` | Catppuccin Mocha RGBA color palette |
| `decorations.lua` | Gaps, borders, rounding (**blur and shadows disabled**) |
| `defaults.lua` | Default apps: Kitty, Dolphin, Zen Browser, VSCodium, GNOME Calc |
| `environment.lua` | Env vars placeholder (empty — uses UWSM) |
| `input.lua` | Flat acceleration, touchpad gestures |
| `keybinds.lua` | All keyboard shortcuts |
| `misc.lua` | Dwindle layout, splash, terminal swallowing, VRR=3 |
| `monitors.lua` | Display config, external monitor auto-detection |
| `windowrules.lua` | Workspace assignments, game rules, float/opacity rules |

## Key Architectural Decisions

### Dotfiles Management
- **Custom symlink deployment via `install.sh`**, not GNU Stow/Chezmoi/Yadm.
- The script symlinks `.config/*` → `~/.config/*` and `.zshrc` → `~/.zshrc`.
- Existing non-symlink files are backed up to `*.bak` before overwriting.
- When modifying config files: edit them in the repo directly since `~/.config/*` is symlinked.

### Hyprland Lua DSL (CachyOS-Specific)
This is **not** standard Hyprland config. CachyOS provides a Lua DSL wrapper (`hl.bind()`, `hl.config()`, `hl.window_rule()`, `hl.monitor()`, etc.) that generates the underlying Hyprland config. Always use the DSL helpers, never write raw Hyprland config directives.

### Performance Optimization
- **All animations disabled** across both Hyprland and Noctalia.
- **Blur and shadows disabled** — both explicitly set to `false`.
- **VRR mode 3** — variable refresh rate enabled for fullscreen apps only.
- These are deliberate choices. Do not re-enable without explicit user request.

### Bitwarden SSH Agent
SSH auth uses Bitwarden's SSH agent socket (`~/.bitwarden-ssh-agent.sock`) instead of traditional `ssh-agent`. The wrapper at `.config/git-ssh-wrapper.sh` exports `SSH_AUTH_SOCK` and execs git for GUI tools. VSCodium is configured to use this wrapper.

### Monitor Hot-Plug
Managed by `scripts/hypr-socket.py` — a Python script that communicates directly with Hyprland's UNIX socket. On external monitor connect: external becomes primary at 0x0, laptop extends right, workspaces 1-4 migrate. On disconnect: laptop restored as primary at 0x0.

### Browser
Default browser is **Zen Browser** (at `/opt/zen-browser-bin/zen-bin`), despite the README saying Chromium.

### Terminal
Kitty is the primary terminal. The Alacritty config is retained as legacy/reference only.

## Common Tasks

### Deploying dotfiles
```bash
./install.sh --all          # Symlinks + packages + fonts
./install.sh --link         # Symlinks only
./install.sh --packages     # Pacman dependencies only
./install.sh --fonts        # Font installation only
```

### Adding a new application config
1. Create a new directory under `.config/<appname>/`
2. Add the app's config files inside
3. Re-run `./install.sh --link` to symlink it
4. Update the structure section in README.md

### Adding a new Hyprland config module
1. Create `.config/hypr/config/<module>.lua` using the CachyOS Lua DSL
2. Add `require("config.<module>")` to `hyprland.lua`
3. Test by reloading Hyprland (no need to re-run install.sh since config is symlinked)

### Modifying Noctalia settings
- Edit `.config/noctalia/settings.json` directly
- Changes take effect on Noctalia restart or via its IPC

### Adding a new wallpaper
1. Add image files to `.config/wallpapers/`
2. Noctalia randomly cycles wallpapers every 30 minutes — no config change needed

### Modifying keybinds
- Edit `.config/hypr/config/keybinds.lua`
- Use `hl.bind()` for the DSL
- Hardware keys (XF86Audio*, brightness) route through Noctalia IPC, not Hyprland directly

### Modifying VSCodium settings
- Edit `.config/VSCodium/User/settings.json`
- Settings apply when VSCodium restarts

## Conventions

### When Editing Config Files
- **Use tabs for JSON** (Noctalia settings.json)
- **Use spaces for Lua** (Hyprland config modules)
- **No trailing whitespace**
- **Follow existing Catppuccin Mocha color references** — use colors from `colors.lua` for any new UI elements

### Color Palette (Catppuccin Mocha)
Reference: `.config/hypr/config/colors.lua` and `.config/noctalia/colors.json`
- Background: `#1e1e2e` (base)
- Surface: `#313244` (surface0)
- Foreground: `#cdd6f4` (text)
- Primary/Accent: `#cba6f7` (mauve)
- Secondary: `#89b4fa` (blue)
- Red: `#f38ba8`, Green: `#a6e3a1`, Yellow: `#f9e2af`

### Font
**JetBrainsMono Nerd Font** is used throughout (terminal, editor, desktop shell). Do not change without explicit user request.

### Git Commits
- Conventional commit format: `type(scope): description`
- Recent examples: `fix(kitty): update font`, `feat(hypr): disable animations`, `chore: add install script`

### Package Management
- System packages via **pacman** (see `install.sh` for full list)
- Noctalia is manually installed from GitHub
- Zen Browser is manually installed to `/opt/zen-browser-bin/`
- Bitwarden is manually installed

### Shell
- **Zsh** with **oh-my-zsh** framework
- Theme: **bullet-train** (custom, at `.oh-my-zsh/custom/themes/bullet-train.zsh-theme`)
- Plugins: ansible, brew, git, debian, kubectl, zsh-autosuggestions

## What NOT To Do

- **Do not re-enable animations, blur, or shadows** without explicit user request — these are disabled for performance
- **Do not switch away from Kitty** without user approval — Alacritty config is legacy
- **Do not use standard Hyprland config syntax** — use the CachyOS Lua DSL exclusively
- **Do not add a dotfile management tool** (stow, chezmoi, etc.) — the custom install.sh is the chosen approach
- **Do not remove the `git-ssh-wrapper.sh`** — VSCodium depends on it for Bitwarden SSH agent access
- **Do not change the color theme** from Catppuccin Mocha without user approval
- **Do not change the font** from JetBrainsMono Nerd Font without user approval
- **The `.opencode/` directory is not part of the dotfiles** — it's local AI assistant configuration
- **Do not commit secrets** — SSH keys, API tokens, etc. should never be committed

## Manual Dependencies (Not Automated by install.sh)

These must be installed separately:
- **Noctalia** — from https://github.com/noctalia-dev/noctalia
- **Zen Browser** — to `/opt/zen-browser-bin/zen-bin`
- **Bitwarden** (desktop app + CLI) — for SSH agent
- **oh-my-zsh** — the `oh-my-zsh-git` AUR package provides the framework, but the custom theme at `.oh-my-zsh/` needs manual setup

## Verification

After making changes:
```bash
# Verify Hyprland config syntax (if hyprctl available)
hyprctl config validate

# Verify install.sh is valid bash
bash -n install.sh

# Verify Noctalia settings.json is valid JSON
python3 -c "import json; json.load(open('.config/noctalia/settings.json'))"

# Check symlinks are intact
ls -la ~/.config/hypr ~/.config/kitty ~/.config/noctalia ~/.config/VSCodium ~/.zshrc
```
