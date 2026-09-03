#!/usr/bin/env bash
# Name a herdr agent from a modal popup, imitating the built-in rename_tab overlay.
#
# Bound in config.toml as [[keys.command]] with type = "popup". This CANNOT be
# type = "shell": shell commands run detached in the background with no TTY, so
# they can never draw a prompt. "popup" is the only command type that gets a
# session-modal terminal.
#
# There is no rename_agent ACTION -- herdr's action bindings are a closed enum
# (rename_tab / rename_workspace / rename_pane and friends), so the real overlay
# widget is not reachable from config. This script is the stand-in.
#
# One prompt sets BOTH names, because herdr keeps them separate:
#   pane.label  -- free text, what the sidebar `pane` token renders
#   agent.name  -- slug handle, what `herdr agent prompt <name> ...` targets,
#                  and which no sidebar token can display
set -uo pipefail

die() { printf '%s\n' "$*"; sleep 1.5; exit 1; }

command -v fzf >/dev/null || die "fzf not found"
command -v jq >/dev/null || die "jq not found"

agents=$(herdr agent list 2>/dev/null) || die "herdr agent list failed"
panes=$(herdr pane list 2>/dev/null) || die "herdr pane list failed"

# agent list has no .label and pane list has no agent state, so join them on
# pane_id. A label the user set wins; otherwise show the agent's own terminal
# title in guillemets to signal "this is auto, not something you named".
rows=$(jq -rn --argjson a "$agents" --argjson p "$panes" '
  ($p.result.panes | map({key: .pane_id, value: (.label // "")}) | from_entries) as $label
  | $a.result.agents[]
  | ($label[.pane_id] // "") as $l
  | [ .pane_id,
      .agent_status,
      .tab_id,
      (if $l != "" then $l else "«" + ((.terminal_title_stripped // "untitled")[0:38]) + "»" end),
      (if .name then "@" + .name else "-" end)
    ] | @tsv') || die "could not read agent list"

[ -n "$rows" ] || die "no agents running"

# Which pane invoked this? A popup is session-modal, so whether it inherits the
# caller's context is not guaranteed. Try each signal in turn and VALIDATE it
# against the agent rows -- a candidate that is not a live agent pane (the
# popup's own shell, say) gets rejected rather than silently preselected.
here=""
for cand in \
  "${HERDR_PANE_ID:-}" \
  "$(herdr pane current 2>/dev/null | jq -r '.result.pane.pane_id // empty')" \
  "$(printf '%s' "$agents" | jq -r 'first(.result.agents[] | select(.focused) | .pane_id) // empty')"
do
  [ -n "$cand" ] || continue
  if printf '%s\n' "$rows" | cut -f1 | grep -qxF -- "$cand"; then here=$cand; break; fi
done

# Float the current pane to the top and tag it. fzf --no-sort keeps this order
# and parks the cursor on the first row, so "rename where I am" is just Enter.
ordered=$(printf '%s\n' "$rows" | awk -F'\t' -v here="$here" '
  { line[NR] = $0; cur[NR] = (here != "" && $1 == here) }
  END {
    for (i = 1; i <= NR; i++) if (cur[i]) print line[i] "\t◂ here"
    for (i = 1; i <= NR; i++) if (!cur[i]) print line[i] "\t"
  }')

pick=$(printf '%s\n' "$ordered" \
  | column -t -s $'\t' \
  | fzf --no-sort --layout=reverse --height=100% --border=rounded \
        --prompt='rename agent > ' \
        --header='enter to name · esc to cancel')
[ -n "$pick" ] || exit 0

pane=${pick%% *}

current=$(herdr pane get "$pane" | jq -r '.result.pane.label // ""')

printf '\n'
# -e -i pre-fills the line with the existing label so this edits rather than retypes.
read -e -r -i "$current" -p "name for $pane (empty clears): " label

if [ -z "$label" ]; then
  herdr pane rename "$pane" --clear >/dev/null 2>&1
  herdr agent rename "$pane" --clear >/dev/null 2>&1
  printf 'cleared %s\n' "$pane"
  sleep 1
  exit 0
fi

# herdr enforces [a-z][a-z0-9_-]{0,31} on agent names, so derive a slug from the
# free-text label rather than making the user type the name twice.
slug=$(printf '%s' "$label" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -e 's/[^a-z0-9_-]\+/-/g' -e 's/^-\+//' -e 's/-\+$//')
# The name must START with a letter. Prefix rather than strip, so a label like
# "2nd attempt" becomes agent-2nd-attempt instead of losing its leading digit.
case $slug in
  [a-z]*) ;;
  '')     slug="" ;;
  *)      slug="agent-$slug" ;;
esac
slug=$(printf '%s' "$slug" | cut -c1-32 | sed 's/-\+$//')

herdr pane rename "$pane" "$label" >/dev/null || die "pane rename failed"

note=""
if [ -n "$slug" ]; then
  # Two distinct failure modes here, so report herdr's own message rather than
  # guessing: the slug may collide with another live agent, OR herdr may have
  # momentarily dropped the pane from its agent registry (`agent_not_found`),
  # which happens while a pane is mid-`working`. The latter succeeds on retry,
  # so try twice before giving up. The label is already set either way.
  for attempt in 1 2; do
    out=$(herdr agent rename "$pane" "$slug" 2>&1)
    err=$(printf '%s' "$out" | jq -r '.error.message // empty' 2>/dev/null)
    [ -z "$err" ] && { note="  handle: @$slug"; break; }
    note="  (handle '$slug': $err)"
    [ "$attempt" = 1 ] && sleep 0.4
  done
fi

printf '%s -> %s%s\n' "$pane" "$label" "$note"
sleep 1.2
