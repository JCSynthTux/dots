#!/usr/bin/env bash
set -Eeuo pipefail

# Apply the GNOME settings that have direct or close equivalents in the
# Hyprland configuration. Compositor-specific rules are intentionally not
# included; GNOME needs extensions for those.

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

configure_custom_bindings() {
    local bindings=(
        "$CUSTOM_ROOT/kitty/"
        "$CUSTOM_ROOT/ranger/"
        "$CUSTOM_ROOT/codium/"
        "$CUSTOM_ROOT/librewolf/"
        "$CUSTOM_ROOT/btop/"
        "$CUSTOM_ROOT/localsend/"
        "$CUSTOM_ROOT/screenshot-area/"
        "$CUSTOM_ROOT/screenshot-window/"
        "$CUSTOM_ROOT/mic-mute/"
    )

    set_setting \
        org.gnome.settings-daemon.plugins.media-keys \
        custom-keybindings \
        "[$(printf "'%s'," "${bindings[@]}" | sed 's/,$//')]"

    set_custom_binding kitty "Launch Kitty" "kitty" "<Super>Return"
    set_custom_binding ranger "File manager" "kitty -T ranger -e ranger" "<Super>e"
    set_custom_binding codium "VSCodium" "codium" "<Super>t"
    set_custom_binding librewolf "LibreWolf" "librewolf" "<Super>w"
    set_custom_binding btop "System monitor" "kitty -e btop" "<Control><Shift>Escape"
    set_custom_binding localsend "LocalSend" "localsend" "<Super>n"
    set_custom_binding screenshot-area "Screenshot area" "gnome-screenshot -a" "Print"
    set_custom_binding screenshot-window "Screenshot window" "gnome-screenshot -w" "<Super>Print"
    set_custom_binding mic-mute "Mute microphone" \
        "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" "<AudioMicMute>"
}

clear_shell_conflicts() {
    # GNOME Shell claims Super+number for launching Dash applications. Clear
    # those bindings so Mutter can use the keys for workspace switching.
    local application
    for application in {1..9}; do
        set_setting org.gnome.shell.keybindings "switch-to-application-$application" "[]"
    done

    # These overlap with the Hyprland-style custom bindings below.
    set_setting org.gnome.shell.keybindings focus-active-notification "[]"
    set_setting org.gnome.shell.keybindings show-screenshot-ui "[]"
    set_setting org.gnome.shell.keybindings screenshot "[]"
    set_setting org.gnome.shell.keybindings screenshot-window "[]"
    set_setting org.gnome.mutter.keybindings toggle-tiled-left "[]"
    set_setting org.gnome.mutter.keybindings toggle-tiled-right "[]"
    set_setting org.gnome.shell.extensions.dash-to-dock shortcut "[]"
    set_setting org.gnome.shell.extensions.dash-to-dock shortcut-text "''"
}

configure_extensions() {
    # Match the workspace assignments in hypr/config/windowrules.lua.
    set_setting org.gnome.shell.extensions.auto-move-windows application-list \
        "['librewolf.desktop:1','kitty.desktop:2','vscodium.desktop:3','bitwarden.desktop:4','steam.desktop:6']"

    # Dash to Dock provides the macOS-like bottom dock. Disable its number
    # hotkeys because Super+number belongs to workspace switching here.
    set_setting org.gnome.shell.extensions.dash-to-dock dock-position "'BOTTOM'"
    set_setting org.gnome.shell.extensions.dash-to-dock animation-time 0.0
    set_setting org.gnome.shell.extensions.dash-to-dock hot-keys false
    set_setting org.gnome.shell.extensions.dash-to-dock autohide true
    set_setting org.gnome.shell.extensions.dash-to-dock intellihide true
    set_setting org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 48
    set_setting org.gnome.shell.extensions.dash-to-dock multi-monitor false

    # Match the monitoring modules shown by Waybar. Battery is enabled here
    # as well as in GNOME's standard status area.
    set_setting org.gnome.shell.extensions.vitals show-processor true
    set_setting org.gnome.shell.extensions.vitals show-temperature true
    set_setting org.gnome.shell.extensions.vitals show-memory true
    set_setting org.gnome.shell.extensions.vitals show-network true
    set_setting org.gnome.shell.extensions.vitals show-battery true
    set_setting org.gnome.shell.extensions.vitals show-fan false
    set_setting org.gnome.shell.extensions.vitals show-gpu false
    set_setting org.gnome.shell.extensions.vitals show-storage false
    set_setting org.gnome.shell.extensions.vitals show-voltage false
    set_setting org.gnome.shell.extensions.vitals show-system false
    set_setting org.gnome.shell.extensions.vitals update-time 5
}

