#!/usr/bin/env bash
# Run by kanshi when the `aw-only` profile activates (just the AW, laptop off).
# Monitor layout is already applied by kanshi; here we only handle
# workspace->monitor assignment (keyboard options are per-device in lua/input.lua).

source "$HOME/.config/hypr/hyprctl-lua.sh"

find_monitor() {
  hyprctl monitors all | awk -v desc="$1" '
    /^Monitor / { name = $2 }
    /description:/ && index($0, desc) { print name; exit }
  '
}

aw=$(find_monitor "CQF2D34")   # Dell AW2725QF

# NOTE: keyboard options are NOT set here any more. caps:swapescape is pinned
# per-device to the built-in keyboard in lua/input.lua, so it no longer depends
# on which monitor profile is active. See the `hl.device` block there.

# Single monitor: all workspaces live on the AW.
if [[ -n "$aw" ]]; then
  for ws in 1 2 3 4 5 6 7 8 9; do
    ws_rule "$ws" "$aw"
    ws_move "$ws" "$aw"
  done
  ws_rule 1 "$aw" default
fi

# Refresh the external-monitor brightness bus cache (ddc-brightness.sh).
~/.config/hypr/ddc-cache.sh &

# Apply per-monitor wallpapers (serial-keyed; see hypr/wallpaper.conf).
~/.config/hypr/wallpaper.sh &
