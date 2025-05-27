#!/user/bin/env bash

# Wallpaper daemon
swww init &
# Set the wallpaper
swww img ~/.Wallpapers/gruvbox-mountain-village.png &

# Helps manage network connections visually
nm-applet --indicator &

# the top bar
waybar &

# notifications (requires libnotify)
dunst
