#!/usr/bin/env bash
#
# Push this dotfiles repo to the remote machines (geekom, pi).
#
# Each host clones this repo from GitHub itself, then rsyncs the tracked
# top-level entries into its own ~/.config. The host clones rather than
# receiving a copy of this laptop's live ~/.config, because the live tree
# carries gitignored runtime state -- herdr alone holds a 22M log and live
# sockets. A clone has none of it.
#
# Only entries tracked in this repo are touched, so host-local config the repo
# knows nothing about (btop, go, gh, crush, ...) survives every run. Nothing is
# deleted except the entries in FULL_REPLACE, which means a file this repo no
# longer ships stays on the host until you remove it by hand.
#
# Usage:
#   scripts/sync-remote.sh                 both hosts, config then packages
#   scripts/sync-remote.sh geekom          one host
#   scripts/sync-remote.sh -n              dry run: report only, change nothing
#   scripts/sync-remote.sh --no-packages   skip the apt phase (it needs sudo)
#
# Idempotent: safe to re-run. The hosts pull from GitHub, so commit and push
# before a real run or they will copy the last pushed state, not this tree.

set -euo pipefail

DOTFILES_URL="git@github.com:TheNoeTrevino/dotfiles.git"
DOTFILES_BRANCH="main"
CLAUDE_URL="git@github.com:TheNoeTrevino/claude-config.git"
CLAUDE_BRANCH="main"
DEFAULT_HOSTS=(geekom pi)

# Wiped before the copy, so the host ends up byte-identical to the repo.
# nvim is here because both hosts carry their own NoeVim clone. Merging into
# one would leave a tree that is half this repo and half whatever it had.
FULL_REPLACE=(nvim)

# Synced like everything else, only kept out of the conflict report.
QUIET=(lazygit)

# Both hosts run Ubuntu and carry all three in apt. sesh is packaged nowhere,
# so it goes through `go install` instead. go is at /usr/bin/go on both.
APT_PACKAGES=(fzf bat git-delta)
SESH_PKG="github.com/joshmedeski/sesh/v2@latest"

dry=0
packages=1
hosts=()

while [ $# -gt 0 ]; do
  case $1 in
  -n | --dry-run) dry=1 ;;
  --no-packages) packages=0 ;;
  -h | --help)
    sed -n '3,23p' "$0" | sed 's/^# \?//'
    exit 0
    ;;
  -*)
    echo "sync-remote: unknown option $1" >&2
    exit 2
    ;;
  *) hosts+=("$1") ;;
  esac
  shift
done

