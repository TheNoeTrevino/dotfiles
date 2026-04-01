#!/usr/bin/env bash

LAPTOP="eDP-1"
# Identify monitors by description substring (stable across DP name changes)
PORTRAIT_DESC="XVNNT8B7ASQL"  # Dell U2417H - portrait left
MAIN_DESC="AW2725QF"          # Dell AW2725QF - 4K center
SIDE_DESC="XVNNT73E864L"     # Dell U2417H - landscape right

# Find DP name by matching description
find_monitor() {
  hyprctl monitors all | awk -v desc="$1" '
    /^Monitor / { name = $2 }
    /description:/ && index($0, desc) { print name; exit }
  '
}

apply_docked() {
  local portrait main side
  portrait=$(find_monitor "$PORTRAIT_DESC")
  main=$(find_monitor "$MAIN_DESC")
  side=$(find_monitor "$SIDE_DESC")

  # Disable laptop, no caps:swapescape
  hyprctl keyword input:kb_options ""
  hyprctl keyword monitor "$LAPTOP, disable"

  # Portrait left: 1080x1920 logical after transform
  [[ -n "$portrait" ]] && hyprctl keyword monitor "$portrait, 1920x1080@60, 0x0, 1, transform, 1"
  # 4K center: x=1080 (portrait logical width), scale 1.5 -> 2560x1440 logical
  [[ -n "$main" ]] && hyprctl keyword monitor "$main, highrr, 1080x0, 1.5"
  # Landscape right: x = 1080 + 2560 = 3640
  [[ -n "$side" ]] && hyprctl keyword monitor "$side, 1920x1080@60, 3640x0, 1"

  # Workspace assignment
  [[ -n "$portrait" ]] && {
    hyprctl keyword workspace "1, monitor:$portrait, default:true"
    hyprctl dispatch moveworkspacetomonitor 1 "$portrait"
  }
  if [[ -n "$main" ]]; then
    for ws in 2 3 4 5; do
      hyprctl keyword workspace "$ws, monitor:$main"
      hyprctl dispatch moveworkspacetomonitor "$ws" "$main"
    done
    hyprctl keyword workspace "2, monitor:$main, default:true"
  fi
  if [[ -n "$side" ]]; then
    for ws in 6 7 8 9; do
      hyprctl keyword workspace "$ws, monitor:$side"
      hyprctl dispatch moveworkspacetomonitor "$ws" "$side"
    done
    hyprctl keyword workspace "6, monitor:$side, default:true"
  fi
}

apply_laptop_only() {
  hyprctl keyword input:kb_options "caps:swapescape"
  hyprctl keyword monitor "$LAPTOP, highrr, auto, 2"

  for ws in 1 2 3 4 5 6 7 8 9; do
    hyprctl keyword workspace "$ws, monitor:$LAPTOP"
  done
  hyprctl keyword workspace "1, monitor:$LAPTOP, default:true"
}

is_docked() {
  hyprctl monitors all | grep -qv "^Monitor $LAPTOP "
}

apply_layout() {
  if is_docked; then
    apply_docked
  else
    apply_laptop_only
  fi
}

handle() {
  readarray -t parts < <(echo "${1//>>/$'\n'}")
  [[ ${#parts[@]} -ne 2 ]] && return
  local event="${parts[0]}"
  local data="${parts[1]}"

  case "$event" in
  monitorremoved)
    sleep 0.5
    apply_layout
    ;;
  monitoradded)
    [[ "$data" != "$LAPTOP" ]] && sleep 0.5 && apply_docked
    ;;
  esac
}

# Initial layout on startup
apply_layout

# Listen for monitor hotplug events
socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
  while IFS= read -r line; do handle "$line"; done
