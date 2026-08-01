#!/usr/bin/env bash
# rig-check proves that every observer is alive, attributed, and producing current-session evidence.
set -euo pipefail

RIG_HOME="${RIG_HOME:-$HOME/.anselm-rig}"
MANIFEST="$RIG_HOME/current/manifest.json"
FAIL=0
note() { echo "$@"; }
bad() { echo "$@" >&2; FAIL=1; }
field() { python3 -c "import json; print(json.load(open('$MANIFEST')).get('$1',''))"; }
alive_as() {
  local pid="$1" pattern="$2"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && ps -o command= -p "$pid" | grep -Eq "$pattern"
}

command -v ffmpeg >/dev/null || bad "✗ ffmpeg missing — frame extraction unavailable"
TMP=$(mktemp -d)
if screencapture -x "$TMP/probe.png" 2>/dev/null && [ -s "$TMP/probe.png" ]; then
  note "✓ screen capture permission live"
else
  bad "✗ screencapture denied — channel 1 blind"
fi
rm -rf "$TMP"

if [ ! -f "$MANIFEST" ]; then
  bad "✗ no live rig session — run rig-up.sh first"
else
  PORT=$(field port)
  BPID=$(field backendPid)
  TPID=$(field tapPid)
  LPID=$(field llmtapPid)
  LPORT=$(field llmtapPort)
  APID=$(field appPid)
  AWID=$(field appWindowId)
  RPID=$(field recorderPid)
  SESSION=$(field session)

  LISTENER=$(lsof -ti ":$PORT" -sTCP:LISTEN 2>/dev/null | sort -u || true)
  if [ "$LISTENER" = "$BPID" ] && alive_as "$BPID" '/server($| )'; then
    note "✓ channel 2 backend attributed: :$PORT holder == PID $BPID"
  else
    bad "✗ channel 2 attribution broken: holder [$LISTENER], manifest PID [$BPID]"
  fi
  curl -sf "http://127.0.0.1:$PORT/api/v1/health" >/dev/null && note "✓ backend health ok" || bad "✗ backend health failed"
  [ -s "$SESSION/backend.log" ] || bad "✗ backend.log missing or empty"
  if grep -Eq 'panic:|(^|[^A-Za-z])FATAL([^A-Za-z]|$)' "$SESSION/backend.log" 2>/dev/null; then
    bad "✗ backend journal contains panic/FATAL"
  fi

  if alive_as "$TPID" '/ssetap($| )'; then
    note "✓ channel 3 ssetap alive (PID $TPID)"
  else
    bad "✗ channel 3 ssetap dead or PID reused"
  fi
  WORKSPACES=$(curl -sf "http://127.0.0.1:$PORT/api/v1/workspaces" | python3 -c 'import json,sys; print(" ".join(x["id"] for x in json.load(sys.stdin).get("data",[])))' || true)
  if [ -n "$WORKSPACES" ]; then
    for ws in $WORKSPACES; do
      for stream in messages entities notifications; do
        python3 - "$SESSION/sse.jsonl" "$ws" "$stream" <<'PY' || bad "✗ ssetap has no connect for $ws/$stream"
import json, sys
try:
    rows = (json.loads(x) for x in open(sys.argv[1]))
    ok = any(r.get("workspace") == sys.argv[2] and r.get("stream") == sys.argv[3] and r.get("tap") == "connect" for r in rows)
except (OSError, ValueError):
    ok = False
raise SystemExit(0 if ok else 1)
PY
      done
    done
    note "✓ channel 3 connected for every current workspace"
  else
    note "· no workspace yet — discovery is live; onboarding remains observable from creation onward"
  fi

  if [ -n "$LPID" ]; then
    if alive_as "$LPID" '/llmtap($| )' && [ "$(lsof -ti ":$LPORT" -sTCP:LISTEN 2>/dev/null | head -1)" = "$LPID" ]; then
      note "✓ channel 5 llmtap attributed: :$LPORT holder == PID $LPID"
    else
      bad "✗ channel 5 llmtap dead, reused, or not the listener"
    fi
    [ -f "$SESSION/llm.jsonl" ] || bad "✗ llm.jsonl missing"
    if [ -n "$WORKSPACES" ]; then
      for ws in $WORKSPACES; do
        BASE=$(curl -sf "http://127.0.0.1:$PORT/api/v1/api-keys?limit=100" -H "X-Anselm-Workspace-ID: $ws" | python3 -c '
import json,sys
rows=json.load(sys.stdin).get("data") or []
print(next((r.get("baseUrl","") for r in rows if r.get("provider")=="anselm"),"ABSENT"))' || echo ABSENT)
        case "$BASE" in
          ABSENT) note "· managed key pending for $ws" ;;
          "http://127.0.0.1:$LPORT"*) note "✓ channel 5 wiring for $ws → tap" ;;
          *) bad "✗ channel 5 wiring for $ws bypasses tap: $BASE" ;;
        esac
      done
    fi
  elif [ -f "$SESSION/llm.disabled" ]; then
    bad "✗ channel 5 explicitly disabled — useful for diagnosis, never valid for acceptance"
  else
    bad "✗ channel 5 has neither a live observer nor an explicit disabled marker"
  fi

  if alive_as "$APID" 'flutter_tools\.snapshot run'; then
    note "✓ channel 4 Flutter runner alive (PID $APID)"
  else
    bad "✗ channel 4 Flutter runner dead or PID reused"
  fi
  [ -s "$SESSION/frontend.log" ] || bad "✗ frontend.log missing or empty"
  grep -q 'Flutter run key commands' "$SESSION/frontend.log" 2>/dev/null || bad "✗ frontend.log never reached resident app"
  if grep -Eq 'Unhandled exception|══╡ EXCEPTION CAUGHT|FlutterError|Lost connection to device' "$SESSION/frontend.log" 2>/dev/null; then
    bad "✗ frontend.log contains an unreviewed Flutter failure"
  fi

  if [ -n "$AWID" ] && alive_as "$RPID" "screencapture.*-v.*-l[[:space:]]$AWID([[:space:]]|$)"; then
    note "✓ channel 1 window recorder alive (PID $RPID, Anselm window $AWID)"
  elif [ -n "$AWID" ]; then
    bad "✗ channel 1 recorder is not bound to Anselm window $AWID"
  elif alive_as "$RPID" 'screencapture.*-v'; then
    bad "✗ channel 1 manifest has no Anselm window ID — desktop-wide recording is not evidence"
  else
    bad "✗ channel 1 recorder dead or PID reused"
  fi
fi

if [ "$FAIL" = "0" ]; then
  echo "✓ rig-check: five channels physically observing"
else
  echo "✗ rig-check FAILED"
  exit 1
fi
