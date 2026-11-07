# Offline-First Purge + Battery Saver + Anchor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make CricScore provably offline, stop tracked archives losing player cards, cut per-ball battery churn with an opt-in Battery Saver, and add an auto-checked anchor file.

**Architecture:** Fix archives at the raw-record layer (no re-encode), throttle `_persist()`/`_maybeBackup()`/audio at the store edge, split one scoring `ListenableBuilder` when saver is on, excise the entire sync layer so no socket can exist, and guard the anchor with a release check.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13.5, `shared_preferences`, `flutter_soloud` (lazy), `intl`. No new dependencies; `supabase_flutter` removed in Task 4.

**Spec:** Consolidated chat design approved in-session 2026-11-07: rule+check anchor, full live-room excision, surgical archives fix + proof tests, always-on throttles + opt-in Battery Saver (split builders, celebrations off), version 2.26.1 → 2.27.0.

## Global Constraints

- Offline-first: scoring never awaits network; no runtime fetches.
- `pubspec.yaml` version bump and `APP.md` version line must match (`2.27.0+<build>`); `APP.md` < 1,000 words.
- No new prefs keys that rename public storage; one additive key `cricket_battery_saver` only.
- Live-room paths must be unrecoverable by grep after Task 4 (except intentional comments about removal).
- Battery work must not dim glare-first visuals, change animation primitives (`Transform`/`Opacity` only), or drop backups.
- Verify every task with `flutter analyze --no-pub` and targeted tests; do not run full suite except final check.

## Review Focus

- Archive deletion of an old envelope without `sheets` — must delete cleanly, never throw, never strip survivor sheets.
- Store with prefs read failure (`_persistBlocked`) — throttled persist must still skip all writes.
- Battery Saver ON during a boundary — celebration must not fire, score must still update and persist.
- Sound OFF from boot — audio engine must never init; first SFX when ON must still play.
- No leftover `sync`/`Supabase`/`ShareAttempt` reference — a fresh `flutter analyze` must pass with deps pruned.

---

### Task 1: Archives fix — preserve sheets on delete

**Files:**
- Modify: `lib/store.dart:130,2017-2033`
- Test: `test/store_test.dart` (append)

**Interfaces:**
- Consumes: `MatchStore.historyRecords()`, `MatchStore.sheetsFromRecord(Map)`, `InningsSheet.toJson/fromJson`
- Produces: `static const userDataKeys` includes `kSheets`; `deleteHistoryAt` operates on raw records. Signature unchanged: `Future<void> deleteHistoryAt(int idx)`.

- [ ] **Step 1: Write the failing tests**

Add to `test/store_test.dart` using existing fake prefs harness:
`archivedTrackedMatchKeepsSheetsAfterDelete` — seed `kHistory` with two records (match+sheets), call `deleteHistoryAt(0)`, assert `sheetsFromRecord(remaining)` is non-empty and `names` contains first batter.
`archiveRoundTripSheetsSurvive` — build rec via `match.toJson()+sheets`, round-trip through `historyRecords`/`sheetsFromRecord`, assert batting runs match.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub --reporter compact test/store_test.dart -t "archivedTrackedMatchKeepsSheetsAfterDelete"`
Expected: FAIL (survivor sheets stripped — current impl re-encodes via `Match.toJson()`).

- [ ] **Step 3: Implement in `lib/store.dart`**

Change `userDataKeys` to `[kActive, kHistory, kSheets, kRoster, kClubs, kProfiles]`.
Rewrite `deleteHistoryAt` to: read raw via `historyRecords()`, bounds-check, `removeAt(idx)`, `jsonEncode(rawList)`, write to `kHistory`, `notifyListeners()`. Never call `history()`/`Match.toJson()` on this path.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test --no-pub --reporter compact test/store_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/store.dart test/store_test.dart
git commit -m "fix: preserve archive sheets on delete"
```

---

### Task 2: Battery always-on — throttle persist, backup, audio

**Files:**
- Modify: `lib/store.dart:584-631,467-485,226-235,640-700, load()`
- Modify: `lib/sound.dart:59-110`
- Test: `test/store_test.dart` (dirty-flag + backup-floor assertions)

**Interfaces:**
- Consumes: Task 1 `userDataKeys`; `_persist()`, `_maybeBackup()`, `_warmAudio(bool)`, `SoundService.init(enabled:)`, `setEnabled(bool)`
- Produces: `bool batterySaver` field (default false, set in Task 3), `_rosterDirty/_clubsDirty/_profilesDirty` flags (private), `setBatterySaver(bool)`, `suspendAudio()` hook, `_maybeBackup({bool force})` floor 10s → 60s.

- [ ] **Step 1: Write the failing test**

