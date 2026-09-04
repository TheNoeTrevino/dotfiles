# Hyprland `.conf` → Lua Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate `~/.config/hypr/hyprland.conf` (446 lines of hyprlang) to a modular Lua config with identical behavior, verified at every step by `Hyprland --verify-config`.

**Architecture:** A thin `hyprland.lua` entry point that `require`s focused modules under `hypr/lua/`. The whole tree is built under a staging filename (`hyprland-lua-wip.lua`) that Hyprland will not auto-load, validated offline, and promoted to `hyprland.lua` at four live milestones. Rollback at any point is a single `mv`.

**Tech Stack:** Hyprland 0.56.2, Lua 5.5 (full stdlib), `hl` API (stubs at `/usr/share/hypr/stubs/hl.meta.lua`, worked example at `/usr/share/hypr/hyprland.lua`).

**Spec:** This plan is self-contained; the design decisions it implements are recorded in "Design Decisions" below.

---

## Design Decisions

Settled before planning:

1. **Modular layout** via `require`, not a single file — a broken step is isolated and diffs stay readable.
2. **1:1 translation first.** Phase 1 (Tasks 1–8) reproduces today's behavior exactly, so any breakage is a translation bug and nothing else. Phase 2 (Task 9) adds the Lua-only satty float rule. Phase 3 (event-driven monitor hooks) is explicitly out of scope.
3. **Milestone cutovers.** `--verify-config` gates every chunk at zero risk; live cutover + `hyprctl reload` happens at 4 checkpoints only.

---

## Global Constraints

Copy these exactly; every task's requirements implicitly include this section.

- **Hyprland version:** 0.56.2. hyprlang is deprecated as of 0.55; matched window rules exist only in Lua.
- **NEVER create `~/.config/hypr/hyprland.lua` before a deliberate cutover step.** Hyprland auto-selects `hyprland.lua` over `hyprland.conf` purely by filename. Creating it early hijacks the next login/reload. Verified empirically.
- **Staging entry filename:** `~/.config/hypr/hyprland-lua-wip.lua`. Detection is by `.lua` **extension**, not filename, so this file verifies identically to the final one while remaining inert.
- **Module path:** `package.path` is pre-seeded with the entry file's own directory. From an entry in `hypr/`, `require("lua.binds")` resolves to `hypr/lua/binds.lua` with **no** `package.path` setup. Do not add any.
- **THE VALIDATION COMMAND** (the loop condition for the whole migration):
  ```bash
  Hyprland --config ~/.config/hypr/hyprland-lua-wip.lua --verify-config 2>&1 | tail -3
  ```
  Success is the literal line `config ok`. A broken submodule fails this with its exact file and line number, so validation covers the entire `require` tree.
- **`--verify-config` runs `exec` lines** (not `exec-once`). The only `exec` here is an idempotent `gsettings` call, so this is harmless — but never add a non-idempotent `exec`.
- **`hl.bind` key strings use `+`, not commas.** `"SUPER + Q"` is correct; `"SUPER, Q"` fails with *"Unknown keysym… did you forget a +?"*.
- **Do not commit a broken tree.** Every task ends with `config ok` before its commit.
- **Never delete `hyprland.conf`** during Phase 1. It is the rollback target.

---

## Verified API Reference

Every line below was confirmed with `--verify-config` on this machine. Use it verbatim; do not guess.

| hyprlang | Lua |
|---|---|
| `bind = $mainMod, Q, killactive,` | `hl.bind("SUPER + Q", hl.dsp.window.kill)` |
| `bind = $mainMod, F, fullscreen` | `hl.bind("SUPER + F", hl.dsp.window.fullscreen())` |
| `bind = $mainMod, return, exec, ghostty -e herdr` | `hl.bind("SUPER + Return", hl.dsp.exec_cmd("ghostty -e herdr"))` |
| `bind = $mainMod, 1, workspace, 1` | `hl.bind("SUPER + 1", hl.dsp.focus{ workspace = 1 })` |
| `bind = $mainMod, h, movefocus, l` | `hl.bind("SUPER + h", hl.dsp.focus{ direction = "l" })` |
| `bindel = ,XF86AudioRaiseVolume, exec, CMD` | `hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("CMD"), { repeating = true })` |
| `bindl = , XF86AudioNext, exec, CMD` | `hl.bind("XF86AudioNext", hl.dsp.exec_cmd("CMD"), { locked = true })` |
| `general { gaps_in = 5 }` | `hl.config({ general = { gaps_in = 5 } })` |
| `device { name = X \n kb_options = Y }` | `hl.device({ name = "X", kb_options = "Y" })` |
| `monitor = , preferred, auto, 1` | `hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })` |
| `exec-once = waybar` | `hl.exec_cmd("waybar")` |
| `exec-once = [workspace 1 silent] CMD` | `hl.exec_cmd("CMD", { workspace = "1 silent" })` |
| `windowrule = float, class:^(X)$` *(impossible in hyprlang)* | `hl.window_rule({ match = { class = "X" }, float = true })` |

