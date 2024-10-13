OSA_CURRENTLY_PLAYING=$(osascript -e 'tell application "Music" to if it is running then get the name of the current track & " - " & the artist of the current track')

echo "$current_track"

if [ -n "$OSA_CURRENTLY_PLAYING" ]; then
    CURRENTLY_PLAYING=$OSA_CURRENTLY_PLAYING
else
    CURRENTLY_PLAYING="Nothing Playing"
fi

sketchybar --set "$NAME" label="${CURRENTLY_PLAYING}"
