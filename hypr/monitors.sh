#!/usr/bin/env bash

# Monitor identifiers
LAPTOP="eDP-1"
PORTRAIT="DP-11" # Dell U2417H - portrait/chat monitor (left)
MAIN="DP-4"      # Dell AW2725QF - primary 4K (center)
SIDE="DP-10"     # Dell U2417H - secondary landscape (right)

connected() {
  hyprctl monitors all | grep -q "^Monitor $1 "
}

apply_docked() {
  hyprctl keyword input:kb_options ""
  hyprctl keyword monitor "$LAPTOP, disable"

  # Portrait on the left: rotate 90 CW (transform 1)
  # Native 1920x1080, after transform logical size is 1080w x 1920h
  hyprctl keyword monitor "$PORTRAIT, 1920x1080@60, 0x0, 1, transform, 1"

  # Main 4K center: starts at x=1080 (portrait logical width)
  # scale 1.5 -> logical 2560w x 1440h
  hyprctl keyword monitor "$MAIN, 3840x2160@180, 1080x0, 1.5"

  # Side landscape: starts at x = 1080 + 2560 = 3640
  hyprctl keyword monitor "$SIDE, 1920x1080@60, 3640x0, 1"

  # Portrait (chats): workspace 1
  hyprctl keyword workspace "1, monitor:$PORTRAIT, default:true"

  # Main (primary work): workspaces 2-5
  hyprctl keyword workspace "2, monitor:$MAIN, default:true"
  hyprctl keyword workspace "3, monitor:$MAIN"
  hyprctl keyword workspace "4, monitor:$MAIN"
  hyprctl keyword workspace "5, monitor:$MAIN"

  # Side (secondary): workspaces 6-9
  hyprctl keyword workspace "6, monitor:$SIDE, default:true"
  hyprctl keyword workspace "7, monitor:$SIDE"
  hyprctl keyword workspace "8, monitor:$SIDE"
  hyprctl keyword workspace "9, monitor:$SIDE"

  # Move any already-open workspaces to the correct monitors
  hyprctl dispatch moveworkspacetomonitor 1 "$PORTRAIT"
  for ws in 2 3 4 5; do
    hyprctl dispatch moveworkspacetomonitor $ws "$MAIN"
  done
  for ws in 6 7 8 9; do
    hyprctl dispatch moveworkspacetomonitor $ws "$SIDE"
  done
}

apply_laptop_only() {
  hyprctl keyword input:kb_options "caps:swapescape"
  hyprctl keyword monitor "$LAPTOP, 2880x1920@120, 0x0, 2"

  hyprctl keyword monitor "$PORTRAIT, disable"
  hyprctl keyword monitor "$MAIN, disable"
  hyprctl keyword monitor "$SIDE, disable"

  for i in 1 2 3 4 5 6 7 8 9; do
    hyprctl keyword workspace "$i, monitor:$LAPTOP"
  done
  hyprctl keyword workspace "1, monitor:$LAPTOP, default:true"
}

apply_layout() {
  if connected "$MAIN" || connected "$PORTRAIT" || connected "$SIDE"; then
    apply_docked
  else
    apply_laptop_only
  fi
}

# --watch mode: react to monitor plug/unplug via Hyprland's IPC socket
if [[ "$1" == "--watch" ]]; then
  handle() {
    case $1 in
    monitoradded* | monitorremoved*)
      sleep 1 # brief delay for the monitor to fully register
      apply_layout
      ;;
    esac
  }
  socat - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
    while read -r line; do handle "$line"; done
else
  apply_layout
  # Ensure the event watcher is running (only one instance)
  if ! pgrep -f "monitors.sh --watch" >/dev/null; then
    nohup bash ~/.config/hypr/monitors.sh --watch &>/dev/null &
  fi
fi
