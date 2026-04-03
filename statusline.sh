#!/usr/bin/env bash
set -euo pipefail

# Read JSON from stdin
data=$(cat)

# --- Helpers ---
val() { echo "$data" | jq -r "$1 // empty" 2>/dev/null; }
num() { echo "$data" | jq -r "$1 // 0" 2>/dev/null; }

# ANSI colors
reset=$'\e[0m'
bold=$'\e[1m'
cyan=$'\e[36m'
green=$'\e[32m'
yellow=$'\e[33m'
red=$'\e[31m'
dim=$'\e[2m'

color_by_pct() {
  local pct=$1
  if ((pct < 60)); then
    echo "$green"
  elif ((pct < 80)); then
    echo "$yellow"
  else echo "$red"; fi
}

progress_bar() {
  local pct=$1 width=${2:-10}
  local filled=$((pct * width / 100))
  local empty=$((width - filled))
  local bar=""
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  for ((i = 0; i < empty; i++)); do bar+="░"; done
  echo "$bar"
}

# --- Model ---
model=$(val '.model.display_name')
[ -z "$model" ] && model=$(val '.model.id')
# Shorten model name
model=$(echo "$model" | sed -E 's/^claude-//; s/-20[0-9]{6}$//')

# --- Effort (output style) ---
effort=$(val '.output_style.name')

# --- CWD (shortened) ---
cwd=$(val '.cwd')
cwd=${cwd/#$HOME/\~}

# --- Git branch + dirty ---
git_part=""
if git rev-parse --is-inside-work-tree &>/dev/null; then
  branch=$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git --no-optional-locks rev-parse --short HEAD 2>/dev/null || echo "???")
  if git --no-optional-locks diff --quiet HEAD -- 2>/dev/null && git --no-optional-locks diff --cached --quiet HEAD -- 2>/dev/null; then
    git_part="${green}${branch}${reset}"
  else
    git_part="${yellow}${branch}*${reset}"
  fi
fi

# --- Context window ---
ctx_pct=$(num '.context_window.used_percentage' | cut -d. -f1)
ctx_color=$(color_by_pct "$ctx_pct")
ctx_bar=$(progress_bar "$ctx_pct")
ctx_part="${dim}ctx:${reset} ${ctx_color}[${ctx_bar}] ${ctx_pct}%${reset}"

# --- 5hr rate limit ---
rate_part=""
rate_pct=$(val '.rate_limits.five_hour.used_percentage')
if [ -n "$rate_pct" ]; then
  rate_pct_int=$(echo "$rate_pct" | cut -d. -f1)
  rate_color=$(color_by_pct "$rate_pct_int")

  resets_at=$(val '.rate_limits.five_hour.resets_at')
  time_str=""
  if [ -n "$resets_at" ]; then
    now=$(date +%s)
    reset_epoch=$(date -d "$resets_at" +%s 2>/dev/null || echo "")
    if [ -n "$reset_epoch" ] && [ "$reset_epoch" -gt "$now" ]; then
      diff_s=$((reset_epoch - now))
      hrs=$((diff_s / 3600))
      mins=$(((diff_s % 3600) / 60))
      if [ "$hrs" -gt 0 ]; then
        time_str=" (${hrs}h${mins}m)"
      else
        time_str=" (${mins}m)"
      fi
    fi
  fi
  rate_part="${dim}5hr:${reset} ${rate_color}${rate_pct_int}%${time_str}${reset}"
fi

# --- Lines changed ---
lines_add=$(num '.cost.total_lines_added')
lines_del=$(num '.cost.total_lines_removed')
lines_part="${green}+${lines_add}${reset}/${red}-${lines_del}${reset}"

# --- Assemble ---
parts=()
[ -n "$model" ] && parts+=("${cyan}${model}${reset}")
[ -n "$effort" ] && [ "$effort" != "default" ] && parts+=("${dim}effort:${reset} ${yellow}${effort}${reset}")
[ -n "$cwd" ] && parts+=("${dim}${cwd}${reset}")
[ -n "$git_part" ] && parts+=("$git_part")
parts+=("$ctx_part")
[ -n "$rate_part" ] && parts+=("$rate_part")
parts+=("$lines_part")

sep=" ${dim}|${reset} "
output=""
for i in "${!parts[@]}"; do
  [ "$i" -gt 0 ] && output+="$sep"
  output+="${parts[$i]}"
done

echo -n "$output"
