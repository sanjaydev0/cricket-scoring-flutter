#!/usr/bin/env bash
# Safe update: pull the app's own backup, install over the top, verify boot.
# NEVER uninstall. The only copy of the club, roster, live match and archives
# is the app's storage.
set -euo pipefail

ADB="${ADB:-$HOME/Android/Sdk/platform-tools/adb}"
PKG="com.gully.cricket.cricket_scoring"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APK="$REPO/build/app/outputs/flutter-apk/app-release.apk"
DEST="${BACKUP_DIR:-$HOME/backups/cricscore}"
SERIAL="${1:-}"

adb_cmd() {
  if [[ -n "$SERIAL" ]]; then
    "$ADB" -s "$SERIAL" "$@"
  else
    "$ADB" "$@"
  fi
}

[[ -x "$ADB" ]] || { echo "adb not found at $ADB" >&2; exit 1; }
[[ -f "$APK" ]] || { echo "APK missing: $APK (build it first)" >&2; exit 1; }

mkdir -p "$DEST"
STAMP="$(date +%Y%m%d-%H%M%S)"
found=0

# The app-specific copy is written first, always readable, and survives
# `adb install -r`. Prefer it for latest.json.
APP_SRC="/sdcard/Android/data/$PKG/files/backups/cricscore-backup.json"
if adb_cmd shell "test -f '$APP_SRC'" >/dev/null 2>&1; then
  out="$DEST/$STAMP-app-external.json"
  adb_cmd pull "$APP_SRC" "$out" >/dev/null
  echo "backup  $APP_SRC -> $out"
  cp "$out" "$DEST/latest.json"
  found=1
fi

# Pull every public copy, not just the plain name. MediaStore may have
# renamed an older write to "cricscore-backup (1).json"; the newest one is
# still a valid fallback if the app storage was wiped.
while IFS= read -r src; do
  [[ -n "$src" ]] || continue
  base="$(basename "$src")"
  safe="$(printf '%s' "$base" | tr ' ()' '___')"
  out="$DEST/$STAMP-public-$safe"
  if adb_cmd pull "$src" "$out" >/dev/null 2>&1; then
    echo "backup  $src -> $out"
    found=1
    if [[ ! -f "$DEST/latest.json" ]]; then
      cp "$out" "$DEST/latest.json"
    fi
  fi
done < <(
  adb_cmd shell "ls /sdcard/Download/CricScore/cricscore-backup*.json 2>/dev/null" \
    | tr -d '\r'
)

if [[ "$found" -eq 0 ]]; then
  echo "WARNING: no on-device backup found." >&2
  echo "         install -r is still safe; never uninstall." >&2
fi

adb_cmd install -r "$APK"
adb_cmd shell am force-stop "$PKG"
adb_cmd logcat -c
adb_cmd shell am start -n "$PKG/.MainActivity" >/dev/null
sleep 10

echo "--- boot ---"
adb_cmd logcat -d \
  | grep -E "STORE: (restored backup|load\\(\\) complete)|Displayed $PKG" \
  | tail -5 \
  || true
