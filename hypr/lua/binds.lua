-- ~/.config/hypr/lua/binds.lua
-- 1:1 translation of the plain `bind =` binds from hyprland.conf lines
-- 320-412. $mainMod/$terminal/$menu/$fileManager/$notification are inlined
-- since modules do not share scope.
--
-- Excluded from this file (by design, not an oversight):
--   - `bindl`/`bindel` binds (media keys, lid switch, playerctl) -> Task 7.
--   - the `submap = server-mode-exit` block, including its
--     `bind = , catchall, exec, systemctl --user stop server-mode.service`
--     -> Task 8. That bind only fires while the submap is active; translating
--     it here as a top-level hl.bind would make it fire globally instead,
--     which is not a 1:1 behavior match.

-- Escape hatches first: if anything below is wrong, these are what get you a
-- terminal to run rollback.sh from.
hl.bind("SUPER + Return", hl.dsp.exec_cmd("ghostty -e herdr"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("ALT + Space", hl.dsp.exec_cmd("fuzzel")) -- Launcher / menu (see $menu at the top of the old file)
-- wlogout and hyprlock sit on Escape, not L: SUPER + L and SUPER + SHIFT + L
-- are focus-right and move-window-right.
hl.bind("SUPER + Escape", hl.dsp.exec_cmd("wlogout"))
hl.bind("SUPER + SHIFT + Escape", hl.dsp.exec_cmd("hyprlock")) -- Screen locker

-- Deliberately ALT, not SUPER, above: this chord kept its old modifier when
-- the rest of the config moved to SUPER. ALT is otherwise unused now, so
-- nothing clashes.

hl.bind("XF86AudioMedia", hl.dsp.exec_cmd("wtype -k Page_Up"))
hl.bind("Print", hl.dsp.exec_cmd("~/.config/hypr/screenshot-annotate.sh"))

-- Bare ghostty, no herdr. herdr refuses to start inside a herdr-managed pane
-- (experimental.allow_nested, off by default), so `herdr --remote geekom`
-- needs a terminal that is not already one. ghostty sets no default command,
-- so this lands in the login shell.
hl.bind("SUPER + SHIFT + Return", hl.dsp.exec_cmd("ghostty"))

hl.bind("SUPER + N", hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("dolphin"))
hl.bind("SUPER + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("hyprcap rec region -c -n -o ~/ScreenRecordings"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker --autocopy"))

-- Toggle waybar: pkill exits 1 when nothing matched, so || starts it instead
hl.bind("SUPER + W", hl.dsp.exec_cmd([[pkill -x waybar || waybar]]))

-- Clipboard history picker (cliphist via fuzzel).
-- --no-sort keeps cliphist's own most-recent-first ordering; fuzzel would
-- otherwise re-sort the list and bury the entry you just copied.
hl.bind("SUPER + V", hl.dsp.exec_cmd([[cliphist list | fuzzel --dmenu --no-sort --prompt "Clipboard " | cliphist decode | wl-copy]]))

-- Night light toggle (hyprsunset)
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("~/.config/hypr/sunset-toggle.sh"))

-- Move focus with mainMod + hjkl, and move/swap the active window with
-- mainMod + SHIFT + hjkl (swaps if a window exists there, otherwise moves it
-- to that workspace). Plain hjkl here -- not tmux's shifted jkl;.
local dirs = { h = "l", j = "d", k = "u", l = "r" }
for key, dir in pairs(dirs) do
	hl.bind("SUPER + " .. key, hl.dsp.focus{ direction = dir })
	hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move{ direction = dir })
end

-- Switch workspaces with mainMod + [0-9], and move the active window to a
-- workspace with mainMod + SHIFT + [0-9].
for i = 1, 10 do
	local key = (i == 10) and "0" or tostring(i)
	hl.bind("SUPER + " .. key, hl.dsp.focus{ workspace = i })
	hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move{ workspace = i })
end

-- Relative workspace stepping. workspace = "-1"/"+1" MUST be strings: an
-- integer HL.WorkspaceSelector means an absolute workspace id, and the
-- relative "+1"/"-1" grammar only exists in the string form.
hl.bind("SUPER + CONTROL + h", hl.dsp.focus{ workspace = "-1" })
hl.bind("SUPER + CONTROL + l", hl.dsp.focus{ workspace = "+1" })

-- Same moves from the Adv360 Nav layer, which puts arrows on the jkl; positions
local arrows = { left = "l", down = "d", up = "u", right = "r" }
for key, dir in pairs(arrows) do
	hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move{ direction = dir })
end

hl.bind("SUPER + X", hl.dsp.workspace.toggle_special("magic"))
hl.bind("SUPER + SHIFT + X", hl.dsp.window.move{ workspace = "special:magic" })

-- Region select -> satty annotation editor -> Enter copies + saves. Same
-- script on PrtSc. See screenshot-annotate.sh for why wl-copy has to do the
-- copying.
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("~/.config/hypr/screenshot-annotate.sh"))

return true