**Key facts:**
- Dispatchers take **table arguments**: `hl.dsp.focus{ workspace = 1 }`. Positional args (`hl.dsp.focus("l")`) fail with *"dispatcher must be a dispatcher"*.
- `hl.dsp.window.kill` is passed **without** parentheses (it is already a dispatcher); `hl.dsp.window.fullscreen()` is **called**. When unsure, probe both.
- `hl.dsp.workspace` is a *namespace* (`change_id`, `move`, `rename`, `swap_monitors`, `toggle_special`), not callable.
- `HL.BindOptions` fields: `repeating`, `locked`, `release`, `non_consuming`, `transparent`, `ignore_mods`, `dont_inhibit`, `long_press`, `submap_universal`, `click`, `drag`, `description`, `device`.
- `print()` works and appears in verify output prefixed `[Lua]` — the debugging tool for this migration.

### Dispatcher probe harness

Any dispatcher not in the table above must be resolved empirically, never guessed. Use this:

```bash
#!/usr/bin/env bash
# ~/.config/hypr/lua/probe.sh -- resolve an unknown dispatcher form.
# Usage: ./probe.sh 'hl.bind("SUPER + x", hl.dsp.window.pin())'
T=$(mktemp --suffix=.lua)
printf -- '%s\n' "$1" > "$T"
r=$(Hyprland --config "$T" --verify-config 2>&1 | tail -2 | tr -d '\n')
case "$r" in
  *"config ok"*) echo "PASS  $1" ;;
  *) echo "FAIL  $1"; echo "      ${r#*lua:*: }" ;;
esac
rm -f "$T"
```

---

## File Structure

```
hypr/
  hyprland.conf              # UNTOUCHED through Phase 1 -- the rollback target
  hyprland-lua-wip.lua       # staging entry; promoted to hyprland.lua at cutover
  lua/
    probe.sh                 # dispatcher probe harness (Task 1)
    env.lua                  # env vars + shared command strings
    look.lua                 # general, decoration, animations, dwindle, master, misc
    input.lua                # input, touchpad, gesture, 2x device
    autostart.lua            # 11 exec-once + 1 exec
    binds.lua                # 54 plain binds
    media.lua                # 8 bindel + 6 bindl (incl. lid switch)
    submaps.lua              # server-mode-exit + catchall
    rules.lua                # window rules (Phase 2)
  rollback.sh                # one-command return to hyprland.conf (Task 1)
```

Each module is a side-effecting script (it calls `hl.*` at load) and ends with `return true`, matching the shipped `/usr/share/hypr/hyprland.lua` style.

---

## Rollback Procedure

Applies to every milestone. Print it before the first cutover and keep it visible.

```bash
# From a working session:
mv ~/.config/hypr/hyprland.lua ~/.config/hypr/hyprland-lua-wip.lua && hyprctl reload

# If keybinds are dead and no terminal can be opened:
#   Ctrl+Alt+F2  -> log in on the TTY -> run the mv above
#   -> Ctrl+Alt+F1 to return, then `hyprctl reload` from any terminal
```

Because Hyprland selects the config by filename, removing `hyprland.lua` restores `hyprland.conf` with zero further changes.

---

## Task 1: Safety net and skeleton

**Files:**
- Create: `hypr/lua/probe.sh`
- Create: `hypr/rollback.sh`
- Create: `hypr/hyprland-lua-wip.lua`

**Interfaces:**
- Produces: the staging entry point `hyprland-lua-wip.lua`, which every later task adds one `require` line to; `rollback.sh`, referenced by every cutover step.

- [ ] **Step 1: Confirm the current config is the clean baseline**

```bash
cd ~/.config && git status --porcelain hypr/
Hyprland --config ~/.config/hypr/hyprland.conf --verify-config 2>&1 | tail -2
```
Expected: `config ok`. Commit or stash anything unrelated before continuing.