configure_blur_my_shell() {
    # Preserve the currently exposed Blur My Shell profile. Hyprland disables
    # blur, but this is an intentional GNOME-shell-only visual setting.
    local schema
    schema=org.gnome.shell.extensions.blur-my-shell
    set_setting "$schema" brightness 0.6
    set_setting "$schema" color "(0.0, 0.0, 0.0, 0.0)"
    set_setting "$schema" color-and-noise true
    set_setting "$schema" debug false
    set_setting "$schema" hacks-level 1
    set_setting "$schema" noise-amount 0.0
    set_setting "$schema" noise-lightness 0.0
    set_setting "$schema" rounded-blur-found true
    set_setting "$schema" settings-version 2
    set_setting "$schema" sigma 30
    set_setting "$schema" pipelines "{'pipeline_default': {'name': <'Default'>, 'effects': <[<{'type': <'native_static_gaussian_blur'>, 'id': <'effect_000000000000'>, 'params': <{'radius': <30>, 'brightness': <0.6>}>}>]>}, 'pipeline_default_rounded': {'name': <'Default rounded'>, 'effects': <[<{'type': <'native_static_gaussian_blur'>, 'id': <'effect_000000000001'>, 'params': <{'radius': <30>, 'brightness': <0.6>}>}>, <{'type': <'corner'>, 'id': <'effect_000000000002'>, 'params': <{'radius': <24>, 'corners_bottom': <true>, 'corners_top': <true>}>}>]>}}"

    schema=org.gnome.shell.extensions.blur-my-shell.appfolder
    set_setting "$schema" blur true
    set_setting "$schema" brightness 0.6
    set_setting "$schema" color "(0.0, 0.0, 0.0, 0.0)"
    set_setting "$schema" customize false
    set_setting "$schema" noise-amount 0.0
    set_setting "$schema" noise-lightness 0.0
    set_setting "$schema" sigma 30
    set_setting "$schema" style-dialogs 1

    schema=org.gnome.shell.extensions.blur-my-shell.applications
    set_setting "$schema" blacklist "['Plank','com.desktop.ding','Conky']"
    set_setting "$schema" blur false
    set_setting "$schema" blur-on-overview false
    set_setting "$schema" brightness 1.0
    set_setting "$schema" color "(0.0, 0.0, 0.0, 0.0)"
    set_setting "$schema" corner-radius 15
    set_setting "$schema" corner-when-maximized false
    set_setting "$schema" customize true
    set_setting "$schema" dynamic-opacity true
    set_setting "$schema" enable-all false
    set_setting "$schema" noise-amount 0.0
    set_setting "$schema" noise-lightness 0.0
    set_setting "$schema" opacity 215
    set_setting "$schema" pipeline "'pipeline_default'"
    set_setting "$schema" sigma 30
    set_setting "$schema" static-blur false
    set_setting "$schema" whitelist "[]"

    schema=org.gnome.shell.extensions.blur-my-shell.coverflow-alt-tab
    set_setting "$schema" blur true
    set_setting "$schema" pipeline "'pipeline_default'"

    schema=org.gnome.shell.extensions.blur-my-shell.dash-to-dock
    set_setting "$schema" blur true
    set_setting "$schema" brightness 0.6
    set_setting "$schema" color "(0.0, 0.0, 0.0, 0.0)"
    set_setting "$schema" corner-radius 18
    set_setting "$schema" customize false
    set_setting "$schema" noise-amount 0.0
    set_setting "$schema" noise-lightness 0.0
    set_setting "$schema" override-background true
    set_setting "$schema" pipeline "'pipeline_default_rounded'"
    set_setting "$schema" sigma 30
    set_setting "$schema" static-blur true
    set_setting "$schema" style-dash-to-dock 0
    set_setting "$schema" unblur-in-overview false

    set_setting org.gnome.shell.extensions.blur-my-shell.dash-to-panel blur-original-panel true
    set_setting org.gnome.shell.extensions.blur-my-shell.hidetopbar compatibility false

    schema=org.gnome.shell.extensions.blur-my-shell.lockscreen
    set_setting "$schema" blur true
    set_setting "$schema" brightness 0.6
    set_setting "$schema" color "(0.0, 0.0, 0.0, 0.0)"
    set_setting "$schema" customize false
    set_setting "$schema" noise-amount 0.0
    set_setting "$schema" noise-lightness 0.0
    set_setting "$schema" pipeline "'pipeline_default'"
    set_setting "$schema" sigma 30

    schema=org.gnome.shell.extensions.blur-my-shell.overview
    set_setting "$schema" blur true
    set_setting "$schema" brightness 0.6
    set_setting "$schema" color "(0.0, 0.0, 0.0, 0.0)"
    set_setting "$schema" customize false
    set_setting "$schema" noise-amount 0.0
    set_setting "$schema" noise-lightness 0.0
    set_setting "$schema" pipeline "'pipeline_default'"
    set_setting "$schema" sigma 30
    set_setting "$schema" style-components 1

    schema=org.gnome.shell.extensions.blur-my-shell.panel
    set_setting "$schema" blur true
    set_setting "$schema" brightness 0.6
    set_setting "$schema" color "(0.0, 0.0, 0.0, 0.0)"
    set_setting "$schema" corner-radius 0
    set_setting "$schema" customize false
    set_setting "$schema" force-light-text false
    set_setting "$schema" noise-amount 0.0
    set_setting "$schema" noise-lightness 0.0
    set_setting "$schema" override-background true
    set_setting "$schema" override-background-dynamically false
    set_setting "$schema" pipeline "'pipeline_default_rounded'"
    set_setting "$schema" sigma 30
    set_setting "$schema" static-blur true
    set_setting "$schema" style-panel 0
    set_setting "$schema" unblur-in-overview true

    for schema in \
        org.gnome.shell.extensions.blur-my-shell.screenshot \
        org.gnome.shell.extensions.blur-my-shell.window-list; do
        set_setting "$schema" blur true
        set_setting "$schema" brightness 0.6
        set_setting "$schema" color "(0.0, 0.0, 0.0, 0.0)"
        set_setting "$schema" customize false
        set_setting "$schema" noise-amount 0.0
        set_setting "$schema" noise-lightness 0.0
        set_setting "$schema" pipeline "'pipeline_default'"
        set_setting "$schema" sigma 30
    done
}

