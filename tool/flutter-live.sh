#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/flutter/bin:$PATH"

DEVICE="${1:-linux}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PID_FILE="/tmp/opencode/flutter-live-${ROOT##*/}.pid"
mkdir -p /tmp/opencode
rm -f "$PID_FILE"

command -v watchexec >/dev/null || {
  echo "watchexec is missing" >&2
  exit 1
}

# Keep startup fast, but never let a stale package config survive a pubspec change.
if [[ ! -f .dart_tool/package_config.json || pubspec.yaml -nt .dart_tool/package_config.json ]]; then
  flutter pub get
fi

cleanup() {
  [[ -n "${WATCH_PID:-}" ]] && kill "$WATCH_PID" 2>/dev/null || true
  rm -f "$PID_FILE"
}
trap cleanup EXIT INT TERM

watchexec --watch lib --exts dart --debounce 300ms --postpone -- \
  bash -c '[[ -f "$1" ]] && kill -USR1 "$(cat "$1")" 2>/dev/null && echo "[hot reload]"' _ "$PID_FILE" &
WATCH_PID=$!

flutter run -d "$DEVICE" --pid-file="$PID_FILE" --no-pub