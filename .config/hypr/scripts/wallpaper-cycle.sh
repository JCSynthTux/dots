#!/usr/bin/env bash
set -euo pipefail

DIR="$HOME/.config/wallpapers"
STATE="${XDG_RUNTIME_DIR:-/tmp}/wallpaper-index"

shopt -s nullglob
WALLS=("$DIR"/*)
if [ ${#WALLS[@]} -eq 0 ]; then
    echo "no wallpapers found in $DIR" >&2
    exit 1
fi

IDX=0
if [ -f "$STATE" ]; then
    IDX=$(cat "$STATE" 2>/dev/null || echo 0)
fi
IDX=$(( (IDX + 1) % ${#WALLS[@]} ))
echo "$IDX" > "$STATE"

for MON in $(hyprctl monitors -j | jq -r '.[].name'); do
    hyprctl hyprpaper wallpaper "$MON,${WALLS[$IDX]}" >/dev/null
done