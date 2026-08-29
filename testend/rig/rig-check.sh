#!/usr/bin/env bash
# rig-check proves that every observer is alive, attributed, and producing current-session evidence.
set -euo pipefail

source "$(dirname "$0")/scope.sh"

case "${1:-}" in
  "") ;;
  -h|--help)
    cat <<'EOF'
Usage: testend/rig/rig-check.sh

Verify the live rig selected by the explicitly exported absolute RIG_HOME.
EOF
    exit 0
    ;;
  *)
    echo "Usage: testend/rig/rig-check.sh" >&2
    exit 2
    ;;
esac
require_rig_home
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
  APP_OWNS_BACKEND=$(field appOwnsBackend)
  APP_AUTH_TOKEN_FILE=$(field appAuthTokenFile)
  TPID=$(field tapPid)
  LPID=$(field llmtapPid)
  LPORT=$(field llmtapPort)
  APP_PROXY_PID=$(field appProxyPid)
  APP_PROXY_PORT=$(field appProxyPort)
  APP_PROXY_JOURNAL=$(field appProxyJournal)
  RUNNER_PID=$(field runnerPid)
  APP_LAUNCH_PID=$(field appLaunchPid)
  APID=$(field appPid)
  APP_REBINDS=$(field appRebindCount)
  APP_REBIND_JOURNAL=$(field appRebindJournal)
  AWID=$(field appWindowId)
  AWBOUNDS=$(field appWindowBounds)
  RECORDER_PID=$(field recorderPid)
  RLIFE=$(field recordingLifecycle)
  SESSION=$(field session)

  AUTH_ARGS=()
  if [ "$APP_OWNS_BACKEND" = "1" ]; then
    [ -s "$APP_AUTH_TOKEN_FILE" ] || bad "✗ App-owned backend token file missing"
    if [ -s "$APP_AUTH_TOKEN_FILE" ]; then
      APP_AUTH_TOKEN=$(head -1 "$APP_AUTH_TOKEN_FILE")
      AUTH_ARGS=(-H "Authorization: Bearer $APP_AUTH_TOKEN")
    fi
  fi
  # Keep optional auth expansion safe under `set -u`; an empty array is valid for an external backend.
  curl_backend() {
    if (( ${#AUTH_ARGS[@]} )); then
      curl "$@" "${AUTH_ARGS[@]}"
    else
      curl "$@"
    fi
  }

  if [ "$APP_OWNS_BACKEND" = "1" ]; then
    # In App-owned mode BackendController captures sidecar stderr into frontend.log. Project that
    # stream into the backend-only journal before checking it; the process/port check remains D1.
    awk '
      /\[backend\] / { sub(/^.*\[backend\] /, ""); print; next }
      /^flutter: 20[0-9][0-9]-[0-9][0-9-]+T/ { sub(/^flutter: /, ""); print }
    ' "$SESSION/frontend.log" >"$SESSION/backend.log"
  fi
  LISTENER=$(lsof -ti ":$PORT" -sTCP:LISTEN 2>/dev/null | sort -u || true)
  BACKEND_PATTERN='/server($| )'
  [ "$APP_OWNS_BACKEND" = "1" ] && BACKEND_PATTERN='/anselm-server($| )'
  if [ "$LISTENER" = "$BPID" ] && alive_as "$BPID" "$BACKEND_PATTERN"; then
    note "✓ channel 2 backend attributed: :$PORT holder == PID $BPID"
  else
    bad "✗ channel 2 attribution broken: holder [$LISTENER], manifest PID [$BPID]"
  fi
  curl_backend -sf "http://127.0.0.1:$PORT/api/v1/health" >/dev/null && note "✓ backend health ok" || bad "✗ backend health failed"
  [ -s "$SESSION/backend.log" ] || bad "✗ backend.log missing or empty"
  if grep -Eq 'panic:|(^|[^A-Za-z])FATAL([^A-Za-z]|$)' "$SESSION/backend.log" 2>/dev/null; then
    bad "✗ backend journal contains panic/FATAL"
  fi

  if alive_as "$TPID" '/ssetap($| )'; then
    note "✓ channel 3 ssetap alive (PID $TPID)"
  else
    bad "✗ channel 3 ssetap dead or PID reused"
  fi
  WORKSPACES=""
  WORKSPACE_ROSTER_OK=0
  if WORKSPACES_JSON=$(curl_backend -sf "http://127.0.0.1:$PORT/api/v1/workspaces"); then
    if WORKSPACES=$(printf '%s' "$WORKSPACES_JSON" | python3 -c '
import json,sys
payload=json.load(sys.stdin)
rows=payload.get("data") if isinstance(payload,dict) else None
if not isinstance(rows,list) or any(not isinstance(row,dict) or not isinstance(row.get("id"),str) for row in rows):
    raise SystemExit(2)
print(" ".join(row["id"] for row in rows))'); then
      WORKSPACE_ROSTER_OK=1
    else
      bad "✗ workspace roster is malformed — channel 3/5 checks cannot be trusted"
    fi
  else
    bad "✗ workspace roster request failed — channel 3/5 checks cannot be trusted"
  fi
  if [ "$WORKSPACE_ROSTER_OK" = "1" ] && [ -n "$WORKSPACES" ]; then
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
  elif [ "$WORKSPACE_ROSTER_OK" = "1" ]; then
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
        if KEYS_JSON=$(curl_backend -sf "http://127.0.0.1:$PORT/api/v1/api-keys?limit=100" -H "X-Anselm-Workspace-ID: $ws"); then
          CHECK=$(printf '%s' "$KEYS_JSON" | python3 "$(dirname "$0")/channel5_wiring.py" --port "$LPORT") || {
            bad "✗ channel 5 wiring response for $ws is malformed: $CHECK"
            continue
          }
          case "$CHECK" in
            pending$'\t'*) note "· managed key pending for $ws" ;;
            ok$'\t'*) note "✓ channel 5 wiring for $ws → tap ($CHECK)" ;;
            bypass$'\t'*) bad "✗ channel 5 wiring for $ws bypasses tap: $CHECK" ;;
            invalid$'\t'*) bad "✗ channel 5 wiring for $ws is invalid: $CHECK" ;;
            *) bad "✗ channel 5 wiring returned an unknown result for $ws: $CHECK" ;;
          esac
        else
          bad "✗ channel 5 API-key request failed for $ws"
        fi
      done
    fi
  elif [ -f "$SESSION/llm.disabled" ]; then
    bad "✗ channel 5 explicitly disabled — useful for diagnosis, never valid for acceptance"
  else
    bad "✗ channel 5 has neither a live observer nor an explicit disabled marker"
  fi

  if [ -n "$APP_PROXY_PID" ]; then
    if alive_as "$APP_PROXY_PID" '/appproxy($| )' && [ "$(lsof -ti ":$APP_PROXY_PORT" -sTCP:LISTEN 2>/dev/null | head -1)" = "$APP_PROXY_PID" ]; then
      note "✓ App API perturbation proxy attributed: :$APP_PROXY_PORT holder == PID $APP_PROXY_PID"
    else
      bad "✗ App API perturbation proxy dead, reused, or not the listener"
    fi
    [ -s "$APP_PROXY_JOURNAL" ] || bad "✗ App API perturbation journal missing or empty"
  fi

  if [ -n "$APP_LAUNCH_PID" ]; then
    if alive_as "$APP_LAUNCH_PID" '/anselm\.app/Contents/MacOS/anselm($| )' && [ "$APP_LAUNCH_PID" = "$APID" ]; then
      note "✓ channel 4 direct macOS App launch attributed (PID $APP_LAUNCH_PID)"
      UNATTRIBUTED_APP_PIDS=$(ps -axo pid=,command= | awk -v expected="$APP_LAUNCH_PID" '$0 ~ /\/anselm\.app\/Contents\/MacOS\/anselm([ ]|$)/ && $1 != expected {print $1}')
      if [ -n "$UNATTRIBUTED_APP_PIDS" ]; then
        bad "✗ channel 4 ambiguous: unowned Anselm App PID(s) beside manifest PID $APP_LAUNCH_PID: $UNATTRIBUTED_APP_PIDS"
      fi
    else
      bad "✗ channel 4 direct App dead, reused, or launch PID differs from manifest App PID"
    fi
  elif alive_as "$RUNNER_PID" 'flutter_tools\.snapshot run'; then
    note "✓ channel 4 Flutter runner alive (PID $RUNNER_PID)"
  else
    bad "✗ channel 4 Flutter runner/direct App dead or PID reused (manifest runner [$RUNNER_PID], launch [$APP_LAUNCH_PID])"
  fi
  if [ "${APP_REBINDS:-0}" -gt 0 ] 2>/dev/null; then
    if [ -s "$APP_REBIND_JOURNAL" ] && grep -q '"event": "app_rebounded"\|"event":"app_rebounded"' "$APP_REBIND_JOURNAL" 2>/dev/null; then
      note "· channel 4 App identity explicitly rebound ${APP_REBINDS} time(s); journal: $APP_REBIND_JOURNAL"
    else
      bad "✗ channel 4 manifest claims App rebind without an app-rebind journal"
    fi
  fi
  if alive_as "$APID" '/anselm\.app/Contents/MacOS/anselm($| )'; then
    if [ -n "$AWID" ]; then
      WINDOW_PID=$(swift -e 'import CoreGraphics; let target = Int(CommandLine.arguments[1])!; let ws = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []; for w in ws { let number = w[kCGWindowNumber as String] as? Int ?? -1; if number == target { print(w[kCGWindowOwnerPID as String] ?? ""); exit(0) } }' "$AWID" 2>/dev/null | tr -d '[:space:]')
      if [ "$WINDOW_PID" = "$APID" ]; then
        note "✓ channel 4 Flutter app alive and window-owned (PID $APID)"
      else
        bad "✗ channel 4 window owner mismatch (window PID [$WINDOW_PID], manifest App PID [$APID])"
      fi
    else
      bad "✗ channel 4 window ID missing — recording-disabled diagnostic cannot satisfy full acceptance"
    fi
  else
    bad "✗ channel 4 Flutter app dead or PID reused (manifest PID $APID)"
  fi
  if [ -n "$AWID" ] && [ -n "$AWBOUNDS" ] && alive_as "$APID" '/anselm\.app/Contents/MacOS/anselm($| )'; then
    OVERLAY_SCAN="$(swift "$(dirname "$0")/check_visible_overlay.swift" "$AWID" "$APID" "$RECORDER_PID" "$AWBOUNDS" 2>&1)" || {
      bad "✗ channel 1 external window overlaps the Anselm recording region: $OVERLAY_SCAN"
    }
    [ -n "$OVERLAY_SCAN" ] || note "✓ channel 1 recording region has no external overlay"
  fi
  [ -s "$SESSION/frontend.log" ] || bad "✗ frontend.log missing or empty"
  if [ -n "$APP_LAUNCH_PID" ]; then
    grep -q '\[conductor\] direct macOS App started' "$SESSION/frontend.log" 2>/dev/null || bad "✗ frontend.log has no direct App launch marker"
  else
    grep -q 'Flutter run key commands' "$SESSION/frontend.log" 2>/dev/null || bad "✗ frontend.log never reached resident app"
  fi
  if grep -Eq 'Unhandled exception|══╡ EXCEPTION CAUGHT|FlutterError|Lost connection to device|Dart (Error|Exception)' "$SESSION/frontend.log" 2>/dev/null; then
    bad "✗ frontend.log contains an unreviewed Flutter failure"
  fi
  AX_PATTERN='accessibility_bridge\.cc.*Failed to update ui::AXTree, error: [0-9][0-9]* will not be in the tree and is not the new root'
  if grep -Eq 'accessibility_bridge\.cc.*Failed to update ui::AXTree' "$SESSION/frontend.log" 2>/dev/null; then
    AX_REVIEW="$SESSION/evidence/frontend-ax-review.md"
    if grep -E 'accessibility_bridge\.cc.*Failed to update ui::AXTree' "$SESSION/frontend.log" | grep -Ev "$AX_PATTERN" >/dev/null 2>&1; then
      bad "✗ frontend.log contains an unknown accessibility bridge failure"
    elif [ -s "$AX_REVIEW" ] && grep -Eq '^classification: tooling-ax-tree$' "$AX_REVIEW" && grep -Eq '^status: reviewed$' "$AX_REVIEW"; then
      note "· frontend AXTree bridge churn explicitly reviewed as tooling noise; evidence: $AX_REVIEW"
    else
      bad "✗ frontend.log contains AXTree bridge churn without a session review"
    fi
  fi

  if [ -n "$AWID" ] && [ -n "$AWBOUNDS" ] && alive_as "$RECORDER_PID" "screencapture.*-v.*-l[[:space:]]$AWID([[:space:]]|$)"; then
    note "✓ channel 1 Anselm-window recorder alive (PID $RECORDER_PID, window $AWID, bounds $AWBOUNDS)"
    if [ -s "$RLIFE" ] && python3 - "$RLIFE" "$RECORDER_PID" <<'PY'
import datetime
import json
import sys

row = json.load(open(sys.argv[1], encoding="utf-8"))
if str(row.get("pid")) != sys.argv[2]:
    raise SystemExit(1)
requested = datetime.datetime.fromisoformat(row["spawnRequestedAt"].replace("Z", "+00:00"))
returned = datetime.datetime.fromisoformat(row["spawnReturnedAt"].replace("Z", "+00:00"))
if returned < requested:
    raise SystemExit(1)
PY
    then
      note "✓ channel 1 recorder lifecycle has microsecond spawn bracket"
    else
      bad "✗ channel 1 recorder lifecycle is missing, malformed, or attributed to another PID"
    fi
  elif [ -n "$AWID" ] && [ -z "$AWBOUNDS" ]; then
    bad "✗ channel 1 manifest has no Anselm window geometry — refusing unbounded overlay recording"
  elif [ -n "$AWID" ]; then
    bad "✗ channel 1 recorder is not bound to Anselm app region $AWBOUNDS"
  elif alive_as "$RECORDER_PID" 'screencapture.*-v'; then
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
