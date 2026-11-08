#!/usr/bin/env bash
# CricScore anchor check: APP.md stays short and in sync with pubspec.yaml.
# Fails release if the anchor drifts or swells past its budget.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[ -f APP.md ] || { echo "FAIL: APP.md missing" >&2; exit 1; }
WORDS="$(wc -w < APP.md | tr -d ' ')"
if [ "$WORDS" -ge 1000 ]; then
  echo "FAIL: APP.md has $WORDS words (>= 1000) — trim it" >&2
  exit 1
fi
PUBSPEC_VER="$(sed -n 's/^version: *//p' pubspec.yaml | head -n 1)"
PUBSPEC_BASE="${PUBSPEC_VER%%+*}"
APP_VER="$(sed -n 's/^Version: *//p' APP.md | head -n 1 | tr -d '[:space:]')"
APP_BASE="${APP_VER%%+*}"
if [ -z "$APP_BASE" ]; then
  echo "FAIL: APP.md has no 'Version:' line" >&2
  exit 1
fi
if [ "$PUBSPEC_BASE" != "$APP_BASE" ]; then
  echo "FAIL: APP.md version $APP_BASE != pubspec $PUBSPEC_BASE" >&2
  exit 1
fi
# Softer-rule token gate: Home + Result must stay free of raw hex colors;
# the whole screens tree must not grow raw-color debt past baseline.
HOME_RAW="$( { grep -c 'Color(0x' lib/screens/home.dart lib/screens/break_result.dart 2>/dev/null || true; } | awk -F: '{s+=$NF} END {print s+0}')"
if [ "$HOME_RAW" != "0" ]; then
  echo "FAIL: home/result carry $HOME_RAW raw Color(0x — use context.tokens/context.colors" >&2
  exit 1
fi
TOTAL_RAW="$(grep -rn 'Color(0x' lib/screens --include='*.dart' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$TOTAL_RAW" -gt 64 ]; then
  echo "FAIL: screens raw Color(0x count $TOTAL_RAW exceeds baseline 64 — tokens, not hex" >&2
  exit 1
fi
echo "APP.md ok ($WORDS words, v$APP_BASE) + token gate ok (raw colors: $TOTAL_RAW/64)"
