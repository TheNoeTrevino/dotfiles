#!/usr/bin/env bash
# Run by kanshi when the `laptop` profile activates (undocked).
# Monitor layout is already applied by kanshi; here we handle
# workspace->monitor assignment (keyboard options are per-device in hyprland.conf).

LAPTOP="eDP-1"

# NOTE: keyboard options are NOT set here any more. caps:swapescape is pinned
# per-device to the built-in keyboard in hyprland.conf, so it no longer depends
# on which monitor profile is active. See the `device` block there.

# All workspaces live on the laptop screen.
for ws in 1 2 3 4 5 6 7 8 9; do
  hyprctl keyword workspace "$ws, monitor:$LAPTOP"
done
hyprctl keyword workspace "1, monitor:$LAPTOP, default:true"

# Guarantee the panel is powered on whenever the laptop becomes the active
# display. If this profile activated while the lid was still closed (externals
# unplugged before opening), eDP-1 can be enabled-but-DPMS-off; force it on.
hyprctl dispatch dpms on "$LAPTOP"

# Clear external-monitor brightness cache (back to laptop backlight).
: > "${XDG_RUNTIME_DIR:-/tmp}/ddc-buses"

# Apply the laptop wallpaper (WP_MAIN; see hypr/wallpaper.conf).
~/.config/hypr/wallpaper.sh &
