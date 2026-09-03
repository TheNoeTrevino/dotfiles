#!/usr/bin/env bash
# Hyprland keybind cheat sheet — rendered with wofi --dmenu (read-only list).
# Source of truth: ~/.config/hypr/hyprland.conf  (mainMod = ALT)
# Bound in waybar via custom/keybinds.

binds=$(cat <<'EOF'
── Apps & Launchers ──────────────────────────────
ALT + Return            Terminal (ghostty + herdr)
ALT + E                 File manager (dolphin)
ALT + Space             App launcher (wofi)
ALT + V                 Clipboard history (cliphist)
ALT + N                 Notification panel (swaync)
SUPER + W               Restart waybar

── Window ────────────────────────────────────────
ALT + Q                 Close active window
ALT + F                 Toggle fullscreen
ALT + Shift + Space     Toggle floating

── Focus & Move ──────────────────────────────────
ALT + J / ; / K / L     Focus left / right / down / up
ALT + Shift + J / ;     Move window left / right
ALT + Shift + K / L     Move window down / up

── Workspaces ────────────────────────────────────
ALT + [1-0]             Switch to workspace 1-10
ALT + Shift + [1-0]     Move window to workspace 1-10
ALT + Ctrl + J          Previous workspace
ALT + Ctrl + ;          Next workspace
ALT + S                 Toggle special workspace (magic)
ALT + Shift + S         Move window to special workspace

── Capture ───────────────────────────────────────
SUPER + Shift + S       Screenshot region (hyprshot)
PrtSc                   Screenshot region (hyprshot)
SUPER + Shift + R       Screen record region (hyprcap)
SUPER + Shift + C       Color picker (hyprpicker)

── Session ───────────────────────────────────────
SUPER + L               Logout menu (wlogout)
SUPER + Shift + L       Lock screen (hyprlock)
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
