#!/usr/bin/env bash

# make sure it's executable with:
# chmod +x ~/.config/sketchybar/plugins/aerospace.sh

source "$HOME/.config/sketchybar/variables.sh" # Loads all defined colors

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set $NAME \
        label.color="$RED"
else
    sketchybar --set $NAME \
        label.color="$COMMENT"
fi
