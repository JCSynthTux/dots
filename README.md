# dots

Personal dotfiles for CachyOS (Arch-based): GNOME, Catppuccin Mocha, keyboard-driven.

## Quick Start

```bash
git clone git@github.com:JCSynthTux/dots.git ~/Projects/dots
cd ~/Projects/dots
brew bundle                       # Homebrew on Linux; installs the Brewfile below
```

Then link the tracked config into place. `ln -sfn` replaces symlinks, not real
directories — if a destination already exists as a real directory, back it up
and remove it first.

```bash
for d in alacritty gnome k9s kitty lsfg-vk MangoHud opencode VSCodium; do
  ln -sfn ~/Projects/dots/.config/"$d" ~/.config/"$d"
done

ln -sfn ~/Projects/dots/.zshrc ~/.zshrc
ln -sfn ~/Projects/dots/.config/git-ssh-wrapper.sh ~/.config/git-ssh-wrapper.sh
chmod +x ~/.config/git-ssh-wrapper.sh

ln -sfn ~/Projects/dots/.oh-my-zsh/custom/themes/bullet-train.zsh-theme \
  ~/.oh-my-zsh/custom/themes/bullet-train.zsh-theme
```

`~/.config/git-ssh-wrapper.sh` must live at exactly that path — VSCodium's
`git.path` hardcodes it.

Prerequisites the Brewfile does not cover:

- **oh-my-zsh** — `.zshrc` sets `ZSH="$HOME/.oh-my-zsh"` and sources it.
- **zsh-autosuggestions** — listed in `plugins=()` but not shipped with
  oh-my-zsh; it must be cloned into `~/.oh-my-zsh/custom/plugins/` or zsh errors
  on startup.
- **gsettings / GNOME** — required by the settings script.

Apply the GNOME settings:

```bash
./.config/gnome/apply-settings.sh --dry-run   # preview
./.config/gnome/apply-settings.sh             # apply
```

Optional, for OpenCode's MCP servers (see [OpenCode](#opencode)):

```bash
mkdir -p ~/.secrets
printf '...' > ~/.secrets/searxng-url    # no trailing newline
chmod 600 ~/.secrets/searxng-url
```

The k8s server takes its kubeconfig **path** from the `KUBECONFIG` environment
variable that `.zshrc` exports, so no extra secret file is needed for it.

Machine-specific env and secrets go in `~/.zshrc.local`, which is sourced if
present and is deliberately untracked.

## Overview

| Component | What |
|-----------|------|
| **Desktop** | GNOME on CachyOS, dark scheme, accent `blue` |
| **Terminal** | Kitty (secondary: Alacritty) |
| **Browser** | Helium |
| **Editor** | VSCodium (external terminal: Ptyxis) |
| **Shell** | zsh + oh-my-zsh with the bullet-train theme |
| **Theme** | Catppuccin Mocha (terminals, VSCodium, k9s, OpenCode TUI) |
| **Kubernetes** | k9s with a Catppuccin Mocha skin |
| **Agents** | OpenCode orchestrator + five subagents |

## Structure

```
Brewfile                        Homebrew formulas, casks, and flatpaks
AGENTS.md                       Conventions/context for AI agents
.zshrc                          Zsh configuration
.oh-my-zsh/custom/themes/       bullet-train.zsh-theme
.config/
├── alacritty/                  Alacritty terminal config
├── git-ssh-wrapper.sh          git wrapper pinning the Bitwarden SSH agent socket
├── gnome/apply-settings.sh     Portable GNOME settings/keybindings script
├── k9s/                        k9s config, aliases, Catppuccin Mocha skin
├── kitty/                      Kitty terminal config
├── lsfg-vk/                    Lossless Scaling frame-gen config
├── MangoHud/                   MangoHud overlay config
├── opencode/                   OpenCode config, agents, TUI theme, skills
└── VSCodium/                   VSCodium user settings
```

## GNOME

`.config/gnome/apply-settings.sh` applies the portable settings with
`gsettings`. It takes `--dry-run` (log only) and `--help`; unknown options exit
`2`, and a missing `gsettings` exits `1`.

Keys whose schema is absent or not writable are skipped with a log line rather
than failing — so the Dash to Dock lines in `clear_shell_conflicts` are no-ops
unless that extension is installed. The script's help text states that the
custom-keybinding list is managed by it and existing entries will be replaced;
in the current version `set_custom_binding` is defined but never called, so only
the bindings below are written.

### Settings applied

| Setting | Value |
|---------|-------|
| `color-scheme` | `prefer-dark` |
| `accent-color` | `blue` |
| `background picture-uri` | `file:///usr/share/backgrounds/gnome/fold-l.jxl` |
| UI font | `JetBrainsMono Nerd Font 11` |
| Monospace font | `JetBrainsMono Nerd Font 12` |
| Clock | `24h`, date and weekday shown, battery percentage on |
| Animations | on |
| Hot corners | off |
| Mouse / touchpad accel | `flat` |
| Natural scroll | off (mouse and touchpad) |
| Touchpad | tap-to-click on, two-finger scrolling on |
| `gtk-enable-primary-paste` | `false` |
| Workspaces | 10 fixed (`dynamic-workspaces false`), `workspaces-only-on-primary false` |
| Focus / windows | `focus-mode sloppy`, `center-new-windows true`, `edge-tiling true` |