- [ ] **Step 2: Write the rollback script**

```bash
cat > ~/.config/hypr/rollback.sh <<'EOF'
#!/usr/bin/env bash
# Return to hyprland.conf. Hyprland picks hyprland.lua over hyprland.conf purely
# by filename, so moving it aside is a complete rollback.
set -euo pipefail
cd ~/.config/hypr
if [ -e hyprland.lua ]; then
	mv hyprland.lua hyprland-lua-wip.lua
	echo "rolled back to hyprland.conf"
else
	echo "hyprland.lua not present; already on hyprland.conf"
fi
hyprctl reload
EOF
chmod +x ~/.config/hypr/rollback.sh
```

- [ ] **Step 3: Write the dispatcher probe harness**

Create `hypr/lua/probe.sh` with the exact content from "Dispatcher probe harness" above, then `chmod +x ~/.config/hypr/lua/probe.sh`.

- [ ] **Step 4: Write the staging entry point**

```lua
-- ~/.config/hypr/hyprland-lua-wip.lua
-- Staging entry for the .conf -> Lua migration. Promoted to hyprland.lua at
-- cutover. Modules are required in the same order the old hyprland.conf
-- declared them, so ordering-sensitive settings behave identically.
--
-- package.path is pre-seeded with this file's directory, so "lua.x" resolves
-- to hypr/lua/x.lua with no setup.
require("lua.env")
```

- [ ] **Step 5: Create the module dir and a stub env module so the require resolves**

```lua
-- ~/.config/hypr/lua/env.lua
return true
```

- [ ] **Step 6: Validate**

Run: `Hyprland --config ~/.config/hypr/hyprland-lua-wip.lua --verify-config 2>&1 | tail -3`
Expected: `config ok`

- [ ] **Step 7: Prove the rollback path is real (must NOT hijack)**

```bash
ls ~/.config/hypr/hyprland.lua 2>&1   # expected: No such file or directory
hyprctl reload && hyprctl configerrors  # expected: empty; still on .conf
```

- [ ] **Step 8: Commit**

```bash
cd ~/.config
git add hypr/hyprland-lua-wip.lua hypr/lua/env.lua hypr/lua/probe.sh hypr/rollback.sh docs/superpowers/plans/
git commit -m "hypr: scaffold lua migration staging tree and rollback"
```

---

## Task 2: Environment variables and shared commands

**Files:**
- Modify: `hypr/lua/env.lua`
- Source: `hyprland.conf` lines 40–66 (`$` variables) and the `env =` lines (3 total, incl. line 112 `QT_QPA_PLATFORMTHEME`)

**Interfaces:**
- Produces: module-level Lua locals replacing the five `$variables`. Later tasks reference the **literal command strings**, not the locals, because each module is loaded independently — do not attempt to share locals across files.

- [ ] **Step 1: Read the source lines**

```bash
grep -nE '^\s*\$[a-zA-Z]|^\s*env\s*=' ~/.config/hypr/hyprland.conf
```

- [ ] **Step 2: Write the module**

```lua
-- ~/.config/hypr/lua/env.lua
-- Environment variables. The old $variables (terminal/menu/notification/etc.)
-- became plain Lua locals; each consuming module inlines the literal string,
-- since modules are loaded independently and do not share scope.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct") -- for Qt apps
return true
```

Add the remaining two `env =` lines from Step 1 in the same form, preserving their comments.

- [ ] **Step 3: Validate**

Run: `Hyprland --config ~/.config/hypr/hyprland-lua-wip.lua --verify-config 2>&1 | tail -3`
Expected: `config ok`

If `hl.env` rejects two positional args, probe the table form:
`~/.config/hypr/lua/probe.sh 'hl.env{ name = "QT_QPA_PLATFORMTHEME", value = "qt6ct" }'`

- [ ] **Step 4: Commit**

```bash
cd ~/.config && git add hypr/lua/env.lua && git commit -m "hypr(lua): migrate env vars"
```

---

## Task 3: Look and feel

**Files:**
- Create: `hypr/lua/look.lua`
- Modify: `hypr/hyprland-lua-wip.lua` (add `require("lua.look")`)
- Source: `hyprland.conf` lines 148–256 — `general`, `decoration` (+ nested `shadow`, `blur`), `animations` (25 bezier/animation entries), `dwindle`, `master`, `misc`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Read the source block**

```bash
sed -n '148,256p' ~/.config/hypr/hyprland.conf
```

