#!/usr/bin/env bash
# Real end-to-end screenshot of `make app` — the REAL Flutter shell against a REAL Go backend (not the
# fixture demo): starts the backend, seeds a workspace + a few entities via the HTTP API, builds the real
# app and launches its BINARY DIRECTLY with ANSELM_BACKEND_URL (so the dev-attach env is inherited — `open`
# and a backgrounded `flutter run` don't carry env / a TTY), then captures the running window →
# test/dev/out/app.png. Proves the live path end to end: dev-attach → cold-start workspace resolution →
# rail/detail over real HTTP+SSE (catches contract drift the fixture path can't). Run: bash test/dev/shot_app_real.sh
# 真·端到端:真壳 + 真后端。起后端 → 种 workspace+实体 → flutter build macos → 直跑二进制(带 env)→ 截窗口。
set -euo pipefail
cd "$(dirname "$0")/../.."   # frontend/
RUN="mise exec --"
PORT="${PORT:-8742}"
URL="http://127.0.0.1:$PORT"
OUT="test/dev/out"; mkdir -p "$OUT"
DATA="/tmp/anselm-shot-app"
APP="build/macos/Build/Products/Debug/anselm.app"
BIN="$APP/Contents/MacOS/anselm"

BACK=""; APPPID=""
cleanup() {
  [ -n "$APPPID" ] && kill "$APPPID" 2>/dev/null || true
  osascript -e 'tell application "anselm" to quit' >/dev/null 2>&1 || true
  [ -n "$BACK" ] && kill "$BACK" 2>/dev/null || true
  lsof -ti ":$PORT" 2>/dev/null | xargs kill 2>/dev/null || true
}
trap cleanup EXIT

echo "→ starting backend on :$PORT (fresh data dir) …"
rm -rf "$DATA"   # fresh seed each run → deterministic + no workspace/name conflicts 每次全新种子
( cd ../backend && ANSELM_DEV=1 ANSELM_ADDR=":$PORT" ANSELM_DATA_DIR="$DATA" $RUN go run ./cmd/server ) &
BACK=$!
for i in $(seq 1 120); do curl -sf "$URL/api/v1/health" >/dev/null 2>&1 && break || sleep 0.5; done
curl -sf "$URL/api/v1/health" >/dev/null || { echo "✗ backend never healthy"; exit 1; }

echo "→ seeding workspace + entities …"
WS=$(curl -s -X POST "$URL/api/v1/workspaces" -H 'Content-Type: application/json' \
  -d '{"name":"Personal","language":"zh-CN"}' | sed -E 's/.*"id":"([^"]+)".*/\1/')
echo "  workspace = $WS"
seed_fn() { curl -s -o /dev/null -H "X-Anselm-Workspace-ID: $WS" -H 'Content-Type: application/json' \
  -X POST "$URL/api/v1/functions" -d "$1"; }
seed_fn '{"name":"normalize-input","description":"Coerce + trim raw fields","code":"def main(text):\n    return text.strip().lower()"}'
seed_fn '{"name":"validate-schema","description":"JSON-schema validate a payload","code":"def main(payload):\n    return True"}'
seed_fn '{"name":"summarize-text","description":"LLM summarize a document","code":"def main(doc):\n    return doc[:200]"}'

if [ "${BUILD:-1}" = "1" ] || [ ! -d "$APP" ]; then
  echo "→ flutter build macos --debug -t lib/main.dart …"
  $RUN flutter build macos --debug -t lib/main.dart
fi
[ -x "$BIN" ] || { echo "✗ built binary missing: $BIN"; exit 1; }

echo "→ launching the app binary directly (ANSELM_BACKEND_URL=$URL) …"
ANSELM_BACKEND_URL="$URL" "$BIN" >/tmp/anselm-app.log 2>&1 &
APPPID=$!

# Wait for the window + read its rect (delay inside osascript, not a foreground sleep). 等窗口读矩形。
BOUNDS=$(osascript <<'OSA'
set appName to "anselm"
repeat 120 times
  tell application "System Events"
    if (exists (process appName)) then
      tell process appName
        if (count of windows) > 0 then
          set p to position of window 1
          set s to size of window 1
          return ((item 1 of p) as text) & "," & ((item 2 of p) as text) & "," & ((item 1 of s) as text) & "," & ((item 2 of s) as text)
        end if
      end tell
    end if
  end tell
  delay 0.5
end repeat
return "TIMEOUT"
OSA
)
if [ "$BOUNDS" = "TIMEOUT" ]; then echo "✗ anselm window never appeared (see /tmp/anselm-app.log)"; exit 1; fi

osascript -e 'tell application "anselm" to activate' >/dev/null 2>&1 || true
osascript -e 'delay 8'   # debug build: boot → dev-attach health-gate → cold-start workspace → rail load 让全链路稳定
# COLLAPSE=1 → send ⌘B to collapse the left island (verify the reopen sits AFTER the OS traffic lights).
OUTNAME="app"
if [ "${COLLAPSE:-0}" = "1" ]; then
  osascript -e 'tell application "System Events" to keystroke "b" using command down' >/dev/null 2>&1 || true
  osascript -e 'delay 1' ; OUTNAME="app_collapsed"
fi
screencapture -R "$BOUNDS" -o "$OUT/$OUTNAME.png"
echo "✓ $OUT/$OUTNAME.png  (window rect $BOUNDS)"
