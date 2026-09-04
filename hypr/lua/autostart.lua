-- ~/.config/hypr/lua/autostart.lua
-- 1:1 translation of hyprland.conf lines 39 (monitor fallback) and 76-110
-- (exec-once / exec autostarts).

-- Fallback for any display not covered by a kanshi profile. kanshi
-- (exec-once below) overrides this for known monitors at startup.
-- Real geometry lives in ~/.config/kanshi/config; kanshi reacts to hotplug
-- and applies the matching profile. Do NOT move kanshi profiles into Lua.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- kanshi watches for monitor hotplug and applies the matching profile,
-- replacing the old monitors.sh / hypr-monitors.service setup.
hl.exec_cmd("awww-daemon")
hl.exec_cmd("kanshi")
hl.exec_cmd("waybar")
hl.exec_cmd("swaync")
hl.exec_cmd("swayosd-server")
hl.exec_cmd("hyprsunset")

-- Clipboard history (cliphist) -- watch both text and images
hl.exec_cmd("wl-paste --type text --watch cliphist store")
hl.exec_cmd("wl-paste --type image --watch cliphist store")

-- hypridle is now a systemd user service (hypridle.service) bound to
-- graphical-session.target -- gives it proper SIGTERM ordering on logout.
-- Enable once with:  systemctl --user enable --now hypridle.service
-- (Not translated here -- it is not an exec-once.)

hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1") -- GUI auth prompts (sudo, mounts, etc.)

-- Hyprland 0.56.2 BUG: hl.exec_cmd("cmd", { <any rules table> }) SEGFAULTS
-- Hyprland during config parse (exit 139), and so does the hyprlang-style
-- bracket prefix hl.exec_cmd("[workspace N silent] cmd") passed directly to
-- exec-once. Verified live; do not "simplify" this back into either form.
-- The same [workspace N silent] bracket syntax works fine at RUNTIME, so we
-- defer it to `hyprctl dispatch exec` instead of the config-time exec-once.
-- The retry loop covers the window at login where the Hyprland IPC socket
-- isn't up yet; it exits as soon as the dispatch succeeds.
hl.exec_cmd([[sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do hyprctl dispatch exec "[workspace 1 silent] ghostty -e herdr" >/dev/null 2>&1 && exit 0; sleep 0.5; done']])
hl.exec_cmd([[sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do hyprctl dispatch exec "[workspace 2 silent] zen-browser" >/dev/null 2>&1 && exit 0; sleep 0.5; done']])

-- GTK3 theming is declared statically in ~/.config/gtk-3.0/settings.ini
-- (gtk-application-prefer-dark-theme=1); gtk-3.0/ is in .gitignore so that
-- file is NOT tracked by this repo. color-scheme below is still worth
-- setting -- it is the GTK4/libadwaita key and has no effect on GTK3.
hl.exec_cmd('gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"') -- for GTK4 apps

return true
