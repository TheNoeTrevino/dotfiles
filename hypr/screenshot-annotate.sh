#!/usr/bin/env bash
# Region screenshot -> satty annotation editor -> clipboard + ~/Screenshots.
# Bound to PrtSc and SUPER+SHIFT+S in lua/binds.lua.
#
# Enter  in satty: copy annotated PNG to clipboard, save a timestamped file, quit.
# Escape in satty: discard, write nothing.
set -euo pipefail

# Both keys run this; a double-press would otherwise stack two frozen overlays.
# The guard covers only freeze+select -- see the release below.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/screenshot-annotate.lock"
flock -n 9 || exit 0

# Freeze the screen so video, hover states and dropdowns hold still while
# selecting. hyprpicker -z paints a still copy of every output; -r keeps it
# quiet on stdout.
# 9>&- so it cannot inherit the lock fd: a child that outlives its kill would
# otherwise keep the guard held and wedge the keybind.
hyprpicker -r -z 9>&- >/dev/null 2>&1 &
picker=$!
unfreeze() { kill "$picker" 2>/dev/null || true; }
trap unfreeze EXIT
sleep 0.2 # let the freeze overlay map before slurp draws on top of it

geom=$(slurp -b '#ffffff20' -c '#00000040') || exit 0 # Esc during select = cancel
unfreeze
trap - EXIT # drop the freeze before satty opens, or it draws over the editor

# Release the guard NOW, while nothing long-lived is running. Children inherit
# open fds, and --copy-command forks a wl-copy daemon that outlives satty to keep
# serving the clipboard; if it inherited fd 9 it would hold this lock for as long
# as the clipboard content lives, silently wedging the keybind for good.
exec 9>&-

mkdir -p ~/Screenshots

# satty is floated by the `float-satty` window rule in lua/rules.lua, so that
# dwindle does not squash the canvas. Under the old hyprlang config that was
# impossible (no matched window rules on 0.56) and this script had to poll
# `hyprctl clients` and dispatch setfloating by hand; the Lua config expresses
# it declaratively, so satty can simply run in the foreground here.
#
# Piped over stdin rather than through a temp file so only the *annotated*
# image ever reaches the clipboard. --copy-command is load-bearing: satty's own
# GTK clipboard offer dies with the process, so on Wayland the paste comes up
# empty unless wl-copy takes ownership and keeps serving it.
#
# `|| true` because Escape / discard exits non-zero; that is not an error.
grim -g "$geom" - | satty --filename - \
	--output-filename "$HOME/Screenshots/%Y-%m-%d_%H-%M-%S.png" \
	--copy-command wl-copy \
	--actions-on-enter save-to-clipboard,save-to-file,exit \
	--actions-on-escape exit \
	--initial-tool arrow || true
