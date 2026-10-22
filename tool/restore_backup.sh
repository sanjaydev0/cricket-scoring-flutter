#!/usr/bin/env bash
# Push a backup and let a fresh install auto-restore it.
# Use this ONLY before the first launch after a fresh install. If the app
# already has data, use Settings -> Data backup -> Restore instead.
set -euo pipefail

ADB="${ADB:-$HOME/Android/Sdk/platform-tools/adb}"
PKG="com.gully.cricket.cricket_scoring"
SERIAL="${2:-}"
FILE="${1:-}"

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "usage: $0 <backup.json> [device-serial]" >&2
  echo "       (serial is optional when only one device is connected)" >&2
  exit 1
fi

adb_cmd() {
  if [[ -n "$SERIAL" ]]; then
    "$ADB" -s "$SERIAL" "$@"
  else
    "$ADB" "$@"
  fi
}

[[ -x "$ADB" ]] || { echo "adb not found at $ADB" >&2; exit 1; }

echo "note: if the app already has data, auto-restore will not run."
echo "      use Settings -> Data backup -> Restore instead."

adb_cmd shell mkdir -p /sdcard/Download/CricScore
adb_cmd push "$FILE" /sdcard/Download/CricScore/cricscore-backup.json
# The app-specific copy is the one guaranteed to be readable after a fresh
# install; Downloads is the copy that survives an uninstall.
adb_cmd shell mkdir -p "/sdcard/Android/data/$PKG/files/backups"
adb_cmd push "$FILE" "/sdcard/Android/data/$PKG/files/backups/cricscore-backup.json"
adb_cmd shell am force-stop "$PKG"
adb_cmd logcat -c
adb_cmd shell am start -n "$PKG/.MainActivity" >/dev/null
sleep 10

echo "--- boot ---"
adb_cmd logcat -d \
  | grep -E "STORE: (restored backup|load\\(\\) complete)" \
  | tail -3 \
  || true
