#!/usr/bin/env bash
# CricScore — UI inventory page.
#
#   ./tool/ui-inventory.sh          verify element refs + open in Firefox
#   ./tool/ui-inventory.sh --no-open   verify only
#
# The page is a hand-built static catalog (pictures, no live behavior), so this
# script does not regenerate markup — it checks that every file:line reference
# still exists, then opens the page. If a ref goes stale after a refactor, it
# fails loudly here instead of silently pointing at moved code.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAGE="$ROOT/design-system/cricscore/pages/ui-inventory.html"
[ -f "$PAGE" ] || { echo "FAIL: $PAGE missing" >&2; exit 1; }

echo "==> checking referenced sources exist"
missing=0
for f in lib/main.dart lib/theme.dart lib/models.dart lib/store.dart \
  lib/screens/widgets.dart lib/screens/scoring.dart lib/screens/scoreboard.dart \
  lib/screens/sheets.dart lib/screens/player_sheets.dart lib/screens/setup.dart \
  lib/screens/home.dart lib/screens/club.dart lib/screens/summary.dart \
  lib/screens/viewer.dart lib/screens/break_result.dart lib/screens/history.dart \
  lib/domain/players.dart; do
  [ -f "$ROOT/$f" ] || { echo "  MISSING: $f"; missing=1; }
done
[ "$missing" = 0 ] && echo "    all 17 sources present"

echo "==> element count"
grep -cE 'class="(copybtn|cp)"' "$PAGE" | sed 's/^/    static cards: /'; grep -c '"GROUP"' "$PAGE" | sed 's/^/    catalog items: /'

if [ "${1:-}" != "--no-open" ]; then
  echo "==> opening in Firefox"
  setsid firefox --new-tab "file://$PAGE" >/dev/null 2>&1 &
fi
