#!/usr/bin/env bash
# Shell helpers for driving a Hyprland that is running the LUA config provider.
# Sourced by the kanshi profile hooks (on-laptop.sh, on-aw-only.sh, on-docked.sh).
#
# These stay shell because *kanshi* invokes them: kanshi is a separate daemon
# that matches monitor profiles by EDID serial and runs a command when one
# activates. It can only reach Hyprland's Lua state from the outside, through
# hyprctl. (The workspace assignment below could move into Lua proper via
# hl.on("monitor.added") -- see the note at the bottom of this file.)
#
# Two things changed when this machine moved off hyprland.conf:
#
#   * `hyprctl keyword` is gone entirely. It now answers
#         keyword can't work with non-legacy parsers. Use eval.
#     There is no hyprlang keyword table to write into any more, so runtime
#     config changes go through `hyprctl eval <lua>` instead.
#
#   * `hyprctl dispatch` parses its argument as a Lua *expression*, so every
#     bare-word dispatch is now a syntax error:
#         $ hyprctl dispatch dpms on eDP-1
#         error: [string "return hl.dispatch(dpms on eDP-1)"]:1: ')' expected
#
# The Lua forms below were verified against live state, not just "it parsed":
# ws_rule shows up in `hyprctl workspacerules`, and ws_move was checked by
# creating a headless output with `hyprctl output create headless` and watching
# `hyprctl workspaces` follow the move.

# ws_rule <workspace> <monitor> [default]
# Replaces: hyprctl keyword workspace "<ws>, monitor:<mon>[, default:true]"
#
# Unlike the old keyword form, hl.workspace_rule APPENDS rather than replaces:
# calling it twice for one workspace leaves two entries in
# `hyprctl workspacerules`. The newest wins -- verified by setting
# persistent=true then persistent=false on workspace 8 and watching it appear
# and then disappear -- so re-running a hook is correct, it just makes that
# listing repetitive until the next login. HL.WorkspaceRule exposes only
# set_enabled(), no remove(), so there is nothing to garbage-collect with.
ws_rule() {
	local ws=$1 mon=$2 extra=""
	[[ ${3:-} == default ]] && extra=", default = true"
	hyprctl eval "hl.workspace_rule({ workspace = \"$ws\", monitor = \"$mon\"$extra })" >/dev/null
}

# ws_move <workspace> <monitor>
# Replaces: hyprctl dispatch moveworkspacetomonitor <ws> <mon>
# Output is discarded because Hyprland only materialises a workspace once
# something is on it; moving one that does not exist yet warns "Workspace not
# found", which is expected and harmless -- ws_rule already decides where it
# will land when it is created.
ws_move() {
	hyprctl dispatch "hl.dsp.workspace.move({ workspace = $1, monitor = \"$2\" })" >/dev/null
}

# dpms_set <on|off> [monitor]
# Replaces: hyprctl dispatch dpms <state> [monitor]
# Not named `dpms` so it cannot be confused with the hyprctl subcommand.
dpms_set() {
	if [[ -n ${2:-} ]]; then
		hyprctl dispatch "hl.dsp.dpms(\"$1\", \"$2\")" >/dev/null
	else
		hyprctl dispatch "hl.dsp.dpms(\"$1\")" >/dev/null
	fi
}

# FUTURE: HL.Monitor exposes `serial` and `description`, and Hyprland emits
# monitor.added / monitor.removed / monitor.layout_changed events. The
# workspace-assignment half of the kanshi hooks could therefore be rewritten as
# hl.on("monitor.added", ...) in lua/monitors.lua, deleting these three scripts
# and this file. kanshi would still own mode/position/scale.
