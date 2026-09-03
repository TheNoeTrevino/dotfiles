#!/usr/bin/env bash
# fuzzel wallpaper picker for the waybar image icon.
#
# Flow:  pick a target monitor  ->  pick a wallpaper (with thumbnails).
# The choice is applied immediately via awww AND written back into
# ~/.config/hypr/wallpaper.conf so it persists across reloads and replugs.

set -u
CONF="$HOME/.config/hypr/wallpaper.conf"
APPLY="$HOME/.config/hypr/wallpaper.sh"
# shellcheck source=/dev/null
source "$CONF"

# --no-sort keeps step 1's "All monitors" entry pinned first and step 2 in glob
# (alphabetical) order; fuzzel sorts matches by default.
menu() { fuzzel --dmenu --no-sort "$@"; }

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
# Thumbnails use Rofi's extended dmenu protocol, which fuzzel understands:
#   <display text>\0icon\x1f<path>
# This is fed straight into the pipe rather than accumulated in a variable,
# because bash strings CANNOT contain NUL bytes — building it up in $entries
# the way the old wofi `img:PATH:text:NAME` format did would silently drop the
# separator and every line would render as plain text with no thumbnail.
pick="$(
  for f in "$WALLPAPER_DIR"/*; do
    [[ -f "$f" ]] || continue
    printf '%s\0icon\x1f%s\n' "$(basename "$f")" "$f"
  done | menu -p "Wallpaper for ${target%% (*} "
)"
[[ -n "$pick" ]] || exit 0
# Unlike wofi, fuzzel prints only the display text, so $pick is already the
# bare basename — no stripping needed.
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
