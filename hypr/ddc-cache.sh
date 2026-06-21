#!/usr/bin/env bash
# Write the list of external-monitor I2C bus numbers to a cache file
# consumed by ddc-brightness.sh. Run from the kanshi dock hooks so the
# brightness script never pays the ~1.4s `ddcutil detect` cost per keypress.

CACHE="${XDG_RUNTIME_DIR:-/tmp}/ddc-buses"

ddcutil detect --brief 2>/dev/null \
  | awk '/^Display/{d=1} d&&/I2C bus/{n=$0; sub(/.*i2c-/,"",n); print n; d=0}' \
  > "$CACHE"
