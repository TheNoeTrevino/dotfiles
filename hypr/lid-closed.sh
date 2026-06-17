#!/usr/bin/env bash
# Triggered by Hyprland's lid-close bind. Suspends only if no external
# monitors are connected. Display layout itself is handled by kanshi,
# which reacts to monitor hotplug automatically.

LAPTOP="eDP-1"
LOG="/tmp/monitors.log"
log() { echo "[$(date '+%H:%M:%S')] lid-closed: $*" >> "$LOG"; }

if hyprctl monitors all | grep "^Monitor " | grep -qv "^Monitor $LAPTOP "; then
  log "external monitors present, not suspending"
  exit 0
fi

log "no external monitors, suspending"
systemctl suspend
