#!/usr/bin/env bash
set -euo pipefail

DOTS_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --link       Symlink dotfiles into home directory
  --packages   Install required packages (Shelly)
  --fonts      Install JetBrainsMono Nerd Font
  --all        Run everything above
  --help       Show this help

EOF
    exit 0
}

link_dotfiles() {
    info "Linking dotfiles..."

    mkdir -p "$CONFIG_DIR"

    for dir in "$DOTS_DIR"/.config/*/; do
        name="$(basename "$dir")"
        src="$dir"
        dst="$CONFIG_DIR/$name"

        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            warn "Backing up existing $dst -> ${dst}.bak"
            mv "$dst" "${dst}.bak"
        fi

        ln -sfn "$src" "$dst"
        ok "Linked .config/$name"
    done

    for file in .zshrc; do
        src="$DOTS_DIR/$file"
        dst="$HOME/$file"

        if [ -f "$dst" ] && [ ! -L "$dst" ]; then
            warn "Backing up existing $dst -> ${dst}.bak"
            mv "$dst" "${dst}.bak"
        fi

        ln -sf "$src" "$dst"
        ok "Linked $file"
    done

    info "Setting up qt6ct icon theme..."
    QT6CT_CONF="$HOME/.config/qt6ct/qt6ct.conf"
    mkdir -p "$(dirname "$QT6CT_CONF")"
    if [ -f "$QT6CT_CONF" ]; then
        if grep -q '^icon_theme=' "$QT6CT_CONF"; then
            sed -i 's/^icon_theme=.*/icon_theme=hicolor/' "$QT6CT_CONF"
        else
            echo 'icon_theme=hicolor' >> "$QT6CT_CONF"
        fi
    else
        cat > "$QT6CT_CONF" <<'QTCONF'
[Appearance]
icon_theme=hicolor
style=Fusion
standard_dialogs=gtk3
QTCONF
    fi
    ok "qt6ct icon theme set to hicolor"
}

install_packages() {
    if ! command -v shelly &>/dev/null; then
        err "shelly not found — skipping package installation"
        return
    fi

    info "Installing repository packages..."

    local packages=(
        bitwarden
        brightnessctl
        gdm
        gnome-bluetooth-3.0
        gnome-shell
        gnome-shell-extension-dash-to-dock
        gnome-shell-extension-vitals
        gnome-shell-extensions
        gnome-system-monitor
        gnome-themes-extra
        gvfs
        gvfs-nfs
        gvfs-smb
        kitty
        librewolf
        noto-fonts
        onlyoffice-bin
        orchis-theme
        otf-font-awesome
        papirus-icon-theme
        pavucontrol
        # pipewire
        qt6ct
        ttf-font-awesome
        ttf-jetbrains-mono-nerd
        vimix-cursors
        vscodium
        wireplumber
        zsh
    )

    shelly install standard --no-confirm "${packages[@]}"
    ok "Repository package installation complete"
}

install_aur_packages() {
    if ! command -v shelly &>/dev/null; then
        err "shelly not found — skipping AUR package installation"
        return
    fi

    info "Installing AUR packages..."

    local aur_packages=(
        gnome-shell-extension-blur-my-shell
        gnome-rounded-blur
    )

    shelly install aur --no-confirm "${aur_packages[@]}"
    ok "AUR package installation complete"
}

install_fonts() {
    info "Checking JetBrainsMono Nerd Font..."
    if fc-list | grep -qi "JetBrainsMono Nerd Font" &>/dev/null; then
        ok "JetBrainsMono Nerd Font already installed"
        return
    fi

    if command -v shelly &>/dev/null; then
        info "Installing ttf-jetbrains-mono-nerd..."
        shelly install standard --no-confirm ttf-jetbrains-mono-nerd
    fi

    if fc-list | grep -qi "JetBrainsMono Nerd Font" &>/dev/null; then
        ok "JetBrainsMono Nerd Font installed"
    else
        warn "JetBrainsMono Nerd Font not found — install manually"
    fi
}

post_install_msg() {
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Installation complete${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════${NC}"
    echo ""
    echo "  Restart your session or reboot for all changes to take effect."
    echo ""
    echo "  Quick checks:"
    echo "    fc-list | grep -i JetBrainsMono    # Font installed"
    echo "    cat ~/.config/qt6ct/qt6ct.conf     # Icon theme = hicolor"
    echo "    ls -la ~/.config/hypr/             # Hyprland config linked"
    echo ""
    echo -e "${YELLOW}  Remaining steps (manual):${NC}"
    echo "    1. Install noctalia from https://github.com/noctalia-dev/noctalia"
    echo "    2. Set wallpaper via: Super+Shift+W"
    echo "    3. Log out and select Hyprland in your display manager"
    echo ""
}

main() {
    if [ $# -eq 0 ]; then
        usage
    fi

    local do_link=false
    local do_packages=false
    local do_fonts=false

    for arg in "$@"; do
        case "$arg" in
            --link)      do_link=true ;;
            --packages)  do_packages=true ;;
            --fonts)     do_fonts=true ;;
            --all)       do_link=true; do_packages=true; do_fonts=true ;;
            --help)      usage ;;
            *)           err "Unknown option: $arg"; usage ;;
        esac
    done

    $do_link     && link_dotfiles
    $do_packages && install_packages && install_aur_packages
    $do_fonts    && install_fonts
    $do_link     && post_install_msg
}

main "$@"
