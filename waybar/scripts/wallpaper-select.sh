#!/usr/bin/env bash
# Wofi wallpaper picker for the waybar image icon (replaces a dead rofi script;
# rofi is not installed on this machine).
#
# Flow:  pick a target monitor  ->  pick a wallpaper (with thumbnails).
# The choice is applied immediately via awww AND written back into
# ~/.config/hypr/wallpaper.conf so it persists across reloads and replugs.

set -u
CONF="$HOME/.config/hypr/wallpaper.conf"
APPLY="$HOME/.config/hypr/wallpaper.sh"
# shellcheck source=/dev/null
source "$CONF"

menu() { wofi --dmenu --allow-images -i "$@"; }

# Friendly role label for a monitor description (by serial), else its connector.
label_for() {
  local desc="$1" name="$2"
  case "$desc" in
    *T3LMQS142415*) echo "Left · ASUS portrait" ;;
    *CQF2D34*)      echo "Main · Dell 4K" ;;
    *V5XT8124*)     echo "Right · Lenovo" ;;
    *eDP-1*|*)      [[ "$name" == eDP-1 ]] && echo "Laptop" || echo "$name" ;;
  esac
}

# --- Step 1: choose a monitor -------------------------------------------------
declare -A NAME_OF DESC_OF
labels=()
while IFS=$'\t' read -r name desc; do
  [[ -n "$name" ]] || continue
  lbl="$(label_for "$desc" "$name")  ($name)"
  NAME_OF["$lbl"]="$name"; DESC_OF["$lbl"]="$desc"
  labels+=("$lbl")
done < <(hyprctl monitors all | awk '
  /^Monitor /   { name = $2 }
  /description:/ { d = $0; sub(/^[ \t]*description: /, "", d); print name "\t" d }')

target="$(printf 'All monitors (re-apply saved)\n%s\n' "$(printf '%s\n' "${labels[@]}")" \
          | menu -p 'Set wallpaper on…')"
[[ -n "$target" ]] || exit 0

if [[ "$target" == All* ]]; then
  exec "$APPLY"
fi

out="${NAME_OF[$target]:-}"; desc="${DESC_OF[$target]:-}"
[[ -n "$out" ]] || exit 0

# --- Step 2: choose a wallpaper (thumbnails) ----------------------------------
entries=""
for f in "$WALLPAPER_DIR"/*; do
  [[ -f "$f" ]] || continue
  entries+="img:$f:text:$(basename "$f")"$'\n'
done
pick="$(printf '%s' "$entries" | menu -p "Wallpaper for ${target%% (*}")"
[[ -n "$pick" ]] || exit 0
# wofi --allow-images echoes the whole `img:PATH:text:NAME` line, not just NAME.
# Strip up to the last `:text:` to recover the basename (no-op for plain text).
pick="${pick##*:text:}"
file="$WALLPAPER_DIR/$pick"
[[ -f "$file" ]] || { notify-send "Wallpaper" "Not found: $pick" 2>/dev/null; exit 1; }

# --- Apply now ----------------------------------------------------------------
awww img -o "$out" "$file" --resize crop --fill-color 000000 \
  --transition-type fade --transition-duration 0.6 >/dev/null 2>&1

# --- Persist into wallpaper.conf ----------------------------------------------
# Store a bare filename (it lives under WALLPAPER_DIR); match the monitor's
# serial to rewrite the right array entry, else update WP_MAIN (laptop/unmapped).
val="$pick"
for serial in "${!WP_BY_SERIAL[@]}"; do
  if [[ "$desc" == *"$serial"* ]]; then
    sed -i -E "s|(\[$serial\]=)\"[^\"]*\"|\1\"$val\"|" "$CONF"
    exit 0
  fi
done
sed -i -E "s|^(WP_MAIN=)\"[^\"]*\"|\1\"$val\"|" "$CONF"