- [ ] **Step 2: Write the config sections**

Nested hyprlang blocks become nested Lua tables. Note `animations { enabled = no }` — this config has animations **disabled**, so the 25 bezier/animation lines are inert today; translate them anyway to keep behavior identical if re-enabled.

```lua
-- ~/.config/hypr/lua/look.lua
hl.config({
	general = {
		gaps_in = 5, -- replace all values with the real ones from lines 148-165
		border_size = 1,
	},
	decoration = {
		shadow = { enabled = false },
		blur = { enabled = false },
	},
	animations = { enabled = false }, -- was `enabled = no`
	dwindle = { preserve_split = true },
	misc = {},
})
return true
```

- [ ] **Step 3: Translate the bezier curves and animations**

`bezier = NAME, a, b, c, d` becomes `hl.curve(...)`; `animation = ...` becomes `hl.animation({ leaf = ..., ... })`. Follow the worked example:

```bash
sed -n '160,161p' /usr/share/hypr/hyprland.lua   # real hl.animation calls
~/.config/hypr/lua/probe.sh 'hl.curve("easeOutQuint", 0.23, 1, 0.32, 1)'
```
Resolve the exact `hl.curve` signature with the probe before writing all 25.

- [ ] **Step 4: Wire it into the entry point**

Add `require("lua.look")` to `hyprland-lua-wip.lua` immediately after `require("lua.env")`.

- [ ] **Step 5: Validate**

Run: `Hyprland --config ~/.config/hypr/hyprland-lua-wip.lua --verify-config 2>&1 | tail -3`
Expected: `config ok`

- [ ] **Step 6: Commit**

```bash
cd ~/.config && git add hypr/lua/look.lua hypr/hyprland-lua-wip.lua && git commit -m "hypr(lua): migrate look and feel"
```

---

## Task 4: Input, touchpad, gesture, and per-device config

**Files:**
- Create: `hypr/lua/input.lua`
- Modify: `hypr/hyprland-lua-wip.lua`
- Source: `hyprland.conf` lines 266–312

**Interfaces:**
- Produces: the per-device `caps:swapescape` rule that the kanshi `on-*.sh` hooks depend on **not** fighting.

> **Behavioral landmine — do not "simplify" this.** `input.kb_options` is deliberately **empty**, and `caps:swapescape` is applied per-device to the built-in keyboard only. A previous global setting caused reloads to silently revert the kanshi hooks' runtime override and turn Escape into Caps Lock at random. Preserve this split exactly, comments included.

- [ ] **Step 1: Read the source block**

```bash
sed -n '266,312p' ~/.config/hypr/hyprland.conf
```

- [ ] **Step 2: Write the module**

```lua
-- ~/.config/hypr/lua/input.lua
hl.config({
	input = {
		kb_layout = "us",
		-- Deliberately empty: caps:swapescape is applied PER-DEVICE below, never
		-- globally. A global value made every reload revert the kanshi hooks'
		-- runtime override, turning Escape into Caps Lock at random.
		kb_options = "",
		repeat_delay = 300,
		repeat_rate = 100,
		follow_mouse = 1,
		sensitivity = 0,
		touchpad = {
			natural_scroll = true,
			scroll_factor = 0.2,
			clickfinger_behavior = true,
		},
	},
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

-- caps:swapescape belongs to the KEYBOARD, not the monitor layout. Only the
-- built-in Framework keyboard gets the remap; external keyboards (Kinesis
-- Adv360 Pro, which remaps in firmware) are left alone regardless of which
-- kanshi profile is active. Names come from `hyprctl devices`.
hl.device({ name = "at-translated-set-2-keyboard", kb_options = "caps:swapescape" })
return true
```

- [ ] **Step 3: Resolve the gesture signature**

`hl.gesture` takes an `HL.GestureSpec`; the field names above are a guess. Confirm before validating:

```bash
awk '/---@class HL.GestureSpec/{f=1} f&&/^---@field/{print} f&&/^local/{exit}' /usr/share/hypr/stubs/hl.meta.lua
```
Use the field names it prints.

- [ ] **Step 4: Wire in and validate**

Add `require("lua.input")` to the entry point.
Run: `Hyprland --config ~/.config/hypr/hyprland-lua-wip.lua --verify-config 2>&1 | tail -3`
Expected: `config ok`

- [ ] **Step 5: Commit**

```bash
cd ~/.config && git add hypr/lua/input.lua hypr/hyprland-lua-wip.lua && git commit -m "hypr(lua): migrate input, gesture and per-device config"
```

