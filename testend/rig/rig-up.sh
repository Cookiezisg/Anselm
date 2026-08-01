#!/usr/bin/env bash
# rig-up owns every acceptance observer and the real Flutter app. A channel that merely could run
# is not evidence; the conductor starts it, records its PID, and refuses success until it is alive.
#
# rig-up 亲自持有每个验收观察者与真实 Flutter app。一个「理论上能跑」的通道不算证据；导演器
# 必须启动它、记录 PID，并在它真实存活前拒绝报绿。
set -euo pipefail

cd "$(dirname "$0")/../.."
ROOT="$(pwd)"
PORT="${RIG_PORT:-8742}"
RIG_HOME="${RIG_HOME:-$HOME/.anselm-rig}"
SESSION="$RIG_HOME/sessions/$(date +%Y%m%d-%H%M%S)"
SEED="${RIG_SEED:-1}"
DATA="${RIG_DATA:-$RIG_HOME/data}"
LLMTAP="${RIG_LLMTAP:-1}"
LLMTAP_PORT="${RIG_LLMTAP_PORT:-8788}"
LLM_UPSTREAM="${RIG_LLM_UPSTREAM:-https://api.anselm.website}"
RECORD="${RIG_RECORD:-1}"
APP="${RIG_APP:-1}"
MISE="${MISE:-mise}"

BACKEND_PID=""
TAP_PID=""
LLMTAP_PID=""
APP_PID=""
RECORDER_PID=""
ARMED=1

stop_pid() {
  local pid="${1:-}" signal="${2:-TERM}"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && kill -"$signal" -"$pid" 2>/dev/null || true
}

cleanup_failed_start() {
  [ "$ARMED" = "1" ] || return
  stop_pid "$APP_PID"
  stop_pid "$BACKEND_PID"
  stop_pid "$TAP_PID"
  stop_pid "$LLMTAP_PID"
  stop_pid "$RECORDER_PID" INT
}
trap cleanup_failed_start EXIT INT TERM

mkdir -p "$SESSION/evidence" "$RIG_HOME/bin" "$DATA"
echo "→ rig session: $SESSION (port :$PORT, data $DATA)"

PREFLIGHT_PORTS=("$PORT")
[ "$LLMTAP" = "1" ] && PREFLIGHT_PORTS+=("$LLMTAP_PORT")
for p in "${PREFLIGHT_PORTS[@]}"; do
  if HOLDER=$(lsof -ti ":$p" -sTCP:LISTEN 2>/dev/null | head -1) && [ -n "${HOLDER:-}" ]; then
    echo "✗ port :$p already held by PID $HOLDER ($(ps -o comm= -p "$HOLDER" 2>/dev/null || echo '?'))." >&2
    echo "  The rig never adopts a process it did not start (D1). Stop it or change the rig port." >&2
    exit 1
  fi
done

echo "→ building server + observers …"
(cd "$ROOT/backend" && "$MISE" exec -- go build -o "$RIG_HOME/bin/server" ./cmd/server)
(cd "$ROOT/testend" && "$MISE" exec -- go build -o "$RIG_HOME/bin/ssetap" ./cmd/ssetap)
if [ "$LLMTAP" = "1" ]; then
  (cd "$ROOT/testend" && "$MISE" exec -- go build -o "$RIG_HOME/bin/llmtap" ./cmd/llmtap)
fi

GATEWAY_ENV=()
if [ "$LLMTAP" = "1" ]; then
  LLMTAP_PID=$(python3 "$ROOT/testend/rig/spawn.py" --cwd "$ROOT" --out "$SESSION/llmtap.log" -- \
    "$RIG_HOME/bin/llmtap" -listen "127.0.0.1:$LLMTAP_PORT" -upstream "$LLM_UPSTREAM" -out "$SESSION/llm.jsonl")
  for _ in $(seq 1 40); do
    [ "$(lsof -ti ":$LLMTAP_PORT" -sTCP:LISTEN 2>/dev/null | head -1)" = "$LLMTAP_PID" ] && break
    sleep 0.25
  done
  [ "$(lsof -ti ":$LLMTAP_PORT" -sTCP:LISTEN 2>/dev/null | head -1)" = "$LLMTAP_PID" ] || {
    echo "✗ llmtap did not acquire :$LLMTAP_PORT" >&2; exit 1;
  }
  UPSTREAM_HOST=$(python3 -c "from urllib.parse import urlparse; print(urlparse('$LLM_UPSTREAM').netloc)")
  GATEWAY_ENV=(ANSELM_GATEWAY_URL="http://127.0.0.1:$LLMTAP_PORT/v1" ANSELM_PROOF_HOST="$UPSTREAM_HOST")
  echo "✓ llmtap up (PID $LLMTAP_PID, → $LLM_UPSTREAM)"
