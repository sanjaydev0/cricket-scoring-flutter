#!/usr/bin/env bash
# CricScore — release gate. Only run this once features and UI are settled.
#
#   ./tool/release.sh 2.8.1 "short note"
#
# Order matters. The pre-flight gate exists because release-only faults are
# invisible on web and in debug:
#   - Flutter adds android.permission.INTERNET to the debug and profile
#     manifests ONLY. A release APK with no INTERNET cannot open a socket, so
#     live sharing fails with "Failed host lookup ... errno = 7" while
#     `flutter run` and the web build both work. That shipped through v2.2-v2.7.
#   - `--dart-define` values are substituted at compile time. Forget them and
#     the build silently has no backend.
# Both are cheap to assert here and impossible to notice later.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="$HOME/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"

VERSION="${1:?usage: ./tool/release.sh <version> [notes]}"
NOTES="${2:-}"
LOG="/tmp/opencode/apk-$VERSION.log"
mkdir -p /tmp/opencode

SUPA_URL="${SUPABASE_URL:-https://uhoghzqrsfxvvhwbrfbo.supabase.co}"
SUPA_KEY="${SUPABASE_PUBLISHABLE_KEY:-}"
fail() { echo "FAIL: $*" >&2; exit 1; }

# A live web server and a Gradle build together is how dart2js died with
# "Could not start thread" earlier. Do not run them concurrently.
if pgrep -f "flutter run" >/dev/null 2>&1; then
  echo "==> a 'flutter run' dev server is active; stop it (q) before releasing"
  fail "dev server still running"
fi

echo "==> analyze"
dart format . >/dev/null
flutter analyze 2>&1 | tail -n 2

echo "==> test"
flutter test 2>&1 | tr '\r' '\n' | grep -E "All tests passed|Some tests failed" | tail -n 1

echo "==> build apk"
flutter build apk --release \
  --dart-define=SUPABASE_URL="$SUPA_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPA_KEY" \
  >"$LOG" 2>&1 || { tail -n 20 "$LOG"; fail "apk build failed (see $LOG)"; }
grep -q "Built build/app/outputs" "$LOG" || fail "apk build did not report success"
APK=build/app/outputs/flutter-apk/app-release.apk
cp "$APK" "$HOME/Downloads/cricket-scoring.apk"

echo "==> pre-flight gate"
AAPT="$(ls "$HOME/Android/Sdk/build-tools/"*/aapt2 2>/dev/null | head -n 1)"
[ -n "$AAPT" ] || fail "aapt2 not found, cannot verify manifest"
PERMS="$("$AAPT" dump permissions "$APK" 2>/dev/null)"
grep -q "android.permission.INTERNET" <<<"$PERMS" ||
  fail "release apk has no INTERNET permission — every online feature will fail"
grep -q "android.permission.ACCESS_NETWORK_STATE" <<<"$PERMS" ||
  fail "release apk has no ACCESS_NETWORK_STATE (realtime push)"
echo "    permissions ok"

if [ -n "$SUPA_KEY" ]; then
  # NOTE: do not pipe unzip straight into `grep -q` here. grep -q exits at the
  # first match while unzip is still streaming 52 MB, so unzip dies of SIGPIPE
  # and `pipefail` turns a successful match into a failure. Capture first.
  SO_STRINGS="$(unzip -p "$APK" lib/arm64-v8a/libapp.so 2>/dev/null | strings)"
  grep -qF "$SUPA_KEY" <<<"$SO_STRINGS" || fail "Supabase key is not baked into libapp.so"
  grep -qF "$SUPA_URL" <<<"$SO_STRINGS" || fail "Supabase URL is not baked into libapp.so"
  echo "    backend keys baked in"
else
  echo "    WARNING: no SUPABASE_PUBLISHABLE_KEY — live rooms will be off"
fi

echo "==> tag + release"
git rev-parse --short HEAD | sed 's/^/    commit /'
if gh release view "v$VERSION" >/dev/null 2>&1; then
  fail "release v$VERSION already exists; delete it first: gh release delete v$VERSION --yes"
fi
gh release create "v$VERSION" --title "v$VERSION" --notes "${NOTES:-see commit log}" "$APK" 2>&1 | tail -n 1

echo "==> install"
for d in $(adb devices | awk '/device$/{print $1}'); do
  echo "    -> $d"
  adb -s "$d" install -r "$HOME/Downloads/cricket-scoring.apk" 2>&1 | tail -n 1
  adb -s "$d" shell monkey -p com.gully.cricket.cricket_scoring \
    -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
done

cat <<'EOF'

Next, on the phone — these cannot be checked on web:
  * sounds: rapid 4-4-6-W-6, and the boundary/wicket clips are distinct
  * haptics: power saving OFF, vibration intensity above 0
  * live sharing: share a code, open it on a second phone
EOF