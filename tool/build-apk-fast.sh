#!/usr/bin/env bash
# CricScore — fast debug/release APK build with a TEMPORARY Gradle daemon.
# Flips daemon/parallel/workers in android/gradle.properties for the build,
# then restores the file byte-for-byte and stops the daemon (frees RAM).
# Final releases should still use tool/release.sh (preflight checks).
set -euo pipefail

MODE="${1:-debug}"
ARCH="${2:-android-arm64}"
WORKERS="${WORKERS:-2}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="$HOME/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/default}"

[[ -f pubspec.yaml ]] || { echo "❌ run from Flutter project root"; exit 1; }

GP="android/gradle.properties"
BACKUP="/tmp/opencode/gradle.properties.$(date +%s).bak"
LOG="/tmp/opencode/apk-${MODE}.log"
mkdir -p /tmp/opencode

if pgrep -f "flutter build apk" >/dev/null 2>&1; then
  echo "❌ another 'flutter build apk' is already running"; exit 1
fi

set_flag() {
  local key="$1" val="$2" file="$3"
  if grep -q "^${key}=" "$file"; then
    sed -i "s/^${key}=.*/${key}=${val}/" "$file"
  else
    printf '%s=%s\n' "$key" "$val" >> "$file"
  fi
}

restore() {
  if [[ -f "$BACKUP" ]]; then cp "$BACKUP" "$GP"; rm -f "$BACKUP"; fi
  if [[ "${KEEP_DAEMON:-0}" != "1" ]]; then
    (cd "$ROOT/android" && ./gradlew --stop >/dev/null 2>&1 || true)
    pkill -f "org.jetbrains.kotlin.daemon.KotlinCompileDaemon" 2>/dev/null || true
  fi
}
trap restore EXIT INT TERM

cp "$GP" "$BACKUP"
set_flag org.gradle.daemon true  "$GP"
set_flag org.gradle.parallel true "$GP"
set_flag org.gradle.workers.max "$WORKERS" "$GP"

if [[ ! -f .dart_tool/package_config.json || pubspec.yaml -nt .dart_tool/package_config.json ]]; then
  flutter pub get
fi

: > "$LOG"
echo "🚀 Fast APK build — mode=$MODE platform=$ARCH workers=$WORKERS"
START=$(date +%s)
if [[ "$MODE" == "release" ]]; then
  flutter build apk --release --target-platform "$ARCH" --split-per-abi \
    --android-gradle-daemon --no-pub -v 2>&1 | tee "$LOG"
  APK="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
else
  flutter build apk --debug --target-platform "$ARCH" \
    --android-gradle-daemon --no-pub -v 2>&1 | tee "$LOG"
  APK="build/app/outputs/flutter-apk/app-debug.apk"
fi
END=$(date +%s)
echo "🎉 done in $((END-START))s"
[[ -f "$APK" ]] && echo "📦 $APK ($(du -h "$APK" | cut -f1))"
" path="/home/sanjay/Projects/cricket-scoring-flutter/tool/build-apk-fast.sh