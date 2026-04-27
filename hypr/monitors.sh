#!/usr/bin/env bash

LAPTOP="eDP-1"
LOG="/tmp/monitors.log"
log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }
# Identify monitors by description substring (stable across DP name changes)
PORTRAIT_DESC="XVNNT8B7ASQL" # Dell U2417H - portrait left
MAIN_DESC="AW2725QF"         # Dell AW2725QF - 4K center
SIDE_DESC="XVNNT73E864L"     # Dell U2417H - landscape right

WALLPAPER_DIR="$HOME/.config/wallpapers"
PORTRAIT_WALL="$WALLPAPER_DIR/samurai-cat.png"
MAIN_WALL="$WALLPAPER_DIR/chainsaw-man-the-5120x2880-23852.jpg"
SIDE_WALL="$WALLPAPER_DIR/chainsaw-man-the-5120x2880-23852.jpg"
LAPTOP_WALL="$WALLPAPER_DIR/chainsaw-man-the-5120x2880-23852.jpg"

# Find DP name by matching description
find_monitor() {
  hyprctl monitors all | awk -v desc="$1" '
    /^Monitor / { name = $2 }
    /description:/ && index($0, desc) { print name; exit }
  '
}

apply_docked() {
  log "apply_docked: start"
  local portrait main side
  portrait=$(find_monitor "$PORTRAIT_DESC")
  main=$(find_monitor "$MAIN_DESC")
  side=$(find_monitor "$SIDE_DESC")
  log "apply_docked: portrait=$portrait main=$main side=$side"

  # Disable laptop, no caps:swapescape
  hyprctl keyword input:kb_options ""
  hyprctl keyword monitor "$LAPTOP, disable"

  # Portrait left: 1080x1920 logical after transform
  [[ -n "$portrait" ]] && hyprctl keyword monitor "$portrait, preferred, 0x0, 1, transform, 1"
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

  apply_wallpapers "$portrait" "$main" "$side"
}

apply_wallpapers() {
  # Skip if awww-daemon isn't running
  pgrep -x awww-daemon >/dev/null || { log "apply_wallpapers: awww-daemon not running"; return; }
  local portrait="$1" main="$2" side="$3"
  log "apply_wallpapers: portrait=$portrait main=$main side=$side"
  [[ -n "$portrait" ]] && awww img "$PORTRAIT_WALL" --outputs "$portrait"
  [[ -n "$main" ]] && awww img "$MAIN_WALL" --outputs "$main"
  [[ -n "$side" ]] && awww img "$SIDE_WALL" --outputs "$side"
}

apply_laptop_only() {
  log "apply_laptop_only: start"
  local result
  result=$(hyprctl keyword input:kb_options "caps:swapescape" 2>&1)
  log "apply_laptop_only: kb_options result=$result"
  result=$(hyprctl keyword monitor "$LAPTOP, highrr, auto, 2" 2>&1)
  log "apply_laptop_only: monitor enable result=$result"

  for ws in 1 2 3 4 5 6 7 8 9; do
    hyprctl keyword workspace "$ws, monitor:$LAPTOP"
  done
  hyprctl keyword workspace "1, monitor:$LAPTOP, default:true"

  apply_laptop_wallpaper
}

apply_laptop_wallpaper() {
  pgrep -x awww-daemon >/dev/null || { log "apply_laptop_wallpaper: awww-daemon not running"; return; }
  log "apply_laptop_wallpaper: setting $LAPTOP_WALL on $LAPTOP"
  awww img "$LAPTOP_WALL" --outputs "$LAPTOP"
}

is_docked() {
  local monitors
  monitors=$(hyprctl monitors all | grep "^Monitor ")
  log "is_docked: monitors=[$monitors]"
  echo "$monitors" | grep -qv "^Monitor $LAPTOP "
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
  monitorremoved | monitoradded)
    log "handle: event=$event data=$data"
    sleep 0.5
    apply_layout
    ;;
  esac
}

# Re-evaluate on SIGUSR1 (sent by lid switch bindings in hyprland.conf)
trap 'apply_layout' USR1

# Initial layout on startup
apply_layout

# Listen for monitor hotplug events
if command -v socat &>/dev/null; then
  socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
    while IFS= read -r line; do handle "$line"; done
else
  log "WARN: socat not found, falling back to polling"
  prev_docked=$(is_docked && echo y || echo n)
  while sleep 2; do
    curr_docked=$(is_docked && echo y || echo n)
    if [[ "$curr_docked" != "$prev_docked" ]]; then
      log "poll: dock state changed ($prev_docked -> $curr_docked)"
      apply_layout
      prev_docked="$curr_docked"
    fi
  done
fi
