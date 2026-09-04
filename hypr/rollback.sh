#!/usr/bin/env bash
# Return to hyprland.conf. Hyprland picks hyprland.lua over hyprland.conf purely
# by filename, so moving it aside is a complete rollback.
set -euo pipefail
cd ~/.config/hypr
if [ -e hyprland.lua ]; then
	mv hyprland.lua hyprland-lua-wip.lua
	echo "rolled back to hyprland.conf"
else
	echo "hyprland.lua not present; already on hyprland.conf"
fi
hyprctl reload