else
  : >"$SESSION/llm.disabled"
fi

BACKEND_PID=$(python3 "$ROOT/testend/rig/spawn.py" --cwd "$ROOT" --out "$SESSION/backend.log" -- \
  env ANSELM_DEV=1 ANSELM_ADDR=":$PORT" ANSELM_DATA_DIR="$DATA" "${GATEWAY_ENV[@]}" "$RIG_HOME/bin/server")
for _ in $(seq 1 80); do
  curl -sf "http://127.0.0.1:$PORT/api/v1/health" >/dev/null 2>&1 && break
  sleep 0.25
done
curl -sf "http://127.0.0.1:$PORT/api/v1/health" >/dev/null || {
  echo "✗ backend did not come up" >&2; tail -20 "$SESSION/backend.log" >&2; exit 1;
}
LISTENER=$(lsof -ti ":$PORT" -sTCP:LISTEN | sort -u)
[ "$LISTENER" = "$BACKEND_PID" ] || {
  echo "✗ D1 attribution: :$PORT holder [$LISTENER] != journaled PID $BACKEND_PID" >&2; exit 1;
}
echo "✓ backend up (PID $BACKEND_PID == port holder)"

if [ "$SEED" = "1" ]; then
  (cd "$ROOT/backend" && "$MISE" exec -- go run ./cmd/seed -base "http://127.0.0.1:$PORT") | tail -3
fi

# Dynamic discovery is essential: with RIG_SEED=0 there is no workspace until onboarding, and later
# workspace-switch journeys create more. One resident process discovers and taps all of them.
TAP_PID=$(python3 "$ROOT/testend/rig/spawn.py" --cwd "$ROOT" --out "$SESSION/ssetap.log" -- \
  "$RIG_HOME/bin/ssetap" -base "http://127.0.0.1:$PORT" -all-workspaces -out "$SESSION/sse.jsonl")
echo "✓ ssetap discovery up (PID $TAP_PID)"

if [ "$RECORD" = "1" ]; then
  RECORDER_PID=$(python3 "$ROOT/testend/rig/spawn.py" --cwd "$ROOT" --out "$SESSION/recording.log" -- \
    screencapture -v -C -k "$SESSION/screen.mov")
  sleep 1
  kill -0 "$RECORDER_PID" 2>/dev/null || {
    echo "✗ screen recorder exited — check Screen Recording permission and $SESSION/recording.log" >&2; exit 1;
  }
  echo "✓ screen recording (PID $RECORDER_PID)"
else
  : >"$SESSION/recording.disabled"
fi

if [ "$APP" = "1" ]; then
  : >"$SESSION/frontend.log"
  APP_PID=$(python3 "$ROOT/testend/rig/spawn.py" --cwd "$ROOT/frontend" --out "$SESSION/frontend.log" -- \
    env ANSELM_BACKEND_URL="http://127.0.0.1:$PORT" LANG=en_US.UTF-8 \
    "$MISE" exec -- flutter run -d macos -t lib/main.dart --pid-file "$SESSION/flutter.pid")
  for _ in $(seq 1 360); do
    kill -0 "$APP_PID" 2>/dev/null || break
    grep -q "Flutter run key commands" "$SESSION/frontend.log" 2>/dev/null && break
    sleep 0.5
  done
  kill -0 "$APP_PID" 2>/dev/null || {
    echo "✗ Flutter runner exited" >&2; tail -40 "$SESSION/frontend.log" >&2; exit 1;
  }
  grep -q "Flutter run key commands" "$SESSION/frontend.log" || {
    echo "✗ Flutter app did not become resident within 180s" >&2; tail -40 "$SESSION/frontend.log" >&2; exit 1;
  }
  echo "✓ Flutter app up (runner PID $APP_PID, console journaled)"
else
  : >"$SESSION/frontend.disabled"
fi

python3 - "$SESSION/manifest.json" <<PY
import json, sys
json.dump({
  "port": $PORT,
  "backendPid": "$BACKEND_PID",
  "tapPid": "$TAP_PID",
  "llmtapPid": "$LLMTAP_PID",
  "llmtapPort": $LLMTAP_PORT,
  "llmUpstream": "$LLM_UPSTREAM",
  "appPid": "$APP_PID",
  "recorderPid": "$RECORDER_PID",
  "data": "$DATA",
  "session": "$SESSION",
  "startedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}, open(sys.argv[1], "w"), indent=2)
PY
ln -sfn "$SESSION" "$RIG_HOME/current"

ARMED=0
trap - EXIT INT TERM
echo "✓ rig up — five observers owned; journals in $SESSION"
echo "  run: testend/rig/rig-check.sh"
