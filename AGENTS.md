# Retro Arcade Cricket Utility Engine — Agent Guide

**Project:** CricScore — offline gully-cricket umpire scorer
**Repo:** https://github.com/sanjaydev0/cricket-scoring-flutter (branch `main`)
**Stack:** Flutter 3.47.7 / Dart 3.13.5 · Material 3 · `flutter_soloud` · `shared_preferences` · `intl` · `supabase_flutter`
**Config:** `opencode.jsonc` (default agent `build`, formatter `dart`, no linter)
**Verification:** run `flutter analyze --no-pub` and `flutter test`; do not record counts here.

---

## Role & Engineering Standards

You are an expert Flutter/Dart systems architect. You build deterministic, 100% offline-first
Android apps using Material Design 3 and retro arcade UI patterns.

## Technical Rules

1. **Zero Placeholders:** Provide complete, runnable code files. Include all imports, models and
   error handling. Never output `// TODO`, `...`, or truncated logic.
2. **Offline-First:** All assets (fonts, audio, state) must work without network connectivity.
   No runtime font/CDN fetches, no Firebase. Fonts and SFX are bundled in
   `assets/fonts/` and `assets/audio/`.
   **Exception — live rooms (opt-in):** sharing a read-only score view with another
   phone is the one network feature. It is additive and strictly optional: no Supabase
   keys at build time means the app is exactly the offline app it was. Scoring never
   awaits, and never fails because of, the network — see rule 8.
3. **Sound Architecture:** Arcade UI sounds (tap, boundary, wicket, extra, undo, confirm)
   play as short one-shot clips through `SoundService`, backed by `flutter_soloud` 5.2.1.
   - Initialize SoLoud once with low latency and `bufferSize: 1024`.
   - Preload every `.ogg` asset once at startup (`main.dart`).
   - Fire with `play(source, volume: perClipGain)`; the mixer handles overlap.
   - Use a 150 ms per-clip debounce so rapid `4-4-6-W-6` does not drop hits.
   - Per-clip playback gains live in `sound.dart` and level-match the assets.
   - Audio failure is silent; scoring must work with no sound device.
   - Do not use `audioplayers`, `AudioPool`, or `resume()` after `stop()`.
4. **Cricket Domain Rules:**
   - Score is derived from the sequence of ball deliveries; never mutate score fields directly.
   - Deliveries record: runs, extras (wide, no-ball, bye, leg-bye), wicket type (bowled, caught,
     run-out, lbw, stumped, hit-wicket), plus match-level rules.
   - Overs roll at 6 legal deliveries; **the completed over stays visible until the next delivery
     is recorded** (deferred rollover).
   - Extras never consume a legal ball; wides and no-balls are illegal deliveries.
   - Run-outs with completed runs record as `W+n` (e.g. `W+2`) and count those runs.
   - Free hit protects all dismissals except run-out; consumed by the next legal delivery.
   - Custom rules supported: overs limit, players per side, double-side player (odd-man), wide
     penalty, no-ball penalty, free hit, last-man-standing.
5. **Glare-first visuals:** solid saturated fills, near-black/white text only, no pastels, no
   low-contrast greys. Every screen must stay readable in direct sunlight.
6. **Animation safety:** celebrations may only use `Transform`, `Opacity`, `ShaderMask`,
   `TextStyle` colour/shadow, or `Positioned` overlays. Nothing may change layout size — runs and
   wickets numerals animate independently, never the score tile.

## Architecture

