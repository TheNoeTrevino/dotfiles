-- ~/.config/hypr/lua/media.lua
-- 1:1 translation of the `bindel`/`bindl` binds from hyprland.conf lines
-- 420-444: laptop multimedia keys, keyboard backlight, playerctl, and the
-- lid switch. bindel = bind + "e" (repeat) + "l" (locked, works while
-- locked/off), so those binds need both repeating = true and locked = true.
-- bindl only carries the "l" (locked) flag, so those binds need only
-- locked = true.

-- Laptop multimedia keys for volume and LCD brightness
-- stylua: ignore start
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("~/.config/hypr/ddc-brightness.sh up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/ddc-brightness.sh down"), { locked = true, repeating = true })

-- Keyboard backlight control
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd([[sh -c 'echo $(($(cat /sys/class/leds/chromeos::kbd_backlight/brightness) + 10)) | tee /sys/class/leds/chromeos::kbd_backlight/brightness']]), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd([[sh -c 'echo $(($(cat /sys/class/leds/chromeos::kbd_backlight/brightness) - 10)) | tee /sys/class/leds/chromeos::kbd_backlight/brightness']]), { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Lid switch: layout is handled automatically by kanshi (it reacts to
-- monitor hotplug). On close, lid-closed.sh suspends only if no external
-- monitors are attached.
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("~/.config/hypr/lid-closed.sh"), { locked = true })
-- On open: force the internal panel back on. Opening the lid is NOT a DRM
-- hotplug (eDP-1 never disconnects), so kanshi never re-fires; if eDP-1 was
-- left DPMS-off (e.g. externals unplugged while closed), nothing else wakes it.
-- Called as a dispatcher directly rather than shelling out to
-- `hyprctl dispatch dpms on eDP-1`: under the Lua provider hyprctl parses its
-- argument as a Lua expression, so the old bare-word form is a syntax error.
--
-- hl.dsp.dpms takes a TABLE. The positional form hl.dsp.dpms("on", "eDP-1")
-- does not error -- it turns EVERY monitor OFF and ignores the name (verified
-- 2026-09-08). It made this bind blank the panel on every lid open.
hl.bind("switch:off:Lid Switch", hl.dsp.dpms({ action = "on", monitor = "eDP-1" }), { locked = true })

return true