`favorite-apps` (dock order): Nautilus, Helium, Bitwarden (native and flatpak
desktop IDs), Thunderbird, Telegram, VSCodium (native and flatpak desktop IDs),
Kitty, Ptyxis, Shelly, Bazaar, Steam, OnlyOffice, GNOME System Monitor,
MissionCenter.

### Keybindings set

| Binding | Action |
|---------|--------|
| `<Super>q` | Close window (`close`) |
| `<Super>f` | Toggle fullscreen |
| `<Super>l` | Lock screen (`media-keys screensaver`) |
| `<Super>1` … `<Super>0` | Switch to workspace 1–10 |
| `<Super><Shift>1` … `<Super><Shift>0` | Move window to workspace 1–10 |
| `<Super>Left` / `<Super>Right` | Previous / next workspace |
| `<Super><Shift>Left` / `<Super><Shift>Right` | Move window to previous / next workspace |

### Bindings deliberately cleared

`switch-to-application-1`…`9` (frees `<Super>1`–`9` for workspace switching),
`focus-active-notification`, `show-screenshot-ui`, `screenshot`,
`screenshot-window`, `toggle-tiled-left`/`-right`, and the Dash to Dock
`shortcut`/`shortcut-text`. Apart from `screensaver`, the standard volume, media
and brightness keys are left to GNOME.

## Terminals

**Kitty** — `.config/kitty/kitty.conf`. JetBrainsMono Nerd Font at size 12,
inline Catppuccin Mocha palette, `/usr/bin/zsh` as shell, 10 px padding,
titlebar-only decorations, powerline tab bar at the bottom, block cursor,
10 000 lines of scrollback.

**Alacritty** — `.config/alacritty/alacritty.toml`. JetbrainsMono Nerd Font at
size 12, the same Catppuccin Mocha palette, 10 px padding,
`TERM=xterm-256color`.

## Shell

`.zshrc` loads oh-my-zsh with `ZSH_THEME="bullet-train"`; the theme file is
tracked at `.oh-my-zsh/custom/themes/bullet-train.zsh-theme`.

- `plugins=(ansible brew git debian kubectl zsh-autosuggestions)` —
  `zsh-autosuggestions` is not bundled with oh-my-zsh and must be installed
  separately.
- `PATH` starts with `$HOME/bin:/usr/local/bin`, and `$HOME/.local/bin` is
  appended at the end.
- `no_proxy='*'`, `KUBECONFIG="$HOME/.kube/config"`, `KUBE_EDITOR=nvim`,
  `TERM=xterm-256color`.
- bun: `BUN_INSTALL="$HOME/.bun"`, completions sourced from `$HOME/.bun/_bun`,
  `$BUN_INSTALL/bin` prepended to `PATH`.
- `SSH_AUTH_SOCK` points at the **flatpak** Bitwarden agent socket
  (`~/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock`).
- No aliases are defined; `~/.zshrc.local` is sourced when present.

## Git + Bitwarden

`.config/git-ssh-wrapper.sh` is a three-line `/bin/sh` script: it exports
`SSH_AUTH_SOCK` to the flatpak Bitwarden agent socket and `exec`s `/usr/bin/git`.
VSCodium sets `"git.path": "/home/jchroback/.config/git-ssh-wrapper.sh"`, so the
wrapper must be symlinked to that exact path and be executable. Both the wrapper
and the shell assume Bitwarden is the **flatpak** build; other install methods
use a different socket path.

## OpenCode

`.config/opencode/opencode.jsonc` sets `default_agent` to `orchestrator`,
disables the built-in `websearch`, and declares no provider or model block —
models come from each agent's frontmatter.

### Agents

Six files in `.config/opencode/agents/`:

| Agent | Mode | Model | Permissions |
|-------|------|-------|-------------|
| `orchestrator` | primary | `opencode-go/glm-5.3` | Delegates only: denies `edit`, `shell`, `execute`, `webfetch`, `websearch`; may spawn `explorer`, `coder`, `reviewer`, `tester`, `researcher` |
| `coder` | subagent | `opencode-go/deepseek-v4.1-flash` | Implements and commits; shell limited to `git add/commit/status/diff/log/restore/stash`; `git push` denied; may spawn `explorer` and `tester` |
| `explorer` | subagent | `opencode-go/deepseek-v4.1-flash` | Read-only (no `edit`/`shell`/`execute`/subagents); web via searxng MCP tools only |
| `researcher` | subagent | `opencode-go/deepseek-v4.1-flash` | Read-only; sourced web reports via searxng MCP tools only |
| `reviewer` | subagent | `opencode-go/deepseek-v4.1-flash` | Read-only; only `git diff/status/log/show`; never builds or tests |
| `tester` | subagent | `opencode-go/deepseek-v4.1-flash` | Writes and runs tests; `git commit`/`git push` denied; spawns nothing |

