#!/usr/bin/env bash
set -Eeuo pipefail

# Apply the portable GNOME settings from this dotfiles repository.
# Compositor-specific rules are intentionally not included; GNOME needs
# extensions for those.

readonly SCRIPT_NAME="${0##*/}"
readonly CUSTOM_SCHEMA="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
readonly CUSTOM_ROOT="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [--dry-run] [--help]

Apply the portable GNOME settings from this dotfiles repository.

Options:
  --dry-run  Print changes without applying them
  --help     Show this help

The custom keybinding list is managed by this script. Existing custom
keybindings in that GNOME list will be replaced.
EOF
}

log() {
    printf '[gnome] %s\n' "$*"
}

set_setting() {
    local schema="$1"
    local key="$2"
    local value="$3"

    if ! gsettings writable "$schema" "$key" &>/dev/null; then
        log "skip unavailable setting: $schema $key"
        return 0
    fi

    log "set $schema $key = $value"
    if [[ "$DRY_RUN" == false ]]; then
        gsettings set "$schema" "$key" "$value"
    fi
}

set_custom_binding() {
    local id="$1"
    local name="$2"
    local command="$3"
    local binding="$4"
    local path="$CUSTOM_ROOT/$id/"

    set_setting "$CUSTOM_SCHEMA:$path" name "'$name'"
    set_setting "$CUSTOM_SCHEMA:$path" command "'$command'"
    set_setting "$CUSTOM_SCHEMA:$path" binding "'$binding'"
}

clear_shell_conflicts() {
    # GNOME Shell claims Super+number for launching Dash applications. Clear
    # those bindings so Mutter can use the keys for workspace switching.
    local application
    for application in {1..9}; do
        set_setting org.gnome.shell.keybindings "switch-to-application-$application" "[]"
    done

    # These overlap with the custom bindings below.
    set_setting org.gnome.shell.keybindings focus-active-notification "[]"
    set_setting org.gnome.shell.keybindings show-screenshot-ui "[]"
    set_setting org.gnome.shell.keybindings screenshot "[]"
    set_setting org.gnome.shell.keybindings screenshot-window "[]"
    set_setting org.gnome.mutter.keybindings toggle-tiled-left "[]"
    set_setting org.gnome.mutter.keybindings toggle-tiled-right "[]"
    set_setting org.gnome.shell.extensions.dash-to-dock shortcut "[]"
    set_setting org.gnome.shell.extensions.dash-to-dock shortcut-text "''"
}


configure_dock() {
    # This is the current Dash to Dock order. Desktop file IDs are portable
    # across machines as long as the corresponding applications are installed.
    set_setting org.gnome.shell favorite-apps \
        "['org.gnome.Nautilus.desktop', 'helium.desktop', 'bitwarden.desktop', 'com.bitwarden.desktop.desktop', 'org.mozilla.Thunderbird.desktop', 'org.telegram.desktop.desktop', 'vscodium-wayland.desktop', 'com.vscodium.codium.desktop', 'kitty.desktop', 'org.gnome.Ptyxis.desktop', 'com.shellyorg.shelly.desktop', 'io.github.kolunmi.Bazaar.desktop', 'steam.desktop', 'onlyoffice-desktopeditors.desktop', 'org.gnome.SystemMonitor.desktop', 'io.missioncenter.MissionCenter.desktop']"
}

apply_settings() {
    # Catppuccin Mocha and the JetBrains Mono font choices.
    set_setting org.gnome.desktop.interface color-scheme "'prefer-dark'"
    set_setting org.gnome.desktop.interface accent-color "'orange'"
    set_setting org.gnome.desktop.interface font-name "'JetBrainsMono Nerd Font 11'"
    set_setting org.gnome.desktop.interface monospace-font-name "'JetBrainsMono Nerd Font 12'"
    set_setting org.gnome.desktop.interface enable-animations false
    set_setting org.gnome.desktop.interface show-battery-percentage true
    set_setting org.gnome.desktop.interface clock-format "'24h'"
    set_setting org.gnome.desktop.interface clock-show-date true
    set_setting org.gnome.desktop.interface clock-show-weekday true
    set_setting org.gnome.desktop.interface enable-hot-corners false

    # Flat mouse and touchpad acceleration profile.
    set_setting org.gnome.desktop.peripherals.mouse accel-profile "'flat'"
    set_setting org.gnome.desktop.peripherals.touchpad accel-profile "'flat'"
    set_setting org.gnome.desktop.peripherals.mouse natural-scroll false
    set_setting org.gnome.desktop.peripherals.touchpad natural-scroll false
    set_setting org.gnome.desktop.peripherals.touchpad tap-to-click true
    set_setting org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
    set_setting org.gnome.desktop.interface gtk-enable-primary-paste false

    # Use ten fixed workspaces for the Super+number workflow.
    set_setting org.gnome.mutter dynamic-workspaces false
    set_setting org.gnome.mutter workspaces-only-on-primary false
    set_setting org.gnome.mutter center-new-windows true
    set_setting org.gnome.mutter edge-tiling true
    set_setting org.gnome.desktop.wm.preferences num-workspaces 10
    set_setting org.gnome.desktop.wm.preferences focus-mode "'sloppy'"

    local workspace
    for workspace in {1..10}; do
        local key="$workspace"
        [[ "$workspace" == 10 ]] && key=0
        set_setting org.gnome.desktop.wm.keybindings "switch-to-workspace-$workspace" "['<Super>$key']"
        set_setting org.gnome.desktop.wm.keybindings "move-to-workspace-$workspace" "['<Super><Shift>$key']"
    done

    set_setting org.gnome.desktop.wm.keybindings close "['<Super>q']"
    set_setting org.gnome.desktop.wm.keybindings toggle-fullscreen "['<Super>f']"
    set_setting org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Super>Left']"
    set_setting org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Super>Right']"
    set_setting org.gnome.desktop.wm.keybindings move-to-workspace-left "['<Super><Shift>Left']"
    set_setting org.gnome.desktop.wm.keybindings move-to-workspace-right "['<Super><Shift>Right']"
    # GNOME already owns the standard volume, media, brightness, and lock keys.
    set_setting org.gnome.settings-daemon.plugins.media-keys screensaver "['<Super>l']"
    clear_shell_conflicts
    configure_dock
}

main() {
    while (($# > 0)); do
        case "$1" in
            --dry-run) DRY_RUN=true ;;
            --help|-h) usage; return 0 ;;
            *) printf 'error: unknown option: %s\n' "$1" >&2; usage >&2; return 2 ;;
        esac
        shift
    done

    command -v gsettings &>/dev/null || {
        printf 'error: gsettings is required\n' >&2
        return 1
    }

    apply_settings
    log "settings applied"
}

main "$@"
