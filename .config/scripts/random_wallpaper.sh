#!/bin/bash

# Check if a directory argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/directory"
    exit 1
fi

# Check if the provided argument is a valid directory
if [ ! -d "$1" ]; then
    echo "Error: $1 is not a valid directory."
    exit 1
fi

# Get a list of files in the directory
files=("$1"/*)

# Check if the directory is empty
if [ ${#files[@]} -eq 0 ]; then
    echo "Error: The directory is empty."
    exit 1
fi

# Pick a random file
random_file=${files[RANDOM % ${#files[@]}]}

# Set the random file as wallpaper using osascript
osascript -e 'tell application "System Events" to set picture of every desktop to POSIX file "'"$random_file"'"'