---

## Task 5: Autostart and monitor fallback

**Files:**
- Create: `hypr/lua/autostart.lua`
- Modify: `hypr/hyprland-lua-wip.lua`
- Source: `hyprland.conf` lines 76–110 (11 `exec-once`, 1 `exec`) and the single `monitor =` fallback

**Interfaces:**
- Produces: the daemon set that Milestone 1 smoke-tests.

> Real monitor geometry lives in `~/.config/kanshi/config`, **not** here. Translate only the `monitor = , preferred, auto, 1` fallback. Do not move kanshi profiles into Lua.

- [ ] **Step 1: Write the module**

```lua
-- ~/.config/hypr/lua/autostart.lua
-- Fallback only. Real geometry lives in ~/.config/kanshi/config; kanshi reacts
-- to hotplug and applies the matching profile.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.exec_cmd("awww-daemon")
hl.exec_cmd("kanshi")
hl.exec_cmd("waybar")
hl.exec_cmd("swaync")
hl.exec_cmd("swayosd-server")
hl.exec_cmd("hyprsunset")

-- Clipboard history (cliphist) -- watch both text and images
hl.exec_cmd("wl-paste --type text --watch cliphist store")
hl.exec_cmd("wl-paste --type image --watch cliphist store")

-- hypridle is a systemd user service (hypridle.service), not started here.
hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1") -- GUI auth prompts

hl.exec_cmd("ghostty -e herdr", { workspace = "1 silent" })
hl.exec_cmd("zen-browser", { workspace = "2 silent" })

-- GTK4/libadwaita key; GTK3 is themed statically in ~/.config/gtk-3.0/settings.ini
hl.exec_cmd('gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"')
return true
```

- [ ] **Step 2: Confirm the `[workspace N silent]` rule mapping**

```bash
~/.config/hypr/lua/probe.sh 'hl.exec_cmd("true", { workspace = "1 silent" })'
```
Expected: PASS. If it fails, inspect the `rules` table type on `hl.exec_cmd` in the stubs and adjust.

- [ ] **Step 3: Wire in and validate**

Add `require("lua.autostart")` to the entry point.
Run: `Hyprland --config ~/.config/hypr/hyprland-lua-wip.lua --verify-config 2>&1 | tail -3`
Expected: `config ok`

- [ ] **Step 4: Commit**

```bash
cd ~/.config && git add hypr/lua/autostart.lua hypr/hyprland-lua-wip.lua && git commit -m "hypr(lua): migrate autostart and monitor fallback"
```

---

## Task 6: The 54 plain keybinds — MILESTONE 1 (first cutover)

**Files:**
- Create: `hypr/lua/binds.lua`
- Modify: `hypr/hyprland-lua-wip.lua`
- Source: `hyprland.conf` lines 320–412 (every `bind =`)

**Interfaces:**
- Produces: the escape-hatch binds. **These must exist before any cutover** — a cutover without them leaves a session with no way to open a terminal.

- [ ] **Step 1: List every bind to translate**

```bash
grep -nE '^\s*bind\s*=' ~/.config/hypr/hyprland.conf
```
Expected: 54 lines. Translate all of them; none may be dropped.

- [ ] **Step 2: Write the escape-hatch binds FIRST**

```lua
-- ~/.config/hypr/lua/binds.lua
-- Escape hatches first: if anything below is wrong, these are what get you a
-- terminal to run rollback.sh from.
hl.bind("SUPER + Return", hl.dsp.exec_cmd("ghostty -e herdr"))
hl.bind("SUPER + Q", hl.dsp.window.kill)
hl.bind("ALT + Space", hl.dsp.exec_cmd("fuzzel"))
hl.bind("SUPER + Escape", hl.dsp.exec_cmd("wlogout"))
hl.bind("SUPER + SHIFT + Escape", hl.dsp.exec_cmd("hyprlock"))
```

- [ ] **Step 3: Translate the remaining binds by category**

Workspaces 1–10 and move-to-workspace:
```lua
for i = 1, 10 do
	local key = (i == 10) and "0" or tostring(i)
	hl.bind("SUPER + " .. key, hl.dsp.focus{ workspace = i })
	hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move{ workspace = i })
end
```
Confirm the move dispatcher before relying on it:
`~/.config/hypr/lua/probe.sh 'hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move{ workspace = 1 })'`

