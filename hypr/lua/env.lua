-- ~/.config/hypr/lua/env.lua
-- Environment variables. The old $variables (terminal/menu/notification/etc.)
-- became plain Lua locals; each consuming module inlines the literal string,
-- since modules are loaded independently and do not share scope.
--
-- Variables defined in hyprland.conf but not exported (modules inline them directly):
-- $terminal = ghostty -e herdr
-- $fileManager = dolphin
-- $menu = fuzzel
-- $notification = swaync-client -t -sw
-- $mainMod = SUPER

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct") -- for Qt apps
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

return true
