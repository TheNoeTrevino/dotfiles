#!/usr/bin/env bash
#
# Feed the 1..9 workspace index into herdr's expanded sidebar as a metadata token.
#
# herdr renders index numbers natively ONLY in the COLLAPSED sidebar rail
# (src/ui/sidebar.rs render_sidebar_collapsed). The EXPANDED spaces panel draws
# no number -- its row prefix is whitespace plus worktree tree glyphs, and the
# only built-in tokens are state_icon, state_text, workspace, branch, git_status.
# Expanded numbering existed once (CHANGELOG 0.1.2, "Sidebar now shows workspace
# numbers again in expanded view") but was dropped without a changelog entry;
# assets/screenshot.png upstream still shows it, which is misleading.
#
# There is no index token: `number`, `index`, `position`, `num`, and `idx` are
# all rejected with "unknown sidebar token; custom tokens must start with `$`".
# Custom `$` tokens DO work and `report-metadata` sets them, so this loop is the
# only way to number the expanded panel on 0.8.2.
#
# Consumed by:
#   [ui.sidebar.spaces]  ->  $num   (matches switch_workspace = prefix+1..9)
#
# Agents are deliberately not numbered here: the agent panel has no native index
# either, and deriving one from `agent list` order breaks under
# ui.agent_panel_sort = "priority", which reorders rows on state change.
#
# Runs as herdr-sidebar-numbers.service. See ~/.config/services/.

set -uo pipefail

HERDR="${HERDR_BIN:-$HOME/.local/bin/herdr}"
SOURCE="sidebar-numbers"
INTERVAL="${HERDR_NUMBERS_INTERVAL:-2}"

# Outlive a few intervals so a brief hiccup does not blank the numbers, but do
# expire if this syncer dies. A stale index is worse than no index.
TTL_MS=$((INTERVAL * 3 * 1000))

sync_workspaces() {
  # .number is already compact 1..N and matches sidebar order, so it is the
  # same index switch_workspace uses.
  "$HERDR" workspace list 2>/dev/null |
    jq -r '.result.workspaces[] | "\(.workspace_id)\t\(.number)"' |
    while IFS=$'\t' read -r id num; do
      "$HERDR" workspace report-metadata "$id" --source "$SOURCE" \
        --token "num=$num" --ttl-ms "$TTL_MS" >/dev/null 2>&1
    done
}

while :; do
  if "$HERDR" status server 2>/dev/null | grep -q 'status: running'; then
    sync_workspaces
  fi
  sleep "$INTERVAL"
done
