#!/usr/bin/env bash
# Hyprland keybind cheat sheet — rendered with wofi --dmenu (read-only list).
# Source of truth: ~/.config/hypr/hyprland.conf  (mainMod = SUPER)
# Bound in waybar via custom/keybinds.

binds=$(cat <<'EOF'
── Apps & Launchers ──────────────────────────────
SUPER + Return          Terminal (ghostty + herdr)
SUPER + E               File manager (dolphin)
ALT + Space             App launcher (wofi)
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

── Workspaces ────────────────────────────────────
SUPER + [1-0]           Switch to workspace 1-10
SUPER + Shift + [1-0]   Move window to workspace 1-10
SUPER + Ctrl + H        Previous workspace
SUPER + Ctrl + L        Next workspace
SUPER + S               Toggle special workspace (magic)
SUPER + Shift + S       Move window to special workspace

── Capture ───────────────────────────────────────
PrtSc                   Screenshot region (hyprshot)
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

echo "$binds" | wofi --dmenu \
  --prompt "Keybinds" \
  --insensitive \
  --width 720 \
  --height 720 \
  --cache-file /dev/null
