#!/usr/bin/env bash
# CricScore — fast web iteration loop.
#
#   ./tool/web.sh          release web build, serve on the LAN, print the URL
#   ./tool/web.sh serve    serve the existing build (no rebuild)
#
# Why release and not `flutter run`: a release build is what people actually
# use, so layout, icon tree-shaking and font fallback match. It costs ~60s.
# For sub-second nudges use:  flutter run -d web-server --web-port 8000 --web-hostname 0.0.0.0
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="$HOME/flutter/bin:$PATH"

PORT="${PORT:-8000}"
LOG=/tmp/opencode/webserver.log
mkdir -p /tmp/opencode

# dart2js aborts with "Could not start thread: Resource temporarily
# unavailable" when the box is out of memory. The Gradle daemon alone held
# 2.4 GB once and killed a web build, so free it before compiling.
free_memory() {
  if pgrep -f "GradleDaemon" >/dev/null 2>&1; then
    echo "==> stopping Gradle daemon (frees ~2 GB for dart2js)"
    (cd "$ROOT/android" && ./gradlew --stop >/dev/null 2>&1) || true
  fi
}

stop_server() {
  if pgrep -f "http.server $PORT" >/dev/null 2>&1; then
    pkill -f "http.server $PORT" || true
    sleep 1
  fi
}

serve() {
  stop_server
  cd "$ROOT/build/web"
  nohup python3 -m http.server "$PORT" --bind 0.0.0.0 >"$LOG" 2>&1 &
  sleep 2
  local lan
  lan="$(ip -4 addr show scope global 2>/dev/null |
    grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)"
  echo "==> serving build/web on 0.0.0.0:$PORT"
  echo "    desktop : http://localhost:$PORT"
  [ -n "$lan" ] && echo "    phone   : http://$lan:$PORT   <- open this for a real mobile view"
}

if [ "${1:-}" != "serve" ]; then
  free_memory
  echo "==> flutter build web --release"
  flutter build web --release \
    --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://uhoghzqrsfxvvhwbrfbo.supabase.co}" \
    --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-}" \
    2>&1 | tail -n 3
fi

serve
