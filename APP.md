# CricScore — App Anchor

Version: 2.27.0

> **How to read this:** this file is the memory of what CricScore *is*.
> Read it before touching scoring, persistence, sound, or screens.
> If it disagrees with code, the code is right and this file is wrong —
> fix this file in the same commit.

## What it is

CricScore is a 100% offline gully-cricket umpire scorer for Android and
Linux desktop. It scores one ball at a time, keeps a live scorecard with
optional per-player figures, archives finished matches on the device, and
backs them up to `Downloads/CricScore/cricscore-backup.json`. There is no
account, no server, and no network permission.

## Scoring invariants

- Score is derived from the ball sequence; never mutate totals directly.
- One method owns the Laws: `InningsSheet.applyDelivery`
  (`lib/domain/players.dart`); over ends via `closeOver`.
- Overs roll at 6 legal balls; the completed over stays visible until the
  next ball (deferred rollover).
- Extras never consume a legal ball. Run-outs with runs record as `W+n`.
  Wicket-grid "WICKET" records as Bowled ("b Ravi" on the card); run-out is
  two sheets — facts, then next batter — scored only after a pick (skipped
  on last ball / last wicket / chase won).
- Free hit protects all dismissals except run-out; consumed on the next
  legal delivery. Bowler changes go through `MatchStore.setBowler`
  (no consecutive overs).
- UI never mutates state — screens call `MatchStore` only. The store never
  imports widgets (except `services.dart` for haptics).

## Screens (routes in `lib/main.dart`)

- `/` Home: Start / **Rematch** (session-first, archive-fallback) / Resume / Archives,
  settings (sound, haptics, dark mode, ask-fielder, **battery saver**), data backup.
- `/setup`: teams, batting-first, format, squad XIs (when tracking is on).
- `/scoring`: keypad, undo, extras, over strip, hero scoreboard.
- `/break` / `/result`: 10-second handoff with NEXT; awards, WhatsApp share,
  full-width REMATCH primary + HOME / NEW MATCH secondaries, all single-line.
- `/history`: archives list → `ArchiveDetail` (one innings at a time + SUMMARY).
- `/club`: profiles (local PIN), clubs, roster, career figures.

## Data keys (`shared_preferences`, source of truth)

`cricket_active_match_v4` (live match), `cricket_sheets_v1` (live sheets),
`cricket_history_vault_v4` (archives as `{match, sheets, savedAt}`),
`cricket_roster_v1`, `cricket_clubs_v1`, `cricket_profiles_v1`,
`cricket_battery_saver` (setting). Backup copies every `cricket_*` key;
`userDataKeys` decides whether a snapshot is worth restoring.

## Battery discipline

- `_persist()` writes match + sheets immediately; roster/clubs/profiles
  only when dirty. Silent backup floor is 60 s (not mid-over); pause,
  over-end, and archive back up for real.
- SoLoud lazy-boots on first sound; sound-OFF never inits; `suspend()` on
  app pause stops voices.
- Battery Saver (Home toggle, default OFF): celebrations forced `off`,
  silent backup only when forced. Brightness and animation primitives
  (`Transform`/`Opacity`) never change — glare-first wins.

## Active decisions

- **No live rooms.** The entire sync layer (viewer, room codes, Supabase
  backend, share button, INTERNET permission) was removed. Do not
  re-add network code without a new design review.
- **Archives keep sheets.** A tracked match must archive with its sheets.
  Deleting one archive must never strip another's cards.
- **Design rules live in `DESIGN.md`.** Read it before any UI change.

## Commands

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter analyze --no-pub      # must be clean
flutter test --no-pub         # unit/widget tests
bash tool/check-master.sh     # anchor word count + version match
./tool/release.sh VER "notes" # versioned universal APK + tag + install
./tool/fast-install.sh [serial] # arm64 dev install only
```

Keep this file under 1,000 words. Update the relevant section and bump
`pubspec.yaml` in the same commit as any feature change.
