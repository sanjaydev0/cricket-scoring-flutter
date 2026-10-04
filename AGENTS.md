# Retro Arcade Cricket Utility Engine — Agent Guide

**Project:** CricScore — offline gully-cricket umpire scorer
**Repo:** https://github.com/sanjaydev0/cricket-scoring-flutter (branch `main`)
**Stack:** Flutter 3.35 / Dart 3.9 · Material 3 · `audioplayers` · `shared_preferences` · `intl`
**Config:** `opencode.jsonc` (formatter `dart format .`, linter `flutter analyze`, default agent `build`)
**Status:** v2.0.0 released · 16 tests green · `flutter analyze` clean

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
   awaits, and never fails because of, the network — see rule 7.
3. **Sound Architecture:** Arcade UI sounds (tap, boundary, wicket, extra, undo, confirm)
   play as short one-shot clips through one preloaded `audioplayers` `AudioPool` per clip
   (`AudioPool.create` at startup, `pool.start()` to fire). The pool is the module that
   hides replay/overlap: it recycles a player on completion and allocates a fresh one when
   all are busy, so rapid `4-4-6-W-6` never drops a hit. Never `stop()` + `resume()` by
   hand — `resume()` after `stop()` is a no-op and was the silence bug. Preload must be
   awaited before the first frame (`main.dart`), per-sound 150ms debounce, per-clip
   playback gains in `sound.dart` level-match the assets.
   (`soundpool` 2.4.1 was evaluated and rejected: it targets Android's removed v1
   embedding and fails Gradle compilation.)
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
  store.dart        MatchStore (ChangeNotifier) — scoring engine, undo, persistence, publish
  math.dart         CricketMath — overs, CRR/RRR, max wickets
  sound.dart        SoundService — AudioPool per clip, per-clip gain + debounce
  theme.dart        UmpireTheme, StylePreset (12), ScoreFonts (10)
  app_config.dart   AppConfig — --dart-define values (Supabase URL/key), never committed
  domain/           room_code.dart (32^5 codes), room_snapshot.dart (versioned payload)
  ports/            sync_port.dart — SyncPort + SyncState
  adapters/         supabase_sync.dart (real), local_only_sync.dart (default + FakeSync)
  screens/
    home.dart       Start / Resume / Archives + settings sections
    setup.dart      Teams (+batting-first pills), format, rules
    scoring.dart    Keypad + undo + extras; renders Scoreboard
    scoreboard.dart Scoreboard (hero tile + over strip) + OverStrip — SHARED with viewer
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
- Live rooms (Phase 1): share icon in the scoring app bar opens a room and shows its code;
  every ball publishes a full versioned snapshot; undo retracts; `Stop sharing` deletes the row.
  Viewer app and web viewer page are Phase 2+.

Layering rule: **UI never mutates state directly** — screens call `MatchStore` methods only.
Store never imports Flutter widgets (except `services.dart` for haptics).

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
9. **Write access is the database's job, not the app's:** there are no INSERT/UPDATE/
   DELETE policies on `rooms`, so RLS rejects direct writes outright (verified: anon PATCH
   returns 204 with zero rows affected). A leaked 5-character code grants read and nothing
   else.

## Commands

```bash
flutter pub get          # deps
dart format .            # formatting (enforced by opencode.jsonc)
flutter analyze          # lint — must be clean before commit
flutter test             # unit/widget tests
flutter build apk --release
flutter build web --release
adb devices -l           # confirm device (USB or wireless)
```

## Machine notes

- Flutter SDK: `~/flutter/bin` (export PATH); Android SDK `~/Android/Sdk` (v34), JDK 17.
- Wireless deploy: `adb connect <ip>:<port>` — the phone's port changes each session;
  rediscover with `avahi-browse -r _adb-tls-connect._tcp`.
- Waydroid is installed for quick Android preview but its IP is unreachable from the host;
  use `flutter build web` + `localhost:8000` for rapid UI iteration.
- Release flow: commit → push → `gh release create v<semver>` with APK → `adb install -r`.

## Rules

- NEVER hand-edit `build/`, `.dart_tool/`, `*.g.dart` (generated).
- Dart style: 2-space, format-on-save.
- Keep changes minimal; update `test/` whenever scoring logic changes.
- Commit messages: `type: short description` (feat/fix/chore).
- Ask before removing features, renaming public storage keys, or changing badge colours.

## Known gaps (open work)

- Full `DeliveryEvent` model with striker / non-striker / bowler tracking and batsman selection
  after each wicket. Current model tracks score-level state only.
- Innings scorecard with per-player and per-bowler figures.
  **Note:** these are one piece of work, not two — figures cannot be attributed to a
  player until the model knows who faced the ball and who bowled it.
- Live-room web viewer page at `/r/CODE` (the in-app read-only screen ships in v2.7).
- Club roster and career stats (needs the `DeliveryEvent` model first, plus a Postgres
  schema for `clubs` / `players` / `matches` / batting+bowling figures).

## Credits

- SFX: Kenney.nl Interface Sounds + Digital Audio (CC0)
- Fonts: Anton, Archivo Black, IBM Plex Mono, Chakra Petch, Bebas Neue, Alfa Slab One,
  Orbitron-class tech face, Barlow Condensed, Fjalla (SIL OFL)