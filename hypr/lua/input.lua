-- ~/.config/hypr/lua/input.lua
-- Input, touchpad, gesture, and per-device config. 1:1 translation of
-- hyprland.conf lines 266-312.

hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		-- No remap by default. caps:swapescape is applied PER-DEVICE to the built-in
		-- keyboard only (see the `device` block further down), never globally.
		-- Why: `hyprctl keyword` edits only Hyprland's in-memory config, so any
		-- reload -- and autoreload fires on every save of this file -- rebuilt it
		-- from here and silently reverted the kanshi hooks' runtime override, which
		-- turned Escape into Caps Lock at random. Empty here means a reload
		-- reinforces the rule instead of undoing it.
		kb_options = "",
		kb_rules = "",
		repeat_delay = 300,
		repeat_rate = 100,

		follow_mouse = 1,

		sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

		touchpad = {
			natural_scroll = true,
			scroll_factor = 0.2,
			clickfinger_behavior = true,
		},
	},
})

-- See https://wiki.hypr.land/Configuring/Gestures
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Keywords/#per-device-input-configs for more
hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

-- caps:swapescape belongs to the KEYBOARD, not to the monitor layout. Only the
-- built-in Framework keyboard gets the remap; external keyboards (Kinesis Adv360
-- Pro, which does its own remapping in firmware) are left alone regardless of
-- which kanshi profile is active. Because this lives in the config rather than
-- being pushed at runtime, it survives reloads, dock/undock, and USB re-plugs.
-- Names come from `hyprctl devices`.
hl.device({ name = "at-translated-set-2-keyboard", kb_options = "caps:swapescape" })

return true
