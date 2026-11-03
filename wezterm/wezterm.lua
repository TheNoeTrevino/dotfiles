-- These are the basic's for using wezterm.
-- Mux is the mutliplexes for windows etc inside of the terminal
-- Action is to perform actions on the terminal
local wezterm = require("wezterm")
local mux = wezterm.mux
local act = wezterm.action

-- These are vars to put things in later (i dont use em all yet)
local config = {}
local keys = {}
local mouse_bindings = {}
local launch_menu = {}

-- Windows-side zsh, installed into Git for Windows (MSYS2 build). "-l" makes it a
-- login shell so Git's /etc/profile sets up PATH, LANG, etc. before ~/.zshrc runs.
local zsh_exe = "C:\\Users\\noe.trevino\\AppData\\Local\\Programs\\Git\\usr\\bin\\zsh.exe"

-- WSL domain name is "WSL:" + the distro name exactly as `wsl -l -v` prints it (case matters).
local wsl_domain = "WSL:archlinux"

-- This is for newer wezterm vertions to use the config builder
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- Default config settings
-- These are the default config settins needed to use Wezterm
-- Just add this and return config and that's all the basics you need

-- Color scheme, Wezterm has 100s of them you can see here:
-- https://wezfurlong.org/wezterm/colorschemes/index.html
config.color_scheme = "Oceanic Next (Gogh)"
-- This is my chosen font, we will get into installing fonts on windows later
config.font = wezterm.font("JetBrainsMono Nerd Font Mono")
config.font_size = 11
-- makes my cursor blink
config.default_cursor_style = "BlinkingBar"
config.disable_default_key_bindings = true

-- What the *local* (Windows) domain runs when a tab is opened in it. Without this
-- WezTerm falls back to cmd.exe. The WSL domain below is unaffected by this.
config.default_prog = { "pwsh.exe", "-NoLogo" }

-- Launcher entries (CTRL+SHIFT+L). Domains (WSL, local) are listed there too.
launch_menu = {
	{
		label = "zsh (Windows / Git for Windows)",
		args = { zsh_exe, "-l" },
		domain = { DomainName = "local" },
	},
	{
		label = "PowerShell 7",
		args = { "pwsh.exe", "-NoLogo" },
		domain = { DomainName = "local" },
	},
}

-- Keys: defaults are disabled above, so everything used must be listed here.
keys = {
	{ key = "=", mods = "CTRL", action = act.IncreaseFontSize },
	{ key = "-", mods = "CTRL", action = act.DecreaseFontSize },
	{ key = "0", mods = "CTRL", action = act.ResetFontSize },
	-- this adds the ability to use ctrl+v to paste the system clipboard
	{ key = "V", mods = "CTRL", action = act.PasteFrom("Clipboard") },
	-- fuzzy launcher: pick WSL / Windows zsh / pwsh
	{ key = "L", mods = "CTRL|SHIFT", action = act.ShowLauncherArgs({ flags = "FUZZY|LAUNCH_MENU_ITEMS|DOMAINS" }) },
	-- open a Windows zsh tab directly
	{
		key = "Z",
		mods = "CTRL|SHIFT",
		action = act.SpawnCommandInNewTab({ args = { zsh_exe, "-l" }, domain = { DomainName = "local" } }),
	},
	-- workspaces: ALT+1 = WSL (arch), ALT+2 = Windows PowerShell 7. Each is created on first use.
	{
		key = "1",
		mods = "ALT",
		action = act.SwitchToWorkspace({ name = "wsl", spawn = { domain = { DomainName = wsl_domain } } }),
	},
	{
		key = "2",
		mods = "ALT",
		action = act.SwitchToWorkspace({
			name = "windows",
			spawn = { args = { "pwsh.exe", "-NoLogo" }, domain = { DomainName = "local" } },
		}),
	},
	-- fuzzy pick any workspace
	{ key = "S", mods = "CTRL|SHIFT", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
	-- new tab in the current pane's domain (WSL tab in wsl, Windows tab in windows)
	{ key = "T", mods = "CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },
}

-- There are mouse binding to mimc Windows Terminal and let you copy
-- To copy just highlight something and right click. Simple
mouse_bindings = {
	{
		event = { Down = { streak = 3, button = "Left" } },
		action = wezterm.action.SelectTextAtMouseCursor("SemanticZone"),
		mods = "NONE",
	},
	{
		event = { Down = { streak = 1, button = "Right" } },
		mods = "NONE",
		action = wezterm.action_callback(function(window, pane)
			local has_selection = window:get_selection_text_for_pane(pane) ~= ""
			if has_selection then
				window:perform_action(act.CopyTo("ClipboardAndPrimarySelection"), pane)
				window:perform_action(act.ClearSelection, pane)
			else
				window:perform_action(act({ PasteFrom = "Clipboard" }), pane)
			end
		end),
	},
}

-- NOTE: these must come AFTER the tables above are filled in. Previously
-- config.mouse_bindings / config.launch_menu were assigned while the locals were
-- still the empty placeholder tables, so the mouse bindings never took effect.
config.keys = keys
config.mouse_bindings = mouse_bindings
config.launch_menu = launch_menu

-- This is used to make my foreground (text, etc) brighter than my background
config.foreground_text_hsb = {
	hue = 1.0,
	saturation = 1.2,
	brightness = 1.5,
}

config.window_background_opacity = 0.85

-- remove the Windows title bar but keep the borders so the window can still be resized
config.window_decorations = "RESIZE"

-- You can also set a solid background color
config.colors = {
	background = "#000000", -- or any color you want
}

-- IMPORTANT: Sets WSL2 as the default when opening Wezterm.
-- (Installed distros right now: archlinux, docker-desktop — there is no "Ubuntu".)
-- To make Windows zsh the default instead:  config.default_domain = "local"
config.default_domain = wsl_domain
config.enable_kitty_graphics = true

-- WSL over ssh to localhost. The WSL domain above goes through ConPTY, which
-- drops kitty graphics; this one doesn't. WSL must already be running (sshd
-- lives inside it). Open it from the launcher (CTRL+SHIFT+L) as "wsl-ssh".
config.ssh_domains = {
	{
		name = "wsl-ssh",
		remote_address = "127.0.0.1:22",
		username = "noe.trevino",
		multiplexing = "None",
		ssh_option = { identityfile = wezterm.home_dir .. "/.ssh/wezterm_wsl" },
	},
}
config.default_workspace = "wsl"

-- show the current workspace name in the right side of the tab bar
wezterm.on("update-right-status", function(window, _)
	window:set_right_status(" " .. window:active_workspace() .. " ")
end)

return config
