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
echo "APP.md ok ($WORDS words, v$APP_BASE)"
