#!/usr/bin/env bash

set -euo pipefail

mapfile -t profiles < <(
    powerprofilesctl list |
        awk '/^(\* |  )[a-z0-9-]+:/ {
            sub(/^(\* |  )/, "")
            sub(/:.*/, "")
            print
        }'
)

current=$(powerprofilesctl get)

if [[ ${#profiles[@]} -eq 0 ]]; then
    printf '{"text":"󰾆 unavailable","tooltip":"power-profiles-daemon profiles unavailable"}\n'
    exit 0
fi

if [[ ${1:-} == "--cycle" ]]; then
    for index in "${!profiles[@]}"; do
        if [[ ${profiles[index]} == "$current" ]]; then
            next_index=$(( (index + 1) % ${#profiles[@]} ))
            powerprofilesctl set "${profiles[next_index]}"
            current=${profiles[next_index]}
            break
        fi
    done
fi

case "$current" in
    performance) icon="" ;;
    balanced) icon="" ;;
    power-saver) icon="" ;;
    *) icon="󰾆" ;;
esac

printf '{"text":"%s %s","alt":"%s","class":"%s","tooltip":"Power profile: %s\\nClick to cycle"}\n' \
    "$icon" "$current" "$current" "$current" "$current"