configure_dock() {
    # This is the current Dash to Dock order. Desktop file IDs are portable
    # across machines as long as the corresponding applications are installed.
    set_setting org.gnome.shell favorite-apps \
        "['org.gnome.Nautilus.desktop', 'librewolf.desktop', 'bitwarden.desktop', 'org.mozilla.Thunderbird.desktop', 'org.telegram.desktop.desktop', 'vscodium.desktop', 'kitty.desktop', 'com.shellyorg.shelly.desktop', 'steam.desktop', 'org.gnome.SystemMonitor.desktop']"
}

apply_settings() {
    # Catppuccin Mocha and the JetBrains Mono choices from the Hyprland setup.
    set_setting org.gnome.desktop.interface color-scheme "'prefer-dark'"
    set_setting org.gnome.desktop.interface gtk-theme "'Orchis-Dark'"
    set_setting org.gnome.desktop.wm.preferences theme "'Orchis-Dark'"
    set_setting org.gnome.desktop.interface icon-theme "'Papirus'"
    set_setting org.gnome.desktop.interface cursor-theme "'Vimix-cursors'"
    set_setting org.gnome.desktop.interface accent-color "'orange'"
    set_setting org.gnome.shell.extensions.user-theme name "'Orchis-Dark'"
    set_setting org.gnome.desktop.interface font-name "'JetBrainsMono Nerd Font 11'"
    set_setting org.gnome.desktop.interface monospace-font-name "'JetBrainsMono Nerd Font 12'"
    set_setting org.gnome.desktop.interface enable-animations false
    set_setting org.gnome.desktop.interface show-battery-percentage true
    set_setting org.gnome.desktop.interface clock-format "'24h'"
    set_setting org.gnome.desktop.interface clock-show-date true
    set_setting org.gnome.desktop.interface clock-show-weekday true
    set_setting org.gnome.desktop.interface enable-hot-corners false

    # hyprpaper equivalent. GNOME uses separate light and dark wallpaper keys.
    local wallpaper="file://$HOME/.config/wallpapers/peach_unicat.png"
    set_setting org.gnome.desktop.background picture-uri "'$wallpaper'"
    set_setting org.gnome.desktop.background picture-uri-dark "'$wallpaper'"

    # Match the flat acceleration profile in input.lua.
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
    configure_extensions
    configure_blur_my_shell
    configure_dock
    configure_custom_bindings
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
