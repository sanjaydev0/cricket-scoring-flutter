#!/usr/bin/env bash
# Fast phone reinstall: arm64-only release APK + backup-first install.
#
#   ./tool/fast-install.sh [serial]
#
# This is the everyday loop for YOUR phone (SM-G781B, arm64-v8a). It builds a
# single-ABI APK (~20 MB, ~2-3 min) instead of the universal 72 MB one, and
# installs over the top so app data survives. It does NOT tag, does NOT run the
# full test suite, and does NOT touch the GitHub release:
# `./tool/release.sh <version> "<notes>"` stays the universal, versioned path.
#
# NEVER uninstall. The only copy of the club, roster, live match and archives
# is the app's storage.
set -euo pipefail

ADB="${ADB:-$HOME/Android/Sdk/platform-tools/adb}"
PKG="com.gully.cricket.cricket_scoring"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

export PATH="$HOME/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
# AGP 8 defaults the debug keystore to ~/.config/.android on Linux, but this
# phone's install is signed with ~/.android/debug.keystore. Without this the
# install fails INSTALL_FAILED_UPDATE_INCOMPATIBLE and the only "repair" would
# be uninstalling, which deletes the club, roster and archives.
export ANDROID_USER_HOME="${ANDROID_USER_HOME:-$HOME/.android}"

# 100% offline: no backend defines, no network permission.
DEST="${BACKUP_DIR:-$HOME/backups/cricscore}"
SERIAL="${1:-}"

adb_cmd() {
  if [[ -n "$SERIAL" ]]; then "$ADB" -s "$SERIAL" "$@"; else "$ADB" "$@"; fi
}

[[ -x "$ADB" ]] || { echo "adb not found at $ADB" >&2; exit 1; }

if [[ -z "$SERIAL" ]]; then
  mapfile -t DEVICES < <("$ADB" devices | awk '/device$/{print $1}')
  [[ ${#DEVICES[@]} -gt 0 ]] || { echo "no phone attached (adb devices)" >&2; exit 1; }
  [[ ${#DEVICES[@]} -eq 1 ]] ||
    { printf 'several devices attached: %s\n' "${DEVICES[*]}" >&2; exit 1; }
  SERIAL="${DEVICES[0]}"
fi
echo "==> device $SERIAL"

ABI="$(adb_cmd shell getprop ro.product.cpu.abi | tr -d '\r')"
echo "    abi $ABI"
[[ "$ABI" == "arm64-v8a" ]] ||
  echo "    WARNING: phone is $ABI, building arm64 anyway" >&2

# --- backup before touching the installed app ------------------------------
mkdir -p "$DEST"
STAMP="$(date +%Y%m%d-%H%M%S)"
APP_SRC="/sdcard/Android/data/$PKG/files/backups/cricscore-backup.json"
if adb_cmd shell "test -f '$APP_SRC'" >/dev/null 2>&1; then
  out="$DEST/$STAMP-app-external.json"
  adb_cmd pull "$APP_SRC" "$out" >/dev/null
  cp "$out" "$DEST/latest.json"
  echo "    backup -> $out"
else
  echo "    WARNING: no app backup on the phone yet" >&2
fi

# --- build arm64 only -------------------------------------------------------
# NOTE: no --split-per-abi. ABI splits override the versionCode
# (abiOffset * 1000 + base), so an arm64 split installs as 2101 while the
# universal release APK is 101. The next GitHub release would then be refused
# as a version downgrade — and the only repair is uninstalling, which deletes
# the club, roster and archives. One ABI, plain version code.
# This overwrites build/.../app-release.apk with an arm64-only build;
# ./tool/release.sh always rebuilds the universal APK before releasing.
echo "==> build (arm64-v8a, no pub)"
flutter build apk --release --no-pub \
  --target-platform android-arm64 >/tmp/opencode/apk-arm64.log 2>&1 ||
  { tail -n 20 /tmp/opencode/apk-arm64.log; echo "build failed" >&2; exit 1; }

APK="build/app/outputs/flutter-apk/app-release.apk"
[[ -f "$APK" ]] || { echo "missing $APK" >&2; exit 1; }

AAPT="$(ls "$HOME/Android/Sdk/build-tools/"*/aapt2 2>/dev/null | head -n 1 || true)"
if [[ -n "$AAPT" ]]; then
  # Capture first, never pipe aapt2 straight into grep: grep -m1 exits at the
  # first match while aapt2 is still writing, aapt2 dies of SIGPIPE, and
  # `set -o pipefail` turns that into exit 141 — which aborted this script
  # silently after the build, before the install.
  PERMS="$("$AAPT" dump permissions "$APK" 2>/dev/null || true)"
  if grep -q "android.permission.INTERNET" <<<"$PERMS"; then
    echo "apk has INTERNET permission — the app is offline, network code returned" >&2
    exit 1
  fi
  echo "    offline ok (no INTERNET)"
  BADGING="$("$AAPT" dump badging "$APK" 2>/dev/null || true)"
  VER="$(grep -m1 -o "versionName='[^']*'" <<<"$BADGING" | cut -d"'" -f2 || true)"
  VC="$(grep -m1 -o "versionCode='[0-9]*'" <<<"$BADGING" | cut -d"'" -f2 || true)"
  echo "    $(du -h "$APK" | cut -f1)  version ${VER:-unknown} (${VC:-?})"
  # Guards against a reintroduced --split-per-abi: an ABI-split versionCode is
  # base + offset*1000 and would lock the phone out of future universal builds.
  if [[ -n "$VC" && "$VC" -ge 1000 ]]; then
    echo "versionCode $VC looks ABI-split — that blocks later universal" >&2
    echo "releases as a downgrade. Rebuild without --split-per-abi." >&2
    exit 1
  fi
fi

# --- install over the top ---------------------------------------------------
echo "==> install"
OUT="$(adb_cmd install -r "$APK" 2>&1 || true)"
# Recovery only: a build made with --split-per-abi leaves a versionCode of
# e.g. 2101 on the phone, which a plain 101 APK cannot replace. -d allows the
# downgrade without losing app data.
if [[ "$OUT" == *VERSION_DOWNGRADE* ]]; then
  echo "    phone has a higher versionCode (ABI-split leftover); allowing downgrade"
  OUT="$(adb_cmd install -r -d "$APK" 2>&1 || true)"
fi
tail -n 2 <<<"$OUT"
if [[ "$OUT" != *Success* ]]; then
  if [[ "$OUT" == *UPDATE_INCOMPATIBLE* ]]; then
    echo "signed with a different key: rebuild with" >&2
    echo "ANDROID_USER_HOME=\$HOME/.android (see AGENTS.md)." >&2
  fi
  echo "install failed" >&2
  exit 1
fi

adb_cmd shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
sleep 4

echo "==> verify"
adb_cmd shell dumpsys package "$PKG" 2>/dev/null |
  grep -E "versionName|versionCode" | head -n 2 || true
adb_cmd logcat -d 2>/dev/null | grep "STORE:" | tail -n 2 || true