Every agent that denies `execute` (orchestrator, explorer, researcher, reviewer)
also denies the `cloudflare_*` tool prefix, so those ~3k tool schemas never enter
its catalog.

### MCP servers

| Server | Type | Details |
|--------|------|---------|
| `k8s` | local | `npx -y @dockndevai/mcp-kubernetes@0.4.1`, `K8S_MODE=read-only`, `KUBECONFIG_PATH` from `{env:KUBECONFIG}` (exported by `.zshrc`) |
| `searxng` | local | `npx -y mcp-searxng@2.7.0`, `SEARXNG_URL` from `{file:~/.secrets/searxng-url}`, `codemode: false` |
| `cloudflare` | remote | `https://mcp.cloudflare.com/mcp`, `disabled: true` |

In the v2 `mcp.servers` map entries are toggled with `disabled`, not `enabled`;
an `enabled` key there is ignored, so a server meant to be off would still start.

`{file:...}` substitutes the file's **contents**, not its path, so the secret
file must be `chmod 600` **and have no trailing newline**, or the URL is passed
with a stray `\n` and the server fails. It lives outside the repo on purpose.
For the k8s server, which needs a *path*, the config uses `{env:KUBECONFIG}`
instead — `{file:~/.kube/config}` would hand it kubeconfig YAML to open as a
filename.

Both local servers also set `NODE_EXTRA_CA_CERTS` to the system trust bundle.
Fedora-family hosts like this one use
`/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem`; other distributions need
their own bundle path in both entries. The Homebrew node build's bundled roots
reject the npm registry chain (`UNABLE_TO_GET_ISSUER_CERT_LOCALLY`), which made
`npx` hang until MCP init timed out.

### TUI + skills

`.config/opencode/cli.json` selects the `catppuccin-mocha-flamingo` theme
defined in `themes/catppuccin-mocha-flamingo.json`. V2 reads one global
`cli.json`, and its `theme` is an object (`name` plus an optional `mode`, fixed
to `dark` here). `skills/` holds 44 skill directories (`SKILL.md` plus
references/assets), auto-discovered by OpenCode.

## k9s

`.config/k9s/config.yaml`: Catppuccin Mocha transparent skin, read-write
(`readOnly: false`), mouse disabled, `refreshRate: 2`, `apiServerTimeout: 2m0s`,
screen dumps to `/home/jchroback/.local/state/k9s/screen-dumps`, CPU/memory warn
at 70 % and critical at 90 %.

`.config/k9s/aliases.yaml` shortcuts:

| Alias | Resource |
|-------|----------|
| `dp` | deployments |
| `sec` | v1/secrets |
| `jo` | jobs |
| `cr` | clusterroles |
| `crb` | clusterrolebindings |
| `ro` | roles |
| `rb` | rolebindings |
| `np` | networkpolicies |
| `ss` | sealedsecrets |

## Gaming

**MangoHud** — `.config/MangoHud/MangoHud.conf`: verbose overlay at
`font_size=28` with GPU (temp, junction temp, core/mem clocks, power, fan,
voltage), CPU (temp, power, MHz), `vram`, `ram`, `swap`, `fps`, `frametime`,
`fps_metrics=avg,0.01,0.1,1`, FSR, HDR, refresh rate and present mode. Load
colours switch at 60 %/90 %; FPS colour thresholds are 30/60.

**lsfg-vk** — `.config/lsfg-vk/conf.toml`: Lossless Scaling frame generation with
the global DLL at
`/home/jchroback/.steam/steam/steamapps/common/Lossless Scaling/Lossless.dll`.
Per-game entries for `GTAIV.exe` and `Phasmophobia.ex`: multiplier 2,
`flow_scale 1.0`, performance mode off, HDR off, `experimental_present_mode`
`fifo`.

## Dependencies

From the `Brewfile` (`brew bundle`):

| Kind | Packages |
|------|----------|
| Formula | `kubectl`, `kubeseal`, `k9s`, `talosctl`, `opencode`, `uv` |
| Cask | `helium-browser`, `font-jetbrains-mono-nerd-font` |
| Flatpak | `com.bitwarden.desktop`, `io.mpv.Mpv`, `com.vscodium.codium` |

Also required, not managed by the Brewfile: Homebrew on Linux, GNOME with
`gsettings`, zsh, oh-my-zsh, `zsh-autosuggestions`, and the applications named in
`favorite-apps` (Nautilus, Helium, Bitwarden, Thunderbird, Telegram, VSCodium,
Kitty, Ptyxis, Shelly, Bazaar, Steam, OnlyOffice, GNOME System Monitor,
MissionCenter). VSCodium settings reference the Catppuccin Mocha colour and icon
themes, which come from extensions rather than this repo.

## Portability

Several files hardcode `/home/jchroback`: VSCodium's `git.path`, k9s's
`screenDumpDir`, and the lsfg-vk `dll` path. `.zshrc` derives the Bitwarden
socket from `$USER` and the git wrapper uses `$HOME`, but the rest needs a `sed`
pass before the repo works under another username. `favorite-apps` also assumes
the corresponding desktop files are installed.
