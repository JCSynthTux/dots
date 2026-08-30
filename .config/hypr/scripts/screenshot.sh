#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-region}"
DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$DIR"
OUT="$DIR/$(date +%Y%m%d-%H%M%S).png"

case "$MODE" in
    region)
        grim -g "$(slurp)" "$OUT"
        ;;
    window)
        grim -g "$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" "$OUT"
        ;;
    *)
        echo "usage: screenshot.sh [region|window]" >&2
        exit 1
        ;;
esac

notify-send "Screenshot saved" "$OUT"