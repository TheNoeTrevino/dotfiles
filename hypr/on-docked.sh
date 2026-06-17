#!/usr/bin/env bash
# Run by kanshi when the `docked` profile activates.
# Monitor layout is already applied by kanshi; here we only handle
# workspace->monitor assignment and keyboard options.

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

# Docked: laptop keyboard, so drop the caps:swapescape remap.
hyprctl keyword input:kb_options ""

# Left monitor: workspace 1
if [[ -n "$left" ]]; then
  hyprctl keyword workspace "1, monitor:$left, default:true"
  hyprctl dispatch moveworkspacetomonitor 1 "$left"
fi

# Middle monitor: workspaces 2-5 (default 2)
if [[ -n "$mid" ]]; then
  for ws in 2 3 4 5; do
    hyprctl keyword workspace "$ws, monitor:$mid"
    hyprctl dispatch moveworkspacetomonitor "$ws" "$mid"
  done
  hyprctl keyword workspace "2, monitor:$mid, default:true"
fi

# Right monitor: workspaces 6-9 (default 6)
if [[ -n "$right" ]]; then
  for ws in 6 7 8 9; do
    hyprctl keyword workspace "$ws, monitor:$right"
    hyprctl dispatch moveworkspacetomonitor "$ws" "$right"
  done
  hyprctl keyword workspace "6, monitor:$right, default:true"
fi
