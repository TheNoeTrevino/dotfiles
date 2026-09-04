-- ~/.config/hypr/hyprland-lua-wip.lua
-- Staging entry for the .conf -> Lua migration. Promoted to hyprland.lua at
-- cutover. Modules are required in the same order the old hyprland.conf
-- declared them, so ordering-sensitive settings behave identically.
--
-- package.path is pre-seeded with this file's directory, so "lua.x" resolves
-- to hypr/lua/x.lua with no setup.
require("lua.env")
require("lua.look")
require("lua.input")
require("lua.autostart")
require("lua.binds")
