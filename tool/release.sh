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

# The version has to live in pubspec.yaml. Gradle reads flutter.versionName and
# flutter.versionCode from there, so a release that only set a git tag shipped
# an APK still calling itself 1.0.0 / versionCode 1. Every build from v2.2 to
# v2.20 was therefore indistinguishable to Android — and to `dumpsys package`,
# which is why the phone could never say which build it was running.
BUILD_NUMBER="$(git rev-list --count HEAD)"
WANT_VERSION="$VERSION+$BUILD_NUMBER"
CURRENT_VERSION="$(sed -n 's/^version: *//p' pubspec.yaml | head -n 1)"
if [ "$CURRENT_VERSION" != "$WANT_VERSION" ]; then
  echo "==> version $CURRENT_VERSION -> $WANT_VERSION"
  sed -i "s|^version: .*|version: $WANT_VERSION|" pubspec.yaml
  # Committed here, not later: the release tag is cut at HEAD, so the tagged
  # tree must already carry the version the APK was built from. The path form
  # keeps other staged work out of this commit.
  git -c user.name="$(git config user.name || echo sanjaydev0)" \
    -c user.email="$(git config user.email ||
      echo sanjaydev0@users.noreply.github.com)" \
    commit -q -m "chore: release v$VERSION" -- pubspec.yaml
else
  echo "==> version $WANT_VERSION (already set)"
fi

# Pushed before the tag exists. `gh release create` cuts the tag on the REMOTE,
# so an unpushed version commit would tag a tree that still says 1.0.0 — and a
# feature commit left unpushed would tag a tree without the release in it.
echo "==> push"
git push -q origin HEAD:main ||
  fail "could not push to origin/main — the GitHub tag would point at the wrong tree"

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

# Portrait lock, asserted in the PACKAGED manifest. Release-only: on web and in
# `flutter run` the Dart setPreferredOrientations call is enough, so a missing
# manifest attribute is invisible everywhere except a release APK on a phone.
#
# `aapt2 dump badging` does NOT print screenOrientation, so read the XML tree.
# The compiled attribute is the platform integer: 1 = portrait. Anything else
# (2 = landscape, 0 = unspecified, 6 = sensor) lets the phone rotate.
MANIFEST_TREE="$("$AAPT" dump xmltree "$APK" --file AndroidManifest.xml 2>/dev/null)"
ORIENT="$(grep -o 'android:screenOrientation([^)]*)=[0-9-]*' <<<"$MANIFEST_TREE" |
  head -n 1 | grep -o '=[0-9-]*$' | tr -d '=')"
[ "$ORIENT" = "1" ] ||
  fail "release apk is not portrait-locked (screenOrientation=${ORIENT:-unset}) — the phone can rotate"
echo "    portrait lock ok"

# The APK must call itself what the release says it is. Without this the tag
# and the binary drift apart silently, which is exactly how twenty releases
# shipped as 1.0.0.
APK_VERSION="$("$AAPT" dump badging "$APK" 2>/dev/null |
  grep -m1 -o "versionName='[^']*'" | cut -d"'" -f2 || true)"
[ "$APK_VERSION" = "$VERSION" ] ||
  fail "apk versionName is '${APK_VERSION:-none}' but this release is v$VERSION — pubspec.yaml and the tag have drifted"
echo "    version $APK_VERSION ok"

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