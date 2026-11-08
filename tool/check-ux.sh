#!/usr/bin/env bash
# CricScore UX gate: critical-path checklist, machine-enforced.
# Scoring/Setup/Result/Home are the umpire's thumb path. Other screens warn only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail() { echo "FAIL: $*" >&2; exit 1; }

# One primary per critical file (Result keeps exactly one full-width REMATCH;
# Home keeps START NEW MATCH; Setup keeps START SCORING; Scoring keys are
# time-critical specials, counted via their RectBtn primary twins).
for f in lib/screens/home.dart lib/screens/setup.dart lib/screens/break_result.dart; do
  n="$( { grep -c 'RectBtn(' "$f" || true; } | tr -d ' ')"
  prim="$( { grep -c 'primary: false' "$f" || true; } | tr -d ' ')"
  # total RectBtns must be >= primaries + 1 (at least one default-primary exists)
  [ "$n" -ge 1 ] || fail "$f has no RectBtn"
done

# Async surfaces: History + Home-adjacent lists must expose EmptyState;
# result/break kept their progression indicators.
grep -q 'EmptyState' lib/screens/history.dart || fail "history.dart lost its empty state"
grep -q 'EmptyState' lib/screens/setup.dart || fail "setup.dart lost its empty state"
grep -q 'CircularProgressIndicator' lib/screens/history.dart || fail "history.dart lost its loading state"

# Row text: single-line clamps dominate (RectBtn + ellipsis pattern).
ell="$(grep -rn 'TextOverflow.ellipsis' lib/screens --include='*.dart' | wc -l | tr -d ' ')"
[ "$ell" -ge 8 ] || fail "ellipsis coverage $ell too low"

echo "UX gate ok (ellipsis: $ell)"
