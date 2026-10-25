# Gully Cricket Scorer — Flutter (100% offline)

Offline gully-cricket umpire scorer for Android, with a Linux desktop preview for
fast iteration. There is no web target.

## Features (1:1)
- Setup: teams, overs, players/side, wide/no-ball penalty, free-hit, last-man-standing
- Keypad: 0 1 2 3 4 6, WD, NB arm, W + wicket types + run-out runs, undo (60)
- Extras: B, LB via More sheet; custom WD/NB penalties
- Auto: overs, CRR/RRR, target, innings break, result (win by wkts/runs, tie), archives (50)
- 3 themes: Sunlight high-contrast, Pavilion night, Solar high-vis
- Offline: SharedPreferences only. No http, no Firebase, no Google Fonts (system fonts).

## Preview (Linux desktop, fast iteration)
```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter pub get
./tool/flutter-live.sh linux   # watchexec auto hot reload
```
The desktop preview mirrors Android layout and scoring logic. Sound and haptics
must be verified on the phone.

## APK
Needs JDK17 + Android SDK (one-time):
```bash
./tool/release.sh 2.25.0 "notes"   # analyze, test, gate, gh release, install
# or a plain build
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

## Speed notes
- `const` widgets, `ListView.builder`, single `ChangeNotifier`, capped undo JSON
- No codegen, no network fonts/images, minimal dep (shared_preferences only)

## Credits
- Arcade SFX: Kenney.nl Interface Sounds + Digital Audio (CC0, bundled in `assets/audio/`)
- Score fonts: Anton, Archivo Black, IBM Plex Mono, Chakra Petch (SIL OFL, bundled in `assets/fonts/`)
