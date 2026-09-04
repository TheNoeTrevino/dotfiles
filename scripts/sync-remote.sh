#!/usr/bin/env bash
#
# Keep the remote machines' ~/.config tracking this repo.
#
# A host's ~/.config IS a clone of this repo, the same as on the laptop, so
# `git -C ~/.config status` works there and a sync is a fetch and a reset.
#
# git refuses to clone into a non-empty directory, and every host already has a
# ~/.config full of things this repo knows nothing about (btop, go, opencode,
# ...). So the first run adopts the directory in place: init, add the remote,
# fetch, force the checkout. Those host-local entries stay untracked, and their
# names go into .git/info/exclude, which is per-clone and never reaches here.
#
# Later runs are `git reset --hard origin/main`, which touches tracked files
# only. Gitignored runtime state survives it -- herdr's log, its sockets and
# session.json among them. Nothing here ever runs `git clean` on a host.
#
# Usage:
#   scripts/sync-remote.sh                 both hosts, config then packages
#   scripts/sync-remote.sh geekom          one host
#   scripts/sync-remote.sh -n              dry run: report only, change nothing
#   scripts/sync-remote.sh --no-packages   skip the apt phase (it needs sudo)
#
# Idempotent: safe to re-run. The hosts fetch from GitHub, so commit and push
# before a real run or they will take the last pushed state, not this tree.

set -euo pipefail

DOTFILES_URL="git@github.com:TheNoeTrevino/dotfiles.git"
DOTFILES_BRANCH="main"
CLAUDE_URL="git@github.com:TheNoeTrevino/claude-config.git"
CLAUDE_BRANCH="main"
DEFAULT_HOSTS=(geekom pi)

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
    sed -n '3,25p' "$0" | sed 's/^# \?//'
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

# Phase 1 and 2: ~/.config and ~/.claude. Neither needs root, so this runs over
# a plain non-interactive ssh.
sync_host() {
  ssh -o BatchMode=yes "$1" bash -s -- \
    "$DOTFILES_URL" "$DOTFILES_BRANCH" "$CLAUDE_URL" "$CLAUDE_BRANCH" "$dry" <<'REMOTE'
set -euo pipefail

dotfiles_url=$1 dotfiles_branch=$2 claude_url=$3 claude_branch=$4 dry=$5

printf '### %s\n' "$(hostname)"

# adopt_repo <label> <dir> <url> <branch>
#
# Leaves <dir> a clone of <url> tracking <branch>, whether or not it is one
# yet, and without disturbing anything the repo does not track.
adopt_repo() {
  local label=$1 dir=$2 url=$3 br=$4

  if [ -d "$dir/.git" ]; then
    git -C "$dir" remote set-url origin "$url"
    git -C "$dir" fetch --quiet origin "$br"
    if git -C "$dir" diff --quiet "HEAD" "origin/$br" 2>/dev/null; then
      printf '  %-10s up to date\n' "$label"
    else
      printf '  %-10s %s\n' "$label" \
        "$(git -C "$dir" diff --shortstat "HEAD" "origin/$br")"
      git -C "$dir" diff --stat "HEAD" "origin/$br" | sed '$d;s/^/    /'
    fi
    [ "$dry" = 1 ] || git -C "$dir" reset --hard --quiet "origin/$br"
    return
  fi

  # First run. The directory exists and holds files, so git cannot clone into
  # it; init and fetch instead, then force the checkout over what is there.
  printf '  %-10s adopting %s as a clone of %s\n' "$label" "$dir" "$url"
  if [ "$dry" = 1 ]; then
    printf '    (dry run, not adopted -- rerun without -n to see the file list)\n'
    return
  fi

  mkdir -p "$dir"
  git -C "$dir" init --quiet
  git -C "$dir" remote add origin "$url"
  git -C "$dir" fetch --quiet origin "$br"

  # Seed the per-clone ignore list with the top-level entries the incoming tree
  # does not carry. Without this every host-local directory reads as untracked
  # from here on. .git/info/exclude is local to this clone, so no host name
  # ever lands in the repo's own .gitignore.
  local incoming
  incoming=$(git -C "$dir" ls-tree --name-only "origin/$br")
  for entry in $(ls -A "$dir"); do
    [ "$entry" = ".git" ] && continue
    printf '%s\n' "$incoming" | grep -qxF "$entry" && continue
    printf '  %-10s excluding host-local %s\n' "$label" "$entry"
    printf '/%s\n' "$entry" >>"$dir/.git/info/exclude"
  done

  git -C "$dir" checkout --quiet --force -B "$br" "origin/$br"
}

if [ "$dry" = 0 ]; then
  # nvim is a gitlink, and `submodule update` will not clone into a non-empty
  # directory. An earlier version of this script rsynced a plain copy there, so
  # clear it. Every byte comes back from the NoeVim repo.
  if [ -d "$HOME/.config/nvim" ] && [ ! -e "$HOME/.config/nvim/.git" ]; then
    rm -rf "$HOME/.config/nvim"
  fi
  # Same story for tmux, whose submodule this repo dropped. Left alone it would
  # be adopted as host-local config and excluded forever.
  rm -rf "$HOME/.config/tmux"
fi

adopt_repo config "$HOME/.config" "$dotfiles_url" "$dotfiles_branch"

# --force discards whatever the host had, which is the point: the laptop
# decides which commit of NoeVim every machine runs.
if [ "$dry" = 0 ] && [ -d "$HOME/.config/.git" ]; then
  git -C "$HOME/.config" submodule update --init --recursive --force --quiet
fi

adopt_repo claude "$HOME/.claude" "$claude_url" "$claude_branch"

# ~/.dotfiles was the staging mirror an earlier version of this script rsynced
# out of. ~/.config is the clone now, so the mirror is dead weight.
if [ -d "$HOME/.dotfiles" ]; then
  if [ "$dry" = 1 ]; then
    printf '  cleanup    would remove the obsolete ~/.dotfiles mirror\n'
  else
    rm -rf "$HOME/.dotfiles"
    printf '  cleanup    removed the obsolete ~/.dotfiles mirror\n'
  fi
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
