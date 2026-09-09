#!/usr/bin/env bash
# hypridle's 15-minute on-timeout. Suspends only if no external monitors are
# connected -- the same rule lid-closed.sh applies to the lid switch.
#
# Why: resuming from suspend while on the Lenovo 40AS dock leaves its two
# MST-hub monitors dead. amdgpu logs "DM_MST: Differing MST start" on resume
# and from then on rejects every atomic commit on those connectors with
# EINVAL (Hyprland shows them at mode 0x0). A USB-C replug does NOT recover
# it because the dock is self-powered and keeps its state; only a dock
# power-cycle does. Observed 2026-09-08 on kernel 7.2.3 / Hyprland 0.56.2.
#
# Tradeoff: while docked the laptop now stays awake when idle (lid closed,
# panel off, externals DPMS-off after 6 min). Suspend manually via wlogout
# when leaving it for long. To revert, point hypridle's 900s on-timeout back
# at `systemctl suspend`.

LAPTOP="eDP-1"
LOG="/tmp/monitors.log"
log() { echo "[$(date '+%H:%M:%S')] idle-suspend: $*" >> "$LOG"; }

if hyprctl monitors all | grep "^Monitor " | grep -qv "^Monitor $LAPTOP "; then
  log "external monitors present, not suspending"
  exit 0
fi

log "no external monitors, suspending"
systemctl suspend
