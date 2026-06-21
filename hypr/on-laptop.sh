#!/usr/bin/env bash
# Run by kanshi when the `laptop` profile activates (undocked).
# Monitor layout is already applied by kanshi; here we handle
# workspace->monitor assignment and keyboard options.

LAPTOP="eDP-1"

# Undocked: built-in keyboard, restore caps:swapescape.
hyprctl keyword input:kb_options "caps:swapescape"

# All workspaces live on the laptop screen.
for ws in 1 2 3 4 5 6 7 8 9; do
  hyprctl keyword workspace "$ws, monitor:$LAPTOP"
done
hyprctl keyword workspace "1, monitor:$LAPTOP, default:true"

# Clear external-monitor brightness cache (back to laptop backlight).
: > "${XDG_RUNTIME_DIR:-/tmp}/ddc-buses"
