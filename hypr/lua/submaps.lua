-- ~/.config/hypr/lua/submaps.lua
-- 1:1 translation of the server-mode submap from hyprland.conf lines
-- 449-451.
--
-- Server-mode submap: entered by the server-mode script when the display is
-- off. Any keypress stops the service, which triggers cleanup (DPMS on,
-- suspend inhibitor released). Hyprland processes keybinds even with DPMS
-- off. The submap name "server-mode-exit" is load-bearing: ~/.local/bin/
-- server-mode dispatches into it by name, and server-mode.service's
-- teardown depends on it.
hl.define_submap("server-mode-exit", function()
	hl.bind("catchall", hl.dsp.exec_cmd("systemctl --user stop server-mode.service"))
end)

return true
