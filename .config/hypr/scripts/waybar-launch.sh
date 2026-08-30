#!/usr/bin/env bash
# Pick the waybar config based on the displays present:
#   laptop (eDP-1)   -> config-laptop.jsonc (proportional margins on the smaller screen)
#   everything else  -> config.jsonc
set -euo pipefail

CONF="$HOME/.config/waybar/config.jsonc"
if hyprctl monitors -j | jq -e '.[] | select(.name == "eDP-1")' >/dev/null 2>&1; then
    CONF="$HOME/.config/waybar/config-laptop.jsonc"
fi

exec waybar -c "$CONF"