```
lib/
  main.dart         MaterialApp, light/dark, routes; picks the SyncPort from AppConfig
  models.dart       Rules, MatchConfig (+battingFirst), Ball, Over, Innings, Match
  store.dart        MatchStore (ChangeNotifier) — persistence, settings, sync adapter, delegates scoring
  scoring_engine.dart ScoringEngine — live match/sheets/counters, break timer, side effects
  undo_log.dart     UndoEnvelope — on-disk undo snapshot shape
  math.dart         CricketMath — overs, CRR/RRR, max wickets
  sound.dart        SoundService — SoLoud mixer, preload + per-clip gain/debounce
  theme.dart        UmpireTheme, StylePreset (12), ScoreFonts (10)
  app_config.dart   AppConfig — --dart-define values (Supabase URL/key), never committed
  domain/           room_code.dart (32^5 codes), room_snapshot.dart (versioned payload)
  domain/players.dart Player/Club/ClubProfile, DismissalType, BattingCard,
                      BowlingCard, FieldingCard, InningsSheet, Career aggregates
  ports/            sync_port.dart — SyncPort + SyncState
  adapters/         supabase_sync.dart (real), local_only_sync.dart (default + FakeSync)
  screens/
    home.dart       Start / Resume / Archives + settings sections
    setup.dart      Teams (+batting-first pills), format, rules
    scoring.dart    Keypad + undo + extras + PLAYERS button; renders Scoreboard
    player_sheets.dart dismissal (one-tap), bowler picker, stats sheet, openers
    club.dart       profiles (local PIN), clubs, roster + search + career stats
    summary.dart    scorecard tables, awards, player-of-match, WhatsApp share
    scoreboard.dart Scoreboard (hero tile + over strip) — SHARED with viewer
    viewer.dart     ViewerScreen (read-only live view), JoinRoomScreen (enter a code)
    sheets.dart     wicket/run-out dialogs, overs, extras, match settings, look sheet
    break_result.dart (undo-safe route guards), history.dart (dated archives + detail)
    widgets.dart    RectBtn, TeamDot, StepperRow, BallBadge, KeyBtn, Celebrate
```

Current feature inventory (keep compatible unless asked):
- 12 style presets: Umpire Pro, Solar Flare, Pure White, Crimson Court, iOS Frost,
  Nothing Mono, Vercel Ink, Router Paper, Linear Dusk, CRT Phosphor, Neon Cabinet, Game Boy
- 10 score fonts (bundled OFL) + 9 celebrations (Off, Pop, Flash, Glow, Shake, Blink,
  Glitch, CRT, Slow-Mo) — numerals-only, layout-frozen, split runs/wickets
- Run-out badges read `W+n`; complex/simple wicket toggle; double-side player None/One;
  advanced-extras master switch; declare-winner + abandon flows
- Deferred over rollover; 900ms strip glide; fade on forward rollover only, never on undo
- Player names are rows, never pills: every name picker renders compact rows
  (name left, radio/check right) via one shared row layout. Chips stay only for
  non-name toggles (dismissal types, styles).
- Squad rules live in the store, never just the UI: XI cap = playersPerSide,
  cross-XI exclusion waived only for the shared pick when a common player is
  allowed, duplicates warn and are never created, mid-match removal only when
  uncapped.
- Laws: `InningsSheet.applyDelivery` for balls, `closeOver` for over ends.
  Bowler changes go through `MatchStore.setBowler`, which enforces the consecutive-over law.
  Retired-out falls a team wicket; retired-hurt does not. Free-hit and armed no-ball
  route wicket flows to run-out only.
- Live rooms (Phase 1): share icon in the scoring app bar opens a room and shows its code;
  every ball publishes a full versioned snapshot; undo retracts; `Stop sharing` deletes the row.
  Viewer app is Phase 2+.

Layering rule: **UI never mutates state directly** — screens call `MatchStore` methods only.
Store never imports Flutter widgets (except `package:flutter/services.dart` for haptics).

Live rooms add three more layers, so online code never leaks into scoring:

```
lib/domain/     pure Dart, no Flutter — room_code, room_snapshot
lib/ports/      interfaces only — sync_port.dart (SyncPort)
lib/adapters/   the only files importing supabase_flutter — supabase_sync, local_only_sync
supabase/       migrations/*.sql + README.md (the setup steps a human must do)
```

7. **Live rooms use a secret capability, not Supabase Auth.** Anonymous
   sign-ins are disabled by default on a fresh project, and a scoring app should
   not carry a token refresh cycle to save a snapshot. The room code grants
   reads; a 160-bit secret in `room_secrets` (RLS on, no policies, revoked from
   anon/authenticated) grants writes via the `room_publish` / `room_end`
   `security definer` functions. `room_secrets` must stay unreachable from any
   client role — verified: 401.
8. **Sync is fire-and-forget:** `MatchStore._publishRoom()` calls `sync.publish` without
   awaiting and swallows the rejection on the *future* (a `try` around the call cannot
   see an async throw). A dead backend may cost the live room and nothing else — never a
   ball, never an undo, never persistence. Test that with `FakeSync.publishError`.
9. **Release builds need INTERNET declared in `android/app/src/main/AndroidManifest.xml`.**
   Flutter only adds it to the debug and profile manifests, so a release APK is
   network-dead while `flutter run` works — which hid the live-rooms failure for
   several releases. If a network feature ever stops working only in release,
   dump the merged manifest (`aapt2 dump permissions`) before anything else.
10. **Never pre-encode a jsonb payload.** `p_payload` takes the Dart Map
   directly; sending `jsonEncode(...)` makes PostgREST store a jsonb *string*
   scalar, and readers must then guess whether a payload is a map or a string.
   `RoomSnapshot.fromPayload` tolerates both because that bug shipped once.
11. **Write access is the database's job, not the app's:** there are no INSERT/UPDATE/
   DELETE policies on `rooms`, so RLS rejects direct writes outright (verified: anon PATCH
   returns 204 with zero rows affected). A leaked 5-character code grants read and nothing
   else.

## Context policy (model-agnostic)

Classify every path before opening it:

- BINARY → metadata only
- GENERATED → never
- LOCK → grep only
- SOURCE → task scope
- REFERENCE → on demand
- NOISE → never

Rules:

- grep/glob only with `path:` = `lib`, `test`, `tool`, or one feature dir.
- Never pass `build`, `.dart_tool`, `.agents`, `.git`, `design-system`, or `assets` as `path:`.
- `pubspec.lock` and `.flutter-plugins-dependencies`: grep only, never read wholesale.
- `assets/` is binary: use `ls`, `file`, or `du`; one screenshot only for a visual bug.
- Read ±60 lines around a symbol, not a whole file.
- Never rewrite a whole file to change part of it; use `edit`.
- Never edit `*.g.dart` or `*.freezed.dart`.
- If blocked by an excluded path, name it, use the narrowest lookup, then ask.

## Change router

| Change | Read first | Test |
|---|---|---|
| Scoring law | `domain/players.dart` (`applyDelivery`, `closeOver`), `scoring_engine.dart`, `store.dart` (`setBowler`), `models.dart` | `store_test`, `match_sim_test`, `players_test` |
| UI / screen | `screens/<target>.dart`, `theme.dart`, `widgets.dart`, route in `main.dart` | `design_test`, `screens_layout_test` |
| Persistence / undo | save/load in `store.dart`, `undo_log.dart`, `backup.dart` | `backup_test`, `store_test` |
| Live room | `ports/sync_port.dart`, `adapters/supabase_sync.dart`, `domain/room_*`, `supabase/migrations/` | `room_test`, `viewer_test` |
| Sound | `sound.dart`, preload in `main.dart`, `assets/audio/` | `sound_test` |
| Release / APK | `tool/release.sh`, manifest, `gradle.properties`, `pubspec.yaml` | full analyze + test |

## Verification ladder

```bash
export PATH="$HOME/flutter/bin:$PATH"
dart analyze lib
flutter analyze --no-pub
flutter test --no-pub --reporter compact test/<target>_test.dart
git diff --stat && git diff -- <file>
```

No `flutter run`, build, APK, or full test suite unless the task is the daily Linux loop, release/deploy, or explicitly requested.

## Workflow: Linux first, APK last

Iterate on the **Linux desktop** build; cut an APK only once features and UI have settled.
Linux preview is the lowest-RAM loop; APK builds are 10-20 minutes.

```bash
# Daily UI loop: Linux desktop + watchexec auto hot reload
./tool/flutter-live.sh linux

# Release: only when feature/UI work is done
./tool/release.sh 2.9.0 "notes"
```

**What the Linux loop cannot check** — these are part of "done" at release, not optional:
sounds (verify on Linux/Android), haptics (absent on desktop), and anything release-only
(see the INTERNET-permission rule above).

**Only one compile at a time.** A Gradle daemon can hold 2.4 GB, so a parallel
build on this 7.6 GB box can die with `Could not start thread: Resource
temporarily unavailable`. `tool/release.sh` refuses to run while a `flutter run`
dev server is alive.

## Commands

```bash
flutter pub get          # deps
dart format .            # formatting
flutter analyze --no-pub # lint — must be clean before commit
flutter test --no-pub    # unit/widget tests
./tool/flutter-live.sh linux
./tool/release.sh VER NOTE  # analyze, test, pre-flight, apk, install, gh release
flutter build apk --release
$HOME/Android/Sdk/platform-tools/adb devices -l
```

## Machine notes

- Flutter SDK: `~/flutter/bin` (export PATH); Android SDK `~/Android/Sdk`, JDK 17.
- Flutter is on a 3.47 candidate branch. Do not upgrade or switch channels mid-task.
- Zed binary is `zeditor`; watchexec 2.8 drives hot reload.
- Web is not a target: the repo has no `web/` directory. Android APK + Linux desktop only.
- Wireless deploy: `adb connect <ip>:<port>` — the phone's port changes each session;
  rediscover with `avahi-browse -r _adb-tls-connect._tcp`.
- Use `$HOME/Android/Sdk/platform-tools/adb`, not `/usr/bin/adb`.
- Waydroid is installed but its IP is unreachable from the host; Linux desktop is the preview path.
- Release flow: `./tool/release.sh <version> "<notes>"` — analyze, test, pre-flight gate, APK,
  tag/release, install. It refuses a duplicate tag and a live dev server.
- The pre-flight gate is not optional ceremony: it asserts `INTERNET` +
  `ACCESS_NETWORK_STATE` in the **merged release manifest** and that the
  Supabase keys are baked into `libapp.so`. Both faults are invisible in debug.
- Low-RAM Gradle settings: 2 GB heap, daemon off, parallel off, VFS watch off, 2 workers.
  Close memory-heavy apps before an APK build and run `free -h` first.

## Data preservation (critical)

- **NEVER `adb uninstall`, `pm clear`, or "reinstall to fix".** The only copy of the
  club, roster, live match and archives lives in app storage; uninstalling deletes it.
- Update with `adb install -r` only. Run `./tool/safe_update.sh` first: it pulls the
  on-device backup to `~/backups/cricscore/`, installs over the top, and prints the
  `STORE:` boot line.
- The app writes two snapshots after every change (10 s floor):
  `/sdcard/Android/data/com.gully.cricket.cricket_scoring/files/backups/cricscore-backup.json`
  and `/sdcard/Download/CricScore/cricscore-backup.json`. The public copy is updated
  in place; MediaStore may have renamed it to `cricscore-backup (N).json`, and the
  app reads any of those names.
- Fresh install: install, then `./tool/restore_backup.sh <newest.json>` before the
  first launch. It pushes the app-specific copy, so auto-restore is automatic.
- If only the public copy remains, Android scoped storage can stop a new install
  from reading it. The app then shows `RESTORE A BACKUP?`; tap
  `RESTORE FROM FILE…` and pick `Downloads/CricScore/cricscore-backup.json`.
  Never promise an unattended restore from Downloads alone.
- When uninstalling through Android Settings, choose **Keep app data** if offered
  (`hasFragileUserData`). `adb uninstall` still deletes everything.
- The app auto-restores only when no `cricket_*` preference exists, so it can never
  overwrite a live store. Existing data is replaced only via Settings → Data backup.
- Verify after every install:
  `adb logcat -d | grep "STORE:"` → either `roster=N clubs=N ... match=...` or
  `restored backup ...` with the expected counts.
- Backup format is versioned (`BackupSnapshot.format`, currently 1). Keep older
  versions readable; never change a preference key without migrating its backup.
- A backup failure must never block scoring or boot. Prefs remain the source of truth.

## Rules

- NEVER hand-edit `build/`, `.dart_tool/`, `*.g.dart` (generated).
- Dart style: 2-space, format-on-save.
- Keep changes minimal; update `test/` whenever scoring logic changes.
- Commit messages: `type: short description` (feat/fix/chore).
- Ask before removing features, renaming public storage keys, or changing badge colours.

## Player tracking (shipped)

- `Ball` carries nullable `strikerId/nonStrikerId/bowlerId/fielderName`: old saves
  decode untouched, tracked balls attribute. `MatchConfig.trackPlayers` (default
  OFF) + `squadA/squadB` select XIs from the CLUB roster.
- One method owns the Laws: `InningsSheet.applyDelivery`. UI never attributes.
- Undo snapshots carry `{match, sheets}` envelopes; legacy plain-match entries
  still decode. New batter joins in the same commit as the wicket.
- Overs stored as balls, displayed `4.3`-style; undefined stats render `—`.
- Fielder picker (caught/stumped/run-out) is optional behind `askFielder`
  (default OFF); scorecards degrade gracefully (`c b Ravi`, `run out`).

## Known gaps (open work)

- Innings scorecard with per-player and per-bowler figures.
- Club roster and career stats (needs the `DeliveryEvent` model first, plus a Postgres
  schema for `clubs` / `players` / `matches` / batting+bowling figures).

## Credits

- SFX: Kenney.nl Interface Sounds + Digital Audio (CC0)
- Fonts: Anton, Archivo Black, IBM Plex Mono, Chakra Petch, Bebas Neue, Alfa Slab One,
  Orbitron-class tech face, Barlow Condensed, Fjalla (SIL OFL)