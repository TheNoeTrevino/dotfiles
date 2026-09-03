#!/usr/bin/env bash
#
# Feed the 1..9 index numbers into herdr's sidebar as metadata tokens.
#
# herdr has no built-in sidebar token for the index. `number`, `index`,
# `position`, `num`, and `idx` are all rejected with "unknown sidebar token;
# custom tokens must start with `$`". Custom `$` tokens DO work, and
# `report-metadata` is how you set them, so this loop keeps them current.
#
# Consumed by:
#   [ui.sidebar.spaces]  ->  $num   (matches switch_workspace = prefix+shift+1..9)
#   [ui.sidebar.agents]  ->  $n     (matches focus_agent    = prefix+alt+1..9)
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

sync_agents() {
  # Agents carry no index of their own. The agent panel renders `agent list`
  # order while ui.agent_panel_sort = "spaces", so array position is the index.
  # This breaks under agent_panel_sort = "priority", which reorders on state.
  "$HERDR" agent list 2>/dev/null |
    jq -r '.result.agents | to_entries[] | "\(.value.pane_id)\t\(.key + 1)"' |
    while IFS=$'\t' read -r pane num; do
      "$HERDR" pane report-metadata "$pane" --source "$SOURCE" \
        --token "n=$num" --ttl-ms "$TTL_MS" >/dev/null 2>&1
    done
}

while :; do
  if "$HERDR" status server 2>/dev/null | grep -q 'status: running'; then
    sync_workspaces
    sync_agents
  fi
  sleep "$INTERVAL"
done
