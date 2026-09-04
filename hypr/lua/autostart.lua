-- ~/.config/hypr/lua/autostart.lua
-- Monitor fallback + session autostart.

-- Fallback for any display not covered by a kanshi profile. kanshi (started
-- below) overrides this for known monitors at startup.
-- Real geometry lives in ~/.config/kanshi/config; kanshi reacts to hotplug
-- and applies the matching profile. Do NOT move kanshi profiles into Lua.
--
-- NOTE: scale = 1 here is a deliberately dumb fallback, and it is what you get
-- if kanshi ever fails to start -- eDP-1 is 2880x1920, so the desktop renders
-- tiny and the GPU pushes 4x the pixels. If everything is suddenly minuscule
-- and the cursor feels heavy, check `pgrep -x kanshi` first.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- hl.on("hyprland.start", ...) is the Lua equivalent of hyprlang's `exec-once`,
-- and the idiom the shipped /usr/share/hypr/hyprland.lua demonstrates.
--
-- The distinction matters. A bare `hl.exec_cmd` at file scope runs during
-- config *parse*, which is far too early: in the startup log the config
-- executes at lines 16-30 while the Aquamarine backend is only created at line
-- 43 and the seat opens at 46. Wayland clients launched there cannot connect
-- and exit immediately -- on the first Lua login kanshi, awww-daemon,
-- swayosd-server and hyprsunset each got a PID and died, and with kanshi gone
-- no monitor profile was applied, so eDP-1 fell back to the scale 1 above.
--
-- Measured in a nested instance: a child spawned at parse time gets exit 4
-- from `hyprctl monitors`, one spawned from this handler gets exit 0. So this
-- event fires only once IPC is answering and outputs exist -- exactly the
-- readiness condition autostart needs.
hl.on("hyprland.start", function()
	-- kanshi first so that everything which draws comes up against the final
	-- geometry. These are async spawns, so it is a hint, not a guarantee.
	hl.exec_cmd("kanshi")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("waybar")
	hl.exec_cmd("swaync")
	hl.exec_cmd("swayosd-server")
	hl.exec_cmd("hyprsunset")

	-- Clipboard history (cliphist) -- watch both text and images
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")

	-- hypridle is a systemd user service (hypridle.service) bound to
	-- graphical-session.target -- proper SIGTERM ordering on logout.
	-- Enable once with:  systemctl --user enable --now hypridle.service

	hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1") -- GUI auth prompts (sudo, mounts, etc.)

	-- The rules table is the Lua form of hyprlang's `[workspace 1 silent]`
	-- prefix. Passing it to a parse-time hl.exec_cmd segfaults Hyprland 0.56.2
	-- (exit 139); from inside this handler it is fine, verified in a nested
	-- instance.
	hl.exec_cmd("discord", { workspace = "1 silent" })
	hl.exec_cmd("ghostty -e herdr", { workspace = "2 silent" })
	hl.exec_cmd("zen-browser", { workspace = "3 silent" })
	hl.dispatch(hl.dsp.workspace("2"))
end)

-- GTK3 theming is declared statically in ~/.config/gtk-3.0/settings.ini
-- (gtk-application-prefer-dark-theme=1); gtk-3.0/ is in .gitignore so that
-- file is NOT tracked by this repo. color-scheme below is still worth
-- setting -- it is the GTK4/libadwaita key and has no effect on GTK3.
-- Left at file scope rather than in the handler above because it needs no
-- compositor, and this mirrors the old `exec` (not `exec-once`) line it
-- replaces: both re-run on every config reload.
hl.exec_cmd('gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"') -- for GTK4 apps

return true
