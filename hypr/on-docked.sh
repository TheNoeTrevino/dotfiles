#!/usr/bin/env bash
# Run by kanshi when the `docked` profile activates.
# Monitor layout is already applied by kanshi; here we only handle
# workspace->monitor assignment (keyboard options are per-device in lua/input.lua).

source "$HOME/.config/hypr/hyprctl-lua.sh"

# Resolve a connector name (DP-x) from a stable EDID serial substring,
# since DP-x numbers are not stable across replugs.
find_monitor() {
  hyprctl monitors all | awk -v desc="$1" '
    /^Monitor / { name = $2 }
    /description:/ && index($0, desc) { print name; exit }
  '
}

left=$(find_monitor "T3LMQS142415")   # ASUS VP229
mid=$(find_monitor "CQF2D34")         # Dell AW2725QF
right=$(find_monitor "V5XT8124")      # Lenovo S27q-10

# NOTE: keyboard options are NOT set here any more. caps:swapescape is pinned
# per-device to the built-in keyboard in lua/input.lua, so it no longer depends
# on which monitor profile is active. See the `hl.device` block there.

# Left monitor: workspace 1
if [[ -n "$left" ]]; then
  ws_rule 1 "$left" default
  ws_move 1 "$left"
fi

# Middle monitor: workspaces 2-5 (default 2)
if [[ -n "$mid" ]]; then
  for ws in 2 3 4 5; do
    ws_rule "$ws" "$mid"
    ws_move "$ws" "$mid"
  done
  ws_rule 2 "$mid" default
fi

# Right monitor: workspaces 6-9 (default 6)
if [[ -n "$right" ]]; then
  for ws in 6 7 8 9; do
    ws_rule "$ws" "$right"
    ws_move "$ws" "$right"
  done
  ws_rule 6 "$right" default
fi

# Refresh the external-monitor brightness bus cache (ddc-brightness.sh).
~/.config/hypr/ddc-cache.sh &

# Apply per-monitor wallpapers (serial-keyed; see hypr/wallpaper.conf).
~/.config/hypr/wallpaper.sh &
