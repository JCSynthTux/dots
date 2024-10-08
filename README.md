# macOS Dots
## Installation Instructions

1. Run ```git``` in your Terminal and go through the xCode setup
2. Install [Brew](https://brew.sh/)
3. Install Packages with ```xargs brew install < my_brew.txt```
4. Install Casks with ```xargs brew install --cask < my_brew_cask.txt```
5. Run ```skhd``` with ```skhd --start-service```
6. Open the Accessability Settings and enable skhd
7. Run Aerospace
8. Open the Accessability Settings and enable Aerospace
9. Run the ```.osx``` script

## Sketchybar
Make sure Sketchybars brew service is disabled with ```brew services stop sketchybar```.

Sketchybar start up should be handled via ```aerospace```, since the ```brew service``` runs
before ```aerospace``` and therefore the workspace will not be rendered correctly.
