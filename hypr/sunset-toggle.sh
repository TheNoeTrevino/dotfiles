#!/usr/bin/env bash
# Toggle hyprsunset night light between warm and neutral (identity).
# State is tracked via a flag file because `hyprctl hyprsunset identity`
# does not reset the stored temperature value (querying it is unreliable).

WARM=4000
STATE="${XDG_RUNTIME_DIR:-/tmp}/hyprsunset.state"

if [ -f "$STATE" ]; then
  hyprctl hyprsunset identity >/dev/null
  rm -f "$STATE"
  notify-send -t 1500 -a hyprsunset "Night light" "Off"
else
  hyprctl hyprsunset temperature "$WARM" >/dev/null
  touch "$STATE"
  notify-send -t 1500 -a hyprsunset "Night light" "On · ${WARM}K"
fi
