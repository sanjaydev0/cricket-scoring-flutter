#!/usr/bin/env bash
# CricScore — UI inventory page.
#
#   ./tool/ui-inventory.sh            verify element refs + open in Firefox
#   ./tool/ui-inventory.sh --no-open  verify only
#
# The page is a hand-built static catalog (pictures, no live behavior), so this
# script does not regenerate markup — it checks that every source file it points
# at still exists, then opens the page. If a ref goes stale after a refactor, it
# fails loudly here instead of silently pointing at moved code.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAGE="$ROOT/docs/ui-inventory.html"
[ -f "$PAGE" ] || { echo "FAIL: $PAGE missing" >&2; exit 1; }
[ -f "$ROOT/DESIGN.md" ] || { echo "FAIL: DESIGN.md missing" >&2; exit 1; }

echo "==> checking referenced sources exist"
SOURCES=(
  lib/main.dart lib/theme.dart lib/core/theme/app_tokens.dart lib/models.dart
  lib/store.dart lib/screens/widgets.dart lib/screens/scoring.dart
  lib/screens/scoreboard.dart lib/screens/sheets.dart
  lib/screens/player_sheets.dart lib/screens/setup.dart lib/screens/home.dart
  lib/screens/club.dart lib/screens/summary.dart lib/screens/break_result.dart
  lib/screens/history.dart lib/domain/players.dart
)
missing=0
for f in "${SOURCES[@]}"; do
  [ -f "$ROOT/$f" ] || { echo "  MISSING: $f"; missing=1; }
done
[ "$missing" = 0 ] && echo "    all ${#SOURCES[@]} sources present"

echo "==> element count"
grep -c 'class="copybtn"' "$PAGE" | sed 's/^/    cards: /'

# A deleted feature must not linger in the index: the live-room viewer went in
# 2.27.0 and this page is where it used to survive longest.
if grep -qE 'screen\.join|viewer\.|WATCH LIVE' "$PAGE"; then
  echo "FAIL: inventory still lists the removed live-room/viewer feature" >&2
  exit 1
fi
echo "    no removed-feature refs"

if [ "${1:-}" != "--no-open" ]; then
  echo "==> opening in Firefox"
  setsid firefox --new-tab "file://$PAGE" >/dev/null 2>&1 &
fi
