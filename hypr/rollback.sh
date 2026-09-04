#!/usr/bin/env bash
# Return to hyprland.conf. Hyprland picks hyprland.lua over hyprland.conf purely
# by filename, so moving it aside is a complete rollback.
set -euo pipefail
cd ~/.config/hypr
if [ -e hyprland.lua ]; then
	mv hyprland.lua hyprland-lua-wip.lua
	echo "rollback staged — log out and back in to return to hyprland.conf"
else
	echo "hyprland.lua not present; hyprland.conf is already staged — log out and back in if you haven't yet"
fi