[ ${#hosts[@]} -gt 0 ] || hosts=("${DEFAULT_HOSTS[@]}")

# Phase 1 and 2: dotfiles and Claude config. Neither needs root, so this runs
# over a plain non-interactive ssh.
sync_host() {
  ssh -o BatchMode=yes "$1" bash -s -- \
    "$DOTFILES_URL" "$DOTFILES_BRANCH" "$CLAUDE_URL" "$CLAUDE_BRANCH" \
    "$dry" "${FULL_REPLACE[*]}" "${QUIET[*]}" <<'REMOTE'
set -euo pipefail

dotfiles_url=$1 dotfiles_branch=$2 claude_url=$3 claude_branch=$4 dry=$5
read -ra full_replace <<<"$6"
read -ra quiet <<<"$7"

repo="$HOME/.dotfiles"
dest="$HOME/.config"
backup="$HOME/.local/state/dotfiles-sync/$(date +%Y%m%d-%H%M%S)"

in_list() {
  local needle=$1 item
  shift
  for item in "$@"; do [ "$item" = "$needle" ] && return 0; done
  return 1
}

# Mirror the repo. `reset --hard`, not `pull`: this clone exists only to be
# copied out of and is never edited by hand, so a re-run must not be able to
# conflict or leave a merge half finished.
if [ -d "$repo/.git" ]; then
  git -C "$repo" fetch --quiet origin "$dotfiles_branch"
  git -C "$repo" reset --hard --quiet "origin/$dotfiles_branch"
  # A dropped submodule leaves its directory behind and reset warns about it
  # on every later run. clean takes it out. Submodule paths stay, because
  # they are tracked and clean never touches a tracked path.
  git -C "$repo" clean --quiet -fd
else
  git clone --quiet --branch "$dotfiles_branch" "$dotfiles_url" "$repo"
fi
git -C "$repo" submodule update --init --recursive --quiet

# The repo itself decides what ships. A gitlink such as nvim lists as one
# entry, so cutting at the first slash gives exactly the top-level set.
mapfile -t entries < <(
  git -C "$repo" ls-files | cut -d/ -f1 | sort -u |
    grep -vxe '\.gitignore' -e '\.gitmodules'
)

printf '### %s -- %d entries\n' "$(hostname)" "${#entries[@]}"

for entry in "${entries[@]}"; do
  src="$repo/$entry"
  [ -e "$src" ] || continue

  # A submodule's .git is a file pointing back into the superproject and a
  # plain .git is history the host has no use for. Never copy either.
  opts=(--archive --exclude=.git --backup --backup-dir="$backup/$entry")
  if [ -d "$src" ]; then
    from="$src/" to="$dest/$entry/"
  else
    from="$src" to="$dest/$entry"
  fi
  # --delete-excluded is what removes the host's own .git, so a FULL_REPLACE
  # entry stops being a git checkout and becomes a plain copy.
  if in_list "$entry" "${full_replace[@]}"; then
    opts+=(--delete --delete-excluded)
  fi

  # --checksum only for the report. Without it rsync decides by size and
  # mtime, so a file with identical content but a newer stamp reads as a
  # conflict and the report cries wolf.
  changes=$(rsync "${opts[@]}" --dry-run --itemize-changes --checksum "$from" "$to")

  if ! in_list "$entry" "${quiet[@]}"; then
    # rsync pads the change code to 11 columns, so the path starts at 13.
    # Column 3 is 'c' when the content differs and column 4 is 's' when the
    # size does. A code with neither is metadata only and clobbers nothing.
    printf '%s\n' "$changes" |
      awk -v e="$entry" '
        /^[<>c]f/ {
          if (substr($1, 3, 1) == "c" || substr($1, 4, 1) == "s")
            printf "  overwrite  %s/%s\n", e, substr($0, 13)
          next
        }
        /^\*deleting/ {
          path = substr($0, 13)
          # A FULL_REPLACE entry drops the host git checkout. That is the
          # point of the flag, not news, so it collapses to one line.
          if (path ~ /(^|\/)\.git\//) { gitdel++; next }
          # Directory removals are implied by the files inside them.
          if (path ~ /\/$/) next
          printf "  delete     %s/%s\n", e, path
        }
        END {
          if (gitdel)
            printf "  delete     %s/.git/ -- %d files, the host git checkout\n", e, gitdel
        }
      '
  fi

  [ "$dry" = 1 ] || rsync "${opts[@]}" "$from" "$to" >/dev/null
done

# ~/.claude already exists on both hosts and holds live credentials, and git
# refuses to clone into a non-empty directory. Init in place instead. The
# forced checkout overwrites the tracked files and leaves everything the repo
# gitignores -- credentials, sessions, projects, cache -- untouched.
claude="$HOME/.claude"
if [ "$dry" = 1 ]; then
  if [ -d "$claude/.git" ]; then
    printf '  claude     ~/.claude resets to origin/%s\n' "$claude_branch"
  else
    printf '  claude     ~/.claude becomes a clone of %s\n' "$claude_url"
  fi
else
  if [ ! -d "$claude/.git" ]; then
    mkdir -p "$claude"
    git -C "$claude" init --quiet
    git -C "$claude" remote add origin "$claude_url"
  fi
  git -C "$claude" fetch --quiet origin "$claude_branch"
  git -C "$claude" checkout --quiet --force -B "$claude_branch" \
    "origin/$claude_branch"
fi
REMOTE
}

# Phase 3: packages. apt needs root and neither host has passwordless sudo, so
# this one runs under a tty and prompts.
install_packages() {
  local host=$1
  # The script is staged first and run second. `ssh -t host bash -s` cannot
  # work here: stdin is the heredoc, so sudo's prompt would have no keyboard.
  ssh -o BatchMode=yes "$host" 'cat > /tmp/sync-remote-packages.sh' <<'REMOTE'
set -euo pipefail
read -ra pkgs <<<"$1"
sesh_pkg=$2

missing=()
for pkg in "${pkgs[@]}"; do
  dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "installing: ${missing[*]}"
  sudo apt-get update -qq
  sudo apt-get install -y "${missing[@]}"
else
  echo "apt packages already present"
fi

mkdir -p "$HOME/.local/bin"

# Ubuntu ships bat as batcat, because the name bat belongs to another package.
if [ -x /usr/bin/batcat ]; then
  ln -sfn /usr/bin/batcat "$HOME/.local/bin/bat"
fi

# Neither host carries $GOPATH/bin on PATH, and ~/.local/bin already is, so
# the binary gets a link there rather than a new PATH entry in the shell.
if [ ! -x "$(go env GOPATH)/bin/sesh" ]; then
  go install "$sesh_pkg"
fi
ln -sfn "$(go env GOPATH)/bin/sesh" "$HOME/.local/bin/sesh"

echo "linked: $(ls "$HOME/.local/bin")"
REMOTE
  ssh -t "$host" \
    "bash /tmp/sync-remote-packages.sh '${APT_PACKAGES[*]}' '$SESH_PKG'
     rm -f /tmp/sync-remote-packages.sh"
}

for host in "${hosts[@]}"; do
  printf '\n'
  sync_host "$host"
done

if [ "$dry" = 1 ]; then
  printf '\nDry run. Nothing changed. Drop -n to apply.\n'
  exit 0
fi

if [ "$packages" = 1 ]; then
  for host in "${hosts[@]}"; do
    printf '\n### %s -- packages\n' "$host"
    install_packages "$host"
  done
fi
