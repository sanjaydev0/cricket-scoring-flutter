#!/usr/bin/env bash
# CricScore anchor + design gate. Runs inside tool/release.sh.
#
# Two jobs:
#   1. APP.md stays short and in sync with pubspec.yaml.
#   2. The daylight rules in DESIGN.md stay true of the code, so the doc cannot
#      drift back into advice the app does not follow.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# ---- 1. Anchor ------------------------------------------------------------
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

# ---- 2. Design system -----------------------------------------------------
# One normative doc. The old design-system/ tree shipped a generated web
# template whose rules overrode DESIGN.md, which is how agents ended up writing
# Google Fonts CDN imports and backdrop blurs into an offline Flutter app.
[ -f DESIGN.md ] || { echo "FAIL: DESIGN.md missing" >&2; exit 1; }
if [ -d design-system ]; then
  echo "FAIL: design-system/ is back — DESIGN.md is the only design doc" >&2
  exit 1
fi
# The roles named in DESIGN.md must exist in the token layer.
for ROLE in primaryFill onPrimaryFill surfaceOutline borderRow lockedFill \
            lockedInk statGoodInk statGoodFill statWarnInk scaffoldBg surface \
            onSurface mutedInk eventWicket eventSix eventFour eventWide \
            eventNoBall eventBye eventDot; do
  grep -q "$ROLE" lib/core/theme/app_tokens.dart || {
    echo "FAIL: DESIGN.md names '$ROLE' but app_tokens.dart has no such role" >&2
    exit 1
  }
done

# Softer-rule token gate: Home + Result must stay free of raw hex colors;
# the whole screens tree must not grow raw-color debt past baseline.
HOME_RAW="$( { grep -c 'Color(0x' lib/screens/home.dart lib/screens/break_result.dart 2>/dev/null || true; } | awk -F: '{s+=$NF} END {print s+0}')"
if [ "$HOME_RAW" != "0" ]; then
  echo "FAIL: home/result carry $HOME_RAW raw Color(0x — use context.tokens/context.colors" >&2
  exit 1
fi
TOTAL_RAW="$(grep -rn 'Color(0x' lib/screens --include='*.dart' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$TOTAL_RAW" -gt 10 ]; then
  echo "FAIL: screens raw Color(0x count $TOTAL_RAW exceeds baseline 10 — tokens, not hex" >&2
  exit 1
fi

# The Locked-Not-Faded Rule: no text is dimmed by multiplying its ink alpha.
# A 45%-alpha name is a smudge at 10,000 lux; locked rows get lockedFill +
# lockedInk. (Opacity on white ink over a saturated fill is allowed and is not
# matched here.)
DIM="$(grep -rn 'onSurface\.withValues(alpha:' lib/screens --include='*.dart' 2>/dev/null || true)"
if [ -n "$DIM" ]; then
  echo "FAIL: text dimmed by ink alpha — use onSurfaceVariant or lockedInk/lockedFill:" >&2
  echo "$DIM" | head -n 10 >&2
  exit 1
fi

# Bright green/amber as bare text on a surface is 2.1–2.2:1 in daylight. Use
# statGoodInk / statGoodFill / statWarnInk.
BRIGHT="$(grep -rn '0xFF22C55E\|0xFFF59E0B\|0xFF16A34A' lib/screens --include='*.dart' 2>/dev/null || true)"
if [ -n "$BRIGHT" ]; then
  echo "FAIL: bare bright green/amber in screens — use statGoodInk/statWarnInk:" >&2
  echo "$BRIGHT" | head -n 10 >&2
  exit 1
fi

# ---- 3. One kit, no stock Material chrome --------------------------------
# Every button, card, row and app bar in the screen layer comes from
# lib/screens/widgets.dart. Stock Material widgets bring their own pill
# silhouettes, drop shadows and 38%-alpha disabled states, which the Daylight
# rules ban — and one stray Card is how the old chrome creeps back.
# scoreboard.dart and scoring.dart are allowlisted on purpose: the hero tile
# and the keypad are the arcade surface and are not rebuilt.
STOCK="$(grep -rnE '\b(Card|ListTile|SwitchListTile|ExpansionTile|FilledButton|ElevatedButton|OutlinedButton|TextButton)\(' \
  lib/screens --include='*.dart' 2>/dev/null \
  | grep -v '^lib/screens/widgets.dart:' \
  | grep -vE '^lib/screens/(scoreboard|scoring)\.dart:' || true)"
if [ -n "$STOCK" ]; then
  echo "FAIL: stock Material chrome in the screen layer — use the kit in lib/screens/widgets.dart:" >&2
  echo "$STOCK" | head -n 10 >&2
  exit 1
fi

# A preset owns the hero tile, the keys and the two style swatches. Nothing
# else may read one: picking Game Boy must not turn the club roster green.
# home.dart and sheets.dart are allowed the picker itself (StylePreset.ids to
# list the presets, StylePreset.of for the swatch colour) and nothing more.
PRESET="$(grep -rn 'StylePreset' lib/screens --include='*.dart' 2>/dev/null \
  | grep -vE '^lib/screens/(scoreboard|scoring)\.dart:' \
  | grep -vE '^lib/screens/(home|sheets)\.dart:.*StylePreset\.(of|ids)' || true)"
if [ -n "$PRESET" ]; then
  echo "FAIL: StylePreset read outside the score surface (scoreboard, keypad, style swatches):" >&2
  echo "$PRESET" | head -n 10 >&2
  exit 1
fi

echo "APP.md ok ($WORDS words, v$APP_BASE) + token gate ok (raw colors: $TOTAL_RAW/10) + chrome gate ok (kit only, no preset leak)"
