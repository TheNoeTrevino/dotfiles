-- ~/.config/hypr/lua/media.lua
-- 1:1 translation of the `bindel`/`bindl` binds from hyprland.conf lines
-- 420-444: laptop multimedia keys, keyboard backlight, playerctl, and the
-- lid switch. repeating = true matches the "e" (repeat) flag on bindel;
-- locked = true matches the "l" (works while locked/off) flag on bindl.

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"), { repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("~/.config/hypr/ddc-brightness.sh up"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/ddc-brightness.sh down"), { repeating = true })

-- Keyboard backlight control
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd([[sh -c 'echo $(($(cat /sys/class/leds/chromeos::kbd_backlight/brightness) + 10)) | tee /sys/class/leds/chromeos::kbd_backlight/brightness']]), { repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd([[sh -c 'echo $(($(cat /sys/class/leds/chromeos::kbd_backlight/brightness) - 10)) | tee /sys/class/leds/chromeos::kbd_backlight/brightness']]), { repeating = true })

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
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl dispatch dpms on eDP-1"), { locked = true })

return true
