#!/usr/bin/env bash
# Fast, unified brightness control that works docked or undocked.
#
#   docked   -> ALL external monitors over DDC/CI (parallel, cached I2C
#               buses, ~0.6s) with a swayosd OSD popup
#   undocked -> the laptop backlight via swayosd / brightnessctl
#
# Usage: ddc-brightness.sh up|down|set <0-100>|status
#   status -> prints the current brightness percentage (for waybar)

CACHE="${XDG_RUNTIME_DIR:-/tmp}/ddc-buses"
STEP=5
VCP=10   # VCP feature code 0x10 = brightness

# Build the bus cache on demand if a dock hook hasn't already.
[ -s "$CACHE" ] || ~/.config/hypr/ddc-cache.sh
mapfile -t buses < "$CACHE" 2>/dev/null

# Tell the waybar custom/brightness module (signal 9) to refresh now.
refresh_bar() { pkill -RTMIN+9 waybar 2>/dev/null; }

# ── No external monitors: drive the laptop panel ─────────────────────
if [ "${#buses[@]}" -eq 0 ]; then
  case "$1" in
    up)   swayosd-client --brightness raise; refresh_bar ;;
    down) swayosd-client --brightness lower; refresh_bar ;;
    set)  brightnessctl set "${2}%" >/dev/null; refresh_bar ;;
    status)
      brightnessctl -m 2>/dev/null | awk -F, '{gsub("%","",$4); print $4}'
      ;;
  esac
  exit 0
fi

# ── External monitors over DDC ───────────────────────────────────────
case "$1" in
  up)   op="+ $STEP" ;;
  down) op="- $STEP" ;;
  set)  op="$2" ;;
  status)
    ddcutil --bus "${buses[0]}" --brief getvcp "$VCP" 2>/dev/null | awk '/^VCP/{print $4}'
    exit 0 ;;
  *) echo "usage: $0 up|down|set <0-100>|status"; exit 1 ;;
esac

# One retry per bus — DDC occasionally drops a write (esp. the ASUS).
for b in "${buses[@]}"; do
  ( ddcutil --bus "$b" --noverify setvcp "$VCP" $op >/dev/null 2>&1 \
    || ddcutil --bus "$b" --noverify setvcp "$VCP" $op >/dev/null 2>&1 ) &
done
wait

# OSD feedback from the first monitor, then refresh the bar readout.
cur=$(ddcutil --bus "${buses[0]}" --brief getvcp "$VCP" 2>/dev/null | awk '/^VCP/{print $4}')
if [ -n "$cur" ]; then
  swayosd-client --custom-progress "$(awk "BEGIN{printf \"%.2f\", $cur/100}")" \
    --custom-icon display-brightness-symbolic 2>/dev/null
fi
refresh_bar
