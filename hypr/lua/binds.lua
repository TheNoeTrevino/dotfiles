hl.bind("SUPER + Return", hl.dsp.exec_cmd("ghostty -e herdr"), { desc = "Open Terminal - Herdr" })
hl.bind("SUPER + SHIFT + Return", hl.dsp.exec_cmd("ghostty"), { desc = "Open Terminal" })

hl.bind("ALT + Space", hl.dsp.exec_cmd("fuzzel"), { desc = "Search Applications" })

hl.bind("SUPER + Q", hl.dsp.window.close(), { desc = "Close Window" })

hl.bind("SUPER + Escape", hl.dsp.exec_cmd("wlogout"), { desc = "Wlogout" })
hl.bind("SUPER + SHIFT + Escape", hl.dsp.exec_cmd("hyprlock"), { desc = "Hyprlock" })

hl.bind("XF86AudioMedia", hl.dsp.exec_cmd("wtype -k Page_Up"), { desc = "Page Up" })

hl.bind("Print", hl.dsp.exec_cmd("~/.config/hypr/screenshot-annotate.sh"), { desc = "Screenshot -> Annotate" })
hl.bind(
	"SUPER + SHIFT + R",
	hl.dsp.exec_cmd("hyprcap rec region -c -n -o ~/ScreenRecordings"),
	{ desc = "Record Screen" }
)

hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker --autocopy"), { desc = "Pick Color" })

hl.bind("SUPER + N", hl.dsp.exec_cmd("swaync-client -t -sw"), { desc = "Notification Panel" })
hl.bind("SUPER + E", hl.dsp.exec_cmd("dolphin"), { desc = "File Explorer" })

hl.bind("SUPER + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }), { desc = "Toggle float/tiled" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen(), { desc = "Fullscreen" })

hl.bind("SUPER + W", hl.dsp.exec_cmd([[pkill -x waybar || waybar]]), { desc = "Toggle Waybar" })

hl.bind(
	"SUPER + V",
	hl.dsp.exec_cmd([[cliphist list | fuzzel --dmenu --no-sort --prompt "Clipboard " | cliphist decode | wl-copy]]),
	{ desc = "Clipboard History" }
)

hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("~/.config/hypr/sunset-toggle.sh"), { desc = "Nightlight" })

hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("~/.config/hypr/screenshot-annotate.sh"), { desc = "Screenshot -> Annotate" })

-- Plain hjkl here, not tmux's shifted jkl;. SHIFT swaps with the window in that
-- direction if one is there, otherwise moves the active window to it.
local dirs = {
	h = { dir = "l", name = "Left" },
	j = { dir = "d", name = "Down" },
	k = { dir = "u", name = "Up" },
	l = { dir = "r", name = "Right" },
}
for key, d in pairs(dirs) do
	hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = d.dir }), { desc = "Focus " .. d.name })
	hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ direction = d.dir }), { desc = "Move Window " .. d.name })
end

for i = 1, 10 do
	local key = (i == 10) and "0" or tostring(i)
	hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = i }), { desc = "Switch to Workspace " .. i })
	hl.bind(
		"SUPER + SHIFT + " .. key,
		hl.dsp.window.move({ workspace = i }),
		{ desc = "Move Window to Workspace " .. i }
	)
end

-- workspace = "-1"/"+1" MUST be strings: an integer HL.WorkspaceSelector means an
-- absolute workspace id, so the relative grammar only exists in the string form.
hl.bind("SUPER + CONTROL + h", hl.dsp.focus({ workspace = "-1" }), { desc = "Previous Workspace" })
hl.bind("SUPER + CONTROL + l", hl.dsp.focus({ workspace = "+1" }), { desc = "Next Workspace" })

local arrows = {
	left = { dir = "l", name = "Left" },
	down = { dir = "d", name = "Down" },
	up = { dir = "u", name = "Up" },
	right = { dir = "r", name = "Right" },
}
for key, a in pairs(arrows) do
	hl.bind(
		"SUPER + SHIFT + " .. key,
		hl.dsp.window.move({ direction = a.dir }),
		{ desc = "Move Window " .. a.name .. " (Adv360 Nav layer)" }
	)
end

hl.bind("SUPER + X", hl.dsp.workspace.toggle_special("magic"), { desc = "Toggle Special Workspace (magic)" })
hl.bind(
	"SUPER + SHIFT + X",
	hl.dsp.window.move({ workspace = "special:magic" }),
	{ desc = "Move Window to Special Workspace" }
)

return true
