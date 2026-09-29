# Gully Cricket Scorer — Flutter (100% offline)

Flutter port of the AI Studio web app. Optimized for speed + zero-network use.

## Features (1:1)
- Setup: teams, overs, players/side, wide/no-ball penalty, free-hit, last-man-standing
- Keypad: 0 1 2 3 4 6, WD, NB arm, W + wicket types + run-out runs, undo (60)
- Extras: B, LB via More sheet; custom WD/NB penalties
- Auto: overs, CRR/RRR, target, innings break, result (win by wkts/runs, tie), archives (50)
- 3 themes: Sunlight high-contrast, Pavilion night, Solar high-vis
- Offline: SharedPreferences only. No http, no Firebase, no Google Fonts (system fonts).

## Run (web preview for quick changes)
```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter pub get
flutter run -d chrome
flutter build web --release
```

## APK
Needs JDK17 + Android SDK (one-time):
```bash
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

## Speed notes
- `const` widgets, `ListView.builder`, single `ChangeNotifier`, capped undo JSON
- No codegen, no network fonts/images, minimal dep (shared_preferences only)