`persistSkipsUnchangedRoster` — after load with non-empty roster, call a ball-path persist (e.g. `setSound` toggle), assert `kRoster` string unchanged (spy via `SharedPreferences.setString` intercept or pre/post read equality). `backupFloorIsThrottled` — two `_maybeBackup()` calls 20s apart trigger only one `backupNow` (mock or count via `_lastBackupAttempt`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub --reporter compact test/store_test.dart -t "persistSkipsUnchangedRoster"`
Expected: FAIL (current impl rewrites roster every persist).

- [ ] **Step 3: Implement throttles**

In `store.dart`: add dirty flags set at every roster/clubs/profiles mutation (`addProfile`, `addClub`, `addPlayer`, removes, load sets them false, `_applyBackup` sets true). `_persist()` always writes match/undo/theme/sheets/appearances; writes roster/clubs/profiles only if flag true then clears. Change `_maybeBackup` floor to 60s; call sites that force backup (archive, over-end) pass `force:true`. `_warmAudio` returns early if `!enabled` (never inits); `load()` only warms when `soundOn==true`.
In `sound.dart`: make `init` idempotent and lazy (no eager preload in store boot); add `suspend()` that stops voices and keeps sources (no engine teardown). `_play` no-ops when `!enabled`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub --reporter compact test/store_test.dart test/sound_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/store.dart lib/sound.dart test/store_test.dart
git commit -m "perf: throttle persist, backup, and audio boot"
```

---

### Task 3: Battery Saver toggle + split scoring builders

**Files:**
- Modify: `lib/store.dart` (key, field, setter, load, `_persist`, `_maybeBackup` saver branch)
- Modify: `lib/screens/home.dart:450-472` (saver switch tile)
- Modify: `lib/screens/scoring.dart:49-77` (split `ListenableBuilder`)
- Modify: `lib/screens/widgets.dart:348-450` (`Celebrate` gate)
- Test: `test/store_test.dart`, `test/screens_layout_test.dart` (append widget case)

**Interfaces:**
- Consumes: Task 2 throttles; `MatchStore.batterySaver`, `static const kBatterySaver = 'cricket_battery_saver'`, `void setBatterySaver(bool v)`, `bool get isBatterySaverOn`
- Produces: Saver-gated rendering contract: when `isBatterySaverOn==true`, `Celebrate` renders static text and `Scoreboard` is the only store-listening subtree in `ScoringScreen`.

- [ ] **Step 1: Write the failing tests**

`batterySaverRoundTrip` — `setBatterySaver(true)`, reload store, assert `batterySaver==true` and pref `cricket_battery_saver==true`. `celebrateOffWhenSaverOn` — pump `ScoringScreen` with saver on, deliver a boundary, assert no `AnimationController` ticking (find `Celebrate` and check static text) while score updated.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub --reporter compact test/store_test.dart -t "batterySaverRoundTrip"`
Expected: FAIL (`kBatterySaver`/`setBatterySaver` undefined).

- [ ] **Step 3: Implement toggle + splits**

Store: add key/field, load `getBool ?? false`, `_persist` writes it, saver branch in `_maybeBackup` returns early unless `force`. Home: `SwitchListTile` after sound row, subtitle "Fewer repaints + no celebration. Backup on over/pause only." Scoring: keep `ListenableBuilder` only around `Scoreboard`+strip; keypad/appbar built statically from initial `store` reads (still re-read on save via `Listenable` of `soundOn`/`batterySaver` cells only). Widgets: in `Celebrate.build`, `if (batterySaver) return _text(base)` before `AnimatedBuilder`; pass `batterySaver` via constructor arg from scorer (`store.isBatterySaverOn`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test --no-pub --reporter compact test/store_test.dart test/screens_layout_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/store.dart lib/screens/home.dart lib/screens/scoring.dart lib/screens/widgets.dart test/store_test.dart test/screens_layout_test.dart
git commit -m "feat: opt-in battery saver with split scoring builders"
```

---

### Task 4: Full live-room excision

**Files:**
- Delete: `lib/screens/viewer.dart`, `lib/domain/room_code.dart`, `lib/domain/room_snapshot.dart`, `lib/ports/sync_port.dart`, `lib/adapters/supabase_sync.dart`, `lib/adapters/local_only_sync.dart`, `lib/app_config.dart`, `supabase/`, `test/room_test.dart`, `test/viewer_test.dart`
- Modify: `lib/main.dart`, `lib/store.dart` (sync block), `lib/scoring_engine.dart`, `lib/screens/scoring.dart`, `lib/screens/home.dart`, `lib/screens/scoreboard.dart`, `pubspec.yaml`, `tool/release.sh`, `android/app/src/main/AndroidManifest.xml` (keep INTERNET? remove comment + permission only if no other network need — scorer is offline, so remove both live permissions)

**Interfaces:**
- Consumes: Task 3 `MatchStore()` no-arg constructor contract
- Produces: Offline-only app: `MatchStore({})` with no `sync`, `roomCode`, `startSharing/stopSharing/_publishRoom/viewerCount/onlineState` members; `Scoreboard` without `live` param (scorer passes none); no `SyncState` import anywhere.

- [ ] **Step 1: Write the failing guard test (temporary)**

Create `test/live_room_gone_test.dart`: assert `MatchStore` has no `startSharing`, assert `package:supabase_flutter` absent from `pubspec.yaml` text, assert `lib/screens/viewer.dart` does not exist. This test documents removal intent (deleted in Step 5 after excision proves itself, folded into `design_test` grep).

- [ ] **Step 2: Run guard to verify it fails**

Run: `flutter test --no-pub --reporter compact test/live_room_gone_test.dart`
Expected: FAIL (files still exist).

- [ ] **Step 3: Excise per file list**

`main.dart`: drop adapter/app_config/viewer imports, sync selection, `PromiseBar`/`unawaited(sync.init())`, `/join` route. `store.dart`: remove imports, `sync` field/ctor param, room block (`roomCode`, `_roomSeq`, `_publishRoom`, `startSharing`, `stopSharing`, `viewerCount`, `onlineState`, `onlineError`), `_publishRoom` call sites (undo, ball, innings). `scoring_engine.dart`: drop `stopSharing` calls. `scoring.dart`: remove share icon + `_shareSheet`. `home.dart`: remove sync switch, keep saver switch. `scoreboard.dart`: remove `live` field/param and branches that keyed off it (celebration guard becomes `batterySaver`-driven via widgets gate). `pubspec.yaml`: remove supabase dep. `release.sh`: remove SUPA vars + INTERNET/key asserts, add `!grep supabase` fail. `AndroidManifest.xml`: remove INTERNET/ACCESS_NETWORK_STATE + live comment.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter analyze --no-pub` then `flutter test --no-pub --reporter compact`
Expected: PASS (live tests deleted, remaining suites green).

- [ ] **Step 5: Commit**

```bash
git add -A lib pubspec.yaml tool/release.sh android/app/src/main/AndroidManifest.xml test
git commit -m "chore: remove live rooms entirely"
```

Delete `test/live_room_gone_test.dart` in this step and assert via `grep -R supabase lib` empty.

---

### Task 5: Anchor file + release check + version bump

**Files:**
- Create: `APP.md`, `tool/check-master.sh`
- Modify: `AGENTS.md` (rule line), `tool/release.sh` (call check), `pubspec.yaml` (version)

**Interfaces:**
- Consumes: Tasks 1–4 final state (no live code to document)
- Produces: `APP.md` (<1,000 words, version line `Version: 2.27.0`), `tool/check-master.sh` exit 0, release gate calls it.

- [ ] **Step 1: Write the failing check**

Create `tool/check-master.sh` stub that fails when `APP.md` missing. Run it.
Expected: FAIL.

- [ ] **Step 2: Run check to verify it fails**

Run: `bash tool/check-master.sh`
Expected: FAIL.

- [ ] **Step 3: Write `APP.md` + bump version**

`APP.md` sections: What/Version, Scoring invariants, Screens, Data keys, Commands, Active decisions (offline, no live, archives envelope, battery). Count words <1,000. Bump `pubspec.yaml` to `2.27.0+<build>`. `AGENTS.md`: append "APP.md is the anchor — update the relevant section and bump version in the same commit; `tool/check-master.sh` guards it." `release.sh`: call check after `dart format` before analyze. `chmod +x tool/check-master.sh`.

- [ ] **Step 4: Run check to verify it passes**

Run: `bash tool/check-master.sh; flutter analyze --no-pub`
Expected: PASS, no new lints.

- [ ] **Step 5: Commit**

```bash
git add APP.md AGENTS.md tool/check-master.sh tool/release.sh pubspec.yaml
git commit -m "docs: add APP.md anchor with release check"
```

---

### Task 6: Final verification + batterystats note

**Files:** none (verification only)

- [ ] **Step 1: Analyze + targeted tests**

Run: `flutter analyze --no-pub; flutter test --no-pub --reporter compact test/store_test.dart test/match_detail_test.dart test/screens_layout_test.dart`
Expected: PASS.

- [ ] **Step 2: Grep guards**

Run: `grep -R "supabase\|SyncPort\|viewer.dart\|room_code" lib test --include="*.dart" || echo CLEAN`
Expected: `CLEAN`.

- [ ] **Step 3: Note follow-up**

If time permits, capture `adb shell dumpsys batterystats --reset` before a 2-over friendly and after — file the delta in the release note. Not blocking ship.
