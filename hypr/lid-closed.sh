#!/usr/bin/env bash
# Triggered by Hyprland's lid-close bind. Re-runs the monitor layout,
# then suspends only if no external monitors are connected.

LAPTOP="eDP-1"
LOG="/tmp/monitors.log"
log() { echo "[$(date '+%H:%M:%S')] lid-closed: $*" >> "$LOG"; }

pkill -USR1 -f 'monitors\.sh'

# Give monitors.sh a moment to apply the layout before we check dock state.
sleep 0.3

if hyprctl monitors all | grep "^Monitor " | grep -qv "^Monitor $LAPTOP "; then
  log "external monitors present, not suspending"
  exit 0
fi

log "no external monitors, suspending"
systemctl suspend
