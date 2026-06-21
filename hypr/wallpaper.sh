#!/usr/bin/env bash
# Apply per-monitor wallpapers with awww, keyed by EDID serial.
#
# Called by the kanshi hooks (on-docked.sh / on-aw-only.sh / on-laptop.sh) on
# every profile switch, and once at login via exec-once in hyprland.conf, so the
# right wallpaper lands on each screen regardless of how monitors are plugged.
#
# Usage:
#   wallpaper.sh            apply the saved config to every connected monitor
#   wallpaper.sh <output>   (re)apply only that connector's saved wallpaper
#
# The mapping lives in ~/.config/hypr/wallpaper.conf (serial -> file).

set -u
CONF="$HOME/.config/hypr/wallpaper.conf"
[[ -r "$CONF" ]] || { echo "wallpaper.sh: missing $CONF" >&2; exit 1; }
# shellcheck source=/dev/null
source "$CONF"

RESIZE="crop"          # fill the screen, cropping overflow (handles portrait too)
FILL="000000"          # letterbox color if an image can't fill
TRANSITION="fade"      # gentle cross-fade between wallpapers

only_output="${1:-}"   # optional: restrict to a single connector

# Wait for awww-daemon to be ready (it autostarts in parallel at login).
for _ in $(seq 1 50); do
  awww query >/dev/null 2>&1 && break
  sleep 0.1
done

# Resolve "file" -> absolute path under WALLPAPER_DIR unless already absolute.
resolve() {
  local f="$1"
  [[ "$f" = /* ]] && { printf '%s' "$f"; return; }
  printf '%s/%s' "$WALLPAPER_DIR" "$f"
}

# Pick the wallpaper for a monitor given its description line (contains serial).
wallpaper_for() {
  local desc="$1" serial
  for serial in "${!WP_BY_SERIAL[@]}"; do
    if [[ "$desc" == *"$serial"* ]]; then
      resolve "${WP_BY_SERIAL[$serial]}"
      return
    fi
  done
  resolve "$WP_MAIN"   # laptop / anything unmapped
}

apply() {
  local out="$1" img="$2"
  [[ -f "$img" ]] || { echo "wallpaper.sh: not found: $img (for $out)" >&2; return; }
  awww img -o "$out" "$img" \
    --resize "$RESIZE" --fill-color "$FILL" \
    --transition-type "$TRANSITION" --transition-duration 0.6 >/dev/null 2>&1
}

# Walk every connected monitor: collect "connector<TAB>description".
while IFS=$'\t' read -r name desc; do
  [[ -n "$name" ]] || continue
  [[ -n "$only_output" && "$name" != "$only_output" ]] && continue
  apply "$name" "$(wallpaper_for "$desc")"
done < <(hyprctl monitors all | awk '
  /^Monitor /   { name = $2 }
  /description:/ { d = $0; sub(/^[ \t]*description: /, "", d); print name "\t" d }
')
