-- ~/.config/hypr/lua/rules.lua
-- Window rules. Hyprlang on 0.56.2 could not express this: every matched
-- windowrule form was rejected ("windowrule = float, class:^(...)$" fails
-- with "invalid field float: missing a value", and `class` is not even
-- accepted as a rule field). This is the one capability the migration to
-- Lua adds over the old config.
--
-- satty sizes itself to the screenshot; tiling it into dwindle rescales the
-- canvas. Class confirmed empirically via `hyprctl clients` while satty was
-- open.
hl.window_rule({
	name = "float-satty",
	match = { class = "com.gabm.satty" },
	float = true,
})

return true
