#!/usr/bin/env bash
#
# Link and enable every systemd user service in ~/.config/services/.
#
# Unit files live in ~/.config/services/ and ARE tracked by this repo.
# ~/.config/systemd/user/ is gitignored, so the symlinks into it do not come
# with a clone and must be recreated on each machine. This is that step.
#
# Idempotent: safe to re-run. Picks up any service added to services/ later.
#
# Run directly, or via install.sh.

set -euo pipefail

SERVICES_DIR="$HOME/.config/services"
UNIT_DIR="$HOME/.config/systemd/user"

if [ ! -d "$SERVICES_DIR" ]; then
  echo "No $SERVICES_DIR, nothing to link."
  exit 0
fi

shopt -s nullglob
units=("$SERVICES_DIR"/*.service)
shopt -u nullglob

if [ ${#units[@]} -eq 0 ]; then
  echo "No .service files in $SERVICES_DIR, nothing to link."
  exit 0
fi

mkdir -p "$UNIT_DIR"

for unit in "${units[@]}"; do
  name=$(basename "$unit")
  ln -sf "$unit" "$UNIT_DIR/$name"
  echo "  linked $name"
done

systemctl --user daemon-reload

for unit in "${units[@]}"; do
  name=$(basename "$unit")
  systemctl --user enable --now "$name"
  echo "  enabled $name"
done

echo "Done. ${#units[@]} service(s) linked and enabled."
