#!/usr/bin/env bash
# ~/.config/hypr/lua/probe.sh -- resolve an unknown dispatcher form.
# Usage: ./probe.sh 'hl.bind("SUPER + x", hl.dsp.window.pin())'
#
# PASS only means the config parses. Dispatcher tables are largely
# unvalidated (e.g. hl.dsp.window.float{ zzz = 1 } parses fine), so a PASS
# proves nothing about semantic correctness -- cross-check the dispatcher
# form against /usr/share/hypr/hyprland.lua before trusting it.
T=$(mktemp --suffix=.lua)
printf -- '%s\n' "$1" > "$T"
r=$(Hyprland --config "$T" --verify-config 2>&1 | tail -2 | tr -d '\n')
case "$r" in
  *"config ok"*) echo "PASS  $1" ;;
  *) echo "FAIL  $1"; echo "      ${r#*lua:*: }" ;;
esac
rm -f "$T"
