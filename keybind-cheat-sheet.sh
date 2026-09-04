#!/usr/bin/env bash
# Hyprland keybind cheat sheet — rendered with fuzzel --dmenu (read-only list).
# Source of truth: ~/.config/hypr/hyprland.conf  (mainMod = SUPER)
# Bound in waybar via custom/keybinds.

binds=$(cat <<'EOF'
── Apps & Launchers ──────────────────────────────
SUPER + Return          Terminal (ghostty + herdr)
SUPER + SHIFT + Return  Plain terminal, no herdr (for herdr --remote)
SUPER + E               File manager (dolphin)
ALT + Space             App launcher (fuzzel)
SUPER + V               Clipboard history (cliphist)
SUPER + N               Notification panel (swaync)
SUPER + W               Restart waybar

── Window ────────────────────────────────────────
SUPER + Q               Close active window
SUPER + F               Toggle fullscreen
SUPER + Shift + Space   Toggle floating

── Focus & Move ──────────────────────────────────
SUPER + H/J/K/L         Focus left / down / up / right
SUPER + Shift + H/J/K/L Move window left / down / up / right
SUPER + Shift + Arrows  Move window left / down / up / right

── Workspaces ────────────────────────────────────
SUPER + [1-0]           Switch to workspace 1-10
SUPER + Shift + [1-0]   Move window to workspace 1-10
SUPER + Ctrl + H        Previous workspace
SUPER + Ctrl + L        Next workspace
SUPER + X               Toggle special workspace (magic)
SUPER + Shift + X       Move window to special workspace

── Capture ───────────────────────────────────────
PrtSc                   Screenshot region -> annotate (satty)
SUPER + Shift + S       Screenshot region -> annotate (satty)
SUPER + Shift + R       Screen record region (hyprcap)
SUPER + Shift + C       Color picker (hyprpicker)

── Session ───────────────────────────────────────
SUPER + Esc             Logout menu (wlogout)
SUPER + Shift + Esc     Lock screen (hyprlock)
SUPER + Shift + N       Night light toggle (hyprsunset)

── Media & Hardware (special keys) ───────────────
Vol Up / Down / Mute    Volume + OSD (swayosd)
Mic Mute                Toggle mic mute
Brightness Up / Down    Brightness (laptop + external monitors via DDC)
Kbd Bright Up / Down    Keyboard backlight
Media Next/Play/Prev    playerctl
EOF
)

# CAREFUL: fuzzel's --width is in CHARACTERS and --lines counts rows, whereas
# wofi's --width/--height were pixels. The old 720/720 would mean a 720-column
# window here. Longest line above is 71 chars, so 78 leaves a little slack.
#
# --no-sort is REQUIRED: this list is hand-ordered into sections, and fuzzel
# sorts matches by default, which would scatter the "── Section ──" headers.
# --cache=/dev/null likewise stops most-recently-used from reordering it.
echo "$binds" | fuzzel --dmenu \
  --no-sort \
  --cache=/dev/null \
  --prompt "Keybinds " \
  --width 78 \
  --lines 30