Directional focus and window movement (plain `hjkl` here — **not** tmux's shifted `jkl;`):
```lua
local dirs = { h = "l", j = "d", k = "u", l = "r" }
for key, dir in pairs(dirs) do
	hl.bind("SUPER + " .. key, hl.dsp.focus{ direction = dir })
	hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move{ direction = dir })
end
```

Capture and utility binds (translate each literally, preserving comments):
```lua
hl.bind("Print", hl.dsp.exec_cmd("~/.config/hypr/screenshot-annotate.sh"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("~/.config/hypr/screenshot-annotate.sh"))
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("hyprcap rec region -c -n -o ~/ScreenRecordings"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker --autocopy"))
hl.bind("SUPER + X", hl.dsp.workspace.toggle_special{ name = "magic" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
```

- [ ] **Step 4: Verify the count matches**

```bash
grep -c 'hl.bind(' ~/.config/hypr/lua/binds.lua
```
Loops count as one line each — reconcile manually against the 54 source binds and list any not yet covered.

- [ ] **Step 5: Wire in and validate**

Add `require("lua.binds")` to the entry point.
Run: `Hyprland --config ~/.config/hypr/hyprland-lua-wip.lua --verify-config 2>&1 | tail -3`
Expected: `config ok` — this also proves all 54 keysyms and dispatchers are valid.

- [ ] **Step 6: Commit BEFORE cutting over**

```bash
cd ~/.config && git add hypr/lua/binds.lua hypr/hyprland-lua-wip.lua && git commit -m "hypr(lua): migrate keybinds"
```

- [ ] **Step 7: MILESTONE 1 — cutover**

Print the rollback procedure where you can read it without a working session, then:
```bash
cd ~/.config/hypr && mv hyprland-lua-wip.lua hyprland.lua && hyprctl reload
hyprctl configerrors   # expected: empty
```

- [ ] **Step 8: Smoke-test by hand**

Confirm each: `SUPER+Return` opens a terminal; `SUPER+Q` kills a window; `ALT+Space` opens fuzzel; `SUPER+2` switches workspace; `SUPER+h/j/k/l` moves focus; `SUPER+SHIFT+S` opens satty. Also confirm daemons survived the reload: `pgrep -c -x waybar` = 1, and no duplicates of kanshi/swaync/swayosd-server.

**If anything is broken:** run `~/.config/hypr/rollback.sh`, fix, re-validate, cut over again. Do not proceed with a broken session.

- [ ] **Step 9: Commit the cutover**

```bash
cd ~/.config && git add -A hypr/ && git commit -m "hypr(lua): cut over to hyprland.lua (milestone 1)"
```

---

## Task 7: Media, brightness, and lid binds — MILESTONE 2

**Files:**
- Create: `hypr/lua/media.lua`
- Modify: `hypr/hyprland.lua` (now the live entry point)
- Source: `hyprland.conf` lines 415–439 (8 `bindel`, 6 `bindl`)

**Interfaces:**
- Consumes: nothing.
- Produces: the lid-switch bind, on which the thermal safety behavior depends.

> **Thermal constraint:** this laptop overheats when the lid is closed while awake. `lid-closed.sh` suspends only when no external monitors are attached. The lid binds must keep working — do not drop or "improve" them.

- [ ] **Step 1: Translate the repeating (`bindel`) binds**

```lua
-- ~/.config/hypr/lua/media.lua
local function el(key, cmd) hl.bind(key, hl.dsp.exec_cmd(cmd), { repeating = true }) end

el("XF86AudioRaiseVolume", "swayosd-client --output-volume raise")
el("XF86AudioLowerVolume", "swayosd-client --output-volume lower")
el("XF86AudioMute", "swayosd-client --output-volume mute-toggle")
el("XF86AudioMicMute", "swayosd-client --input-volume mute-toggle")
el("XF86MonBrightnessUp", "~/.config/hypr/ddc-brightness.sh up")
el("XF86MonBrightnessDown", "~/.config/hypr/ddc-brightness.sh down")
```

Then the two keyboard-backlight binds from lines 423–424 verbatim — they embed `sh -c '...'` with `$(...)`. In Lua use `[[ ]]` long strings so nothing is re-escaped:
```lua
el("XF86KbdBrightnessUp", [[sh -c 'echo $(($(cat /sys/class/leds/chromeos::kbd_backlight/brightness) + 10)) | tee /sys/class/leds/chromeos::kbd_backlight/brightness']])
```

- [ ] **Step 2: Translate the locked (`bindl`) binds**

```lua
local function l(key, cmd) hl.bind(key, hl.dsp.exec_cmd(cmd), { locked = true }) end

l("XF86AudioNext", "playerctl next")
l("XF86AudioPause", "playerctl play-pause")
l("XF86AudioPlay", "playerctl play-pause")
l("XF86AudioPrev", "playerctl previous")
```

- [ ] **Step 3: Resolve the lid-switch bind form (highest-risk item)**

The `switch:on:Lid Switch` pseudo-key may not accept the same string form in Lua. Probe before writing:
```bash
~/.config/hypr/lua/probe.sh 'hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("true"), { locked = true })'
~/.config/hypr/lua/probe.sh 'hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("true"))'
```
Use whichever passes. If neither does, search the stubs for the switch/event form:
```bash
grep -n -iE 'switch|lid' /usr/share/hypr/stubs/hl.meta.lua | head
```
An `hl.on(...)` event handler is the fallback. **Do not ship this task until a lid bind validates.**

```lua
l("switch:on:Lid Switch", "~/.config/hypr/lid-closed.sh")
l("switch:off:Lid Switch", "hyprctl dispatch dpms on eDP-1")
return true
```

- [ ] **Step 4: Wire in and validate**

Add `require("lua.media")` to `hyprland.lua`.
Run: `Hyprland --config ~/.config/hypr/hyprland.lua --verify-config 2>&1 | tail -3`
Expected: `config ok`

- [ ] **Step 5: MILESTONE 2 — reload and test**

```bash
hyprctl reload && hyprctl configerrors
```
Test by hand: volume up/down/mute show a swayosd popup; brightness keys change external monitor brightness; play/pause works; **close the lid with no external monitor attached and confirm it suspends**, then reopen and confirm the display returns.

- [ ] **Step 6: Commit**

```bash
cd ~/.config && git add hypr/lua/media.lua hypr/hyprland.lua && git commit -m "hypr(lua): migrate media, brightness and lid binds (milestone 2)"
```

---

## Task 8: Server-mode submap — MILESTONE 3

**Files:**
- Create: `hypr/lua/submaps.lua`
- Modify: `hypr/hyprland.lua`
- Source: `hyprland.conf` lines 441–446

**Interfaces:**
- Consumes: nothing.
- Produces: the `server-mode-exit` submap that `~/.local/bin/server-mode` enters via `hyprctl dispatch submap`.

> This is the remote-access escape hatch: **any** keypress must exit server mode. The `catchall` bind is what makes that work, and `~/.local/bin/server-mode` and `server-mode.service` depend on the submap keeping the exact name `server-mode-exit`.

- [ ] **Step 1: Resolve the submap signature**

`hl.define_submap(name, reset_or_fn, fn?)`. Probe both shapes:
```bash
~/.config/hypr/lua/probe.sh 'hl.define_submap("test-submap", function() hl.bind("catchall", hl.dsp.exec_cmd("true")) end)'
~/.config/hypr/lua/probe.sh 'hl.define_submap("test-submap", "reset", function() hl.bind("catchall", hl.dsp.exec_cmd("true")) end)'
```

- [ ] **Step 2: Write the module using whichever form passed**

```lua
-- ~/.config/hypr/lua/submaps.lua
-- Entered by ~/.local/bin/server-mode when the display is off. ANY keypress
-- stops the service, whose teardown restores DPMS, resets the submap and
-- releases the sleep inhibitor. The name must stay "server-mode-exit".
hl.define_submap("server-mode-exit", function()
	hl.bind("catchall", hl.dsp.exec_cmd("systemctl --user stop server-mode.service"))
end)
return true
```

- [ ] **Step 3: Wire in and validate**

Add `require("lua.submaps")` to `hyprland.lua`.
Run: `Hyprland --config ~/.config/hypr/hyprland.lua --verify-config 2>&1 | tail -3`
Expected: `config ok`

- [ ] **Step 4: MILESTONE 3 — test server mode end to end**

```bash
hyprctl reload
systemctl --user start server-mode.service   # screen goes off
# press any key -> screen returns
hyprctl getoption input:kb_options           # session still responsive
systemctl --user status server-mode.service  # expected: inactive
```

- [ ] **Step 5: Commit**

```bash
cd ~/.config && git add hypr/lua/submaps.lua hypr/hyprland.lua && git commit -m "hypr(lua): migrate server-mode submap (milestone 3)"
```

---

## Task 9: Window rules and retirement — MILESTONE 4 (Phase 2)

**Files:**
- Create: `hypr/lua/rules.lua`
- Modify: `hypr/hyprland.lua`, `hypr/screenshot-annotate.sh`, `~/.config/README.md`
- Rename: `hypr/hyprland.conf` → `hypr/hyprland.conf.pre-lua`

**Interfaces:**
- Consumes: the satty class `com.gabm.satty`, confirmed via `hyprctl clients`.
- Produces: the first matched window rule on this machine — impossible in hyprlang.

- [ ] **Step 1: Write the window rule that hyprlang could not express**

```lua
-- ~/.config/hypr/lua/rules.lua
-- satty sizes itself to the screenshot; tiling it into dwindle rescales the
-- canvas. This rule is the reason the migration was worth doing -- hyprlang
-- rejected every matched-windowrule form on 0.56.
hl.window_rule({
	name = "float-satty",
	match = { class = "com.gabm.satty" },
	float = true,
})
return true
```

- [ ] **Step 2: Wire in and validate**

Add `require("lua.rules")` to `hyprland.lua`.
Run: `Hyprland --config ~/.config/hypr/hyprland.lua --verify-config 2>&1 | tail -3`
Expected: `config ok`

- [ ] **Step 3: Confirm the rule works, then remove the script workaround**

```bash
hyprctl reload
grim -g "0,0 600x400" - | satty --filename - --copy-command wl-copy >/dev/null 2>&1 &
sleep 2; hyprctl -j clients | grep -A2 'com.gabm.satty' | grep floating
pkill -x satty
```
Expected: `"floating": true` **without** the script's dispatch block. Only then delete the `for _ in $(seq 20)` float loop from `screenshot-annotate.sh` (keep `wait "$editor"`), and re-test the keybind end to end.

- [ ] **Step 4: Full keybind sweep — the completion criterion**

Walk `~/.config/keybind-cheat-sheet.sh` top to bottom and press every binding. Every one must behave as before the migration. Record any failure, fix, re-validate, re-test. **This loop is the definition of done.**

- [ ] **Step 5: Retire the old config**

Only after Step 4 passes with zero failures:
```bash
cd ~/.config/hypr && git mv hyprland.conf hyprland.conf.pre-lua
Hyprland --config ~/.config/hypr/hyprland.lua --verify-config 2>&1 | tail -2  # config ok
hyprctl reload && hyprctl configerrors
```
Keep the renamed file for one week as a reference, then delete it in a separate commit.

- [ ] **Step 6: Update the docs that now lie**

- `~/.config/README.md` — component list mentions `hyprland.conf`.
- `~/.claude/skills/laptop-setup/SKILL.md` — the "where do I edit…" map points at `hyprland.conf` in several places.
- Delete `hypr/rollback.sh` only after the `.pre-lua` file is deleted; until then it is still a valid escape.

- [ ] **Step 7: Final commit**

```bash
cd ~/.config && git add -A hypr/ README.md && git commit -m "hypr(lua): add window rules, retire hyprland.conf (milestone 4)"
```

---

## Self-Review

**Spec coverage.** Every construct counted in the inventory has an owning task: 3 `env` → Task 2; `general`/`decoration`/`animations`(25 bezier+animation)/`dwindle`/`master`/`misc` → Task 3; `input`+`touchpad`+`gesture`+2×`device` → Task 4; 11 `exec-once`+1 `exec`+1 `monitor` → Task 5; 54 `bind` → Task 6; 8 `bindel`+6 `bindl` → Task 7; 1 `submap`+`catchall` → Task 8; window rules → Task 9. The 5 `$variables` are dissolved into literal strings (Task 2), which is why they have no dedicated module.

**Known gaps, stated rather than hidden.** Four API forms are probed rather than asserted, because `--verify-config` is the only reliable oracle and guessing them would put wrong code in this plan: `hl.curve` (Task 3), `hl.gesture` fields (Task 4), `hl.window.move` (Task 6), the lid-switch bind (Task 7), and `hl.define_submap` (Task 8). Each has an exact probe command and a stated fallback. The lid bind is the highest-risk item and is explicitly blocking.

**Out of scope.** Migrating the kanshi `on-*.sh` hooks to `hl.on("monitor.added")` events. It is genuinely attractive — it would let monitor handling live in one place — but it is a redesign, not a translation, and mixing it in would make any breakage ambiguous. Revisit after this plan is done.
