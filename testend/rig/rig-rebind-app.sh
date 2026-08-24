#!/usr/bin/env bash
# Rebind channel 1/4 after the product deliberately relaunches the real App.
# This is explicit and fail-closed: it never adopts an external or ambiguous process.
set -euo pipefail

source "$(dirname "$0")/scope.sh"

case "${1:-}" in
  "") ;;
  -h|--help)
    cat <<'EOF'
Usage: testend/rig/rig-rebind-app.sh

Rebind the current rig to the single new Anselm process after an in-product relaunch.
The old process must be dead, the replacement must use the manifest's exact binary, and
its Anselm window must be observable. A geometry change is handled by sealing the old
window-region segment and starting a new, explicitly attributed segment; it is never
silently recorded with a stale crop.
EOF
    exit 0
    ;;
  *)
    echo "Usage: testend/rig/rig-rebind-app.sh" >&2
    exit 2
    ;;
esac

require_rig_home
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

MANIFEST="$RIG_HOME/current/manifest.json"
[ -f "$MANIFEST" ] || { echo "✗ no current rig manifest" >&2; exit 1; }

field() { python3 -c "import json; print(json.load(open('$MANIFEST')).get('$1',''))"; }
alive_exact() {
  local pid="${1:-}" binary="${2:-}"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ "$(ps -o command= -p "$pid" | sed 's/[[:space:]]*$//')" = "$binary" ]
}

SESSION=$(field session)
OLD_PID=$(field appPid)
BINARY=$(field appBinary)
OLD_WINDOW_ID=$(field appWindowId)
OLD_BOUNDS=$(field appWindowBounds)
RECORDER_PID=$(field recorderPid)
JOURNAL=$(field appRebindJournal)
APP_OWNS_BACKEND=$(field appOwnsBackend)
OLD_BACKEND_PID=$(field appSidecarPid)
OLD_TAP_PID=$(field tapPid)
APP_AUTH_TOKEN_FILE=$(field appAuthTokenFile)
[ -n "$SESSION" ] && [ -d "$SESSION" ] || { echo "✗ manifest session is missing" >&2; exit 1; }
[ -n "$OLD_PID" ] && [ -n "$BINARY" ] && [ -n "$OLD_WINDOW_ID" ] && [ -n "$OLD_BOUNDS" ] || {
  echo "✗ manifest lacks exact App identity or recorded geometry" >&2
  exit 1
}
[ -n "$JOURNAL" ] || JOURNAL="$SESSION/app-rebind.jsonl"

if alive_exact "$OLD_PID" "$BINARY"; then
  echo "✗ old App PID $OLD_PID is still alive; refusing to adopt another process" >&2
  exit 1
fi

 CANDIDATE_LIST=$(ps -axo pid=,command= | awk -v binary="$BINARY" '
  { pid=$1; $1=""; sub(/^[[:space:]]+/, ""); if ($0 == binary) print pid }
')
CANDIDATE_COUNT=$(printf '%s\n' "$CANDIDATE_LIST" | awk 'NF {count++} END {print count+0}')
if [ "$CANDIDATE_COUNT" -ne 1 ]; then
  printf '✗ expected exactly one replacement App using the manifest binary, found %s:' "$CANDIDATE_COUNT" >&2
  printf ' %s' "$CANDIDATE_LIST" >&2
  printf '\n' >&2
  exit 1
fi
NEW_PID=$(printf '%s\n' "$CANDIDATE_LIST" | awk 'NF {print $1; exit}')
[ "$NEW_PID" != "$OLD_PID" ] || { echo "✗ replacement PID equals the dead manifest PID" >&2; exit 1; }

WINDOW_INFO=$(swift -e '
import Foundation
import CoreGraphics
let target = Int(CommandLine.arguments[1])!
let ws = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for w in ws {
  let owner = w[kCGWindowOwnerName as String] as? String ?? ""
  let name = w[kCGWindowName as String] as? String ?? ""
  let pid = w[kCGWindowOwnerPID as String] as? Int ?? -1
  if pid == target && owner.lowercased() == "anselm" && name == "anselm",
     let b = w[kCGWindowBounds as String] as? [String: Any],
     let x = b["X"] as? NSNumber, let y = b["Y"] as? NSNumber,
     let width = b["Width"] as? NSNumber, let height = b["Height"] as? NSNumber {
    let id = w[kCGWindowNumber as String] ?? -1
    print("\(id)|\(x.intValue),\(y.intValue),\(width.intValue),\(height.intValue)")
    exit(0)
  }
}
' "$NEW_PID" 2>/dev/null | tr -d '[:space:]')
[ -n "$WINDOW_INFO" ] || { echo "✗ replacement App has no Anselm window" >&2; exit 1; }
NEW_WINDOW_ID="${WINDOW_INFO%%|*}"
NEW_BOUNDS="${WINDOW_INFO#*|}"
if [ -n "$RECORDER_PID" ] && ! kill -0 "$RECORDER_PID" 2>/dev/null; then
  echo "✗ recorder is not alive; rebind cannot restore channel 1 evidence" >&2
  exit 1
fi

NEW_RECORDER_PID="$RECORDER_PID"
NEW_RECORDING_LIFECYCLE=$(field recordingLifecycle)
NEW_RECORDING_FILE="$SESSION/screen.mov"
if [ "$NEW_WINDOW_ID" != "$OLD_WINDOW_ID" ] || [ "$NEW_BOUNDS" != "$OLD_BOUNDS" ]; then
  if [ "$NEW_WINDOW_ID" != "$OLD_WINDOW_ID" ] && [ "$NEW_BOUNDS" != "$OLD_BOUNDS" ]; then
    echo "· replacement window identity and geometry changed ($OLD_WINDOW_ID/$OLD_BOUNDS → $NEW_WINDOW_ID/$NEW_BOUNDS); rotating the recording segment"
  elif [ "$NEW_WINDOW_ID" != "$OLD_WINDOW_ID" ]; then
    echo "· replacement window identity changed ($OLD_WINDOW_ID → $NEW_WINDOW_ID) with unchanged geometry; rotating the recording segment"
  else
    echo "· replacement window geometry changed ($OLD_BOUNDS → $NEW_BOUNDS); rotating the recording segment"
  fi
  case "$(ps -o command= -p "$RECORDER_PID" 2>/dev/null || true)" in
    *"screencapture"*) kill -INT "$RECORDER_PID" 2>/dev/null || true ;;
    *) echo "✗ refusing to rotate a non-screencapture recorder PID $RECORDER_PID" >&2; exit 1 ;;
  esac
  for _ in $(seq 1 40); do
    kill -0 "$RECORDER_PID" 2>/dev/null && sleep 0.25 || break
  done
  if kill -0 "$RECORDER_PID" 2>/dev/null; then
    kill -KILL "$RECORDER_PID" 2>/dev/null || true
    echo "✗ old recorder did not seal after INT" >&2
    exit 1
  fi
  NEW_RECORDING_FILE="$SESSION/screen-rebind-${NEW_PID}.mov"
  NEW_RECORDING_LIFECYCLE="$SESSION/recording-rebind-${NEW_PID}.json"
  NEW_RECORDER_PID=$(python3 "$ROOT/testend/rig/spawn.py" --cwd "$ROOT" --out "$SESSION/recording.log" \
    --lifecycle "$NEW_RECORDING_LIFECYCLE" -- \
    screencapture -v -C -k -l "$NEW_WINDOW_ID" "$NEW_RECORDING_FILE")
  sleep 1
  kill -0 "$NEW_RECORDER_PID" 2>/dev/null || {
    echo "✗ replacement screen recorder exited — check $SESSION/recording.log" >&2
    exit 1
  }
fi

NEW_BACKEND_PID=""
NEW_PORT=""
NEW_TAP_PID="$OLD_TAP_PID"
if [ "$APP_OWNS_BACKEND" = "1" ]; then
  for _ in $(seq 1 240); do
    NEW_BACKEND_PID=$(ps -axo pid=,ppid=,command= | awk -v parent="$NEW_PID" \
      '$2 == parent && $0 ~ /\/anselm\.app\/Contents\/MacOS\/anselm-server([ ]|$)/ {print $1; exit}')
    if [ -n "$NEW_BACKEND_PID" ]; then
      NEW_PORT=$(lsof -a -p "$NEW_BACKEND_PID" -iTCP -sTCP:LISTEN -n -P 2>/dev/null | \
        sed -n '2,$p' | sed -n 's/.*127\.0\.0\.1:\([0-9][0-9]*\).*/\1/p' | head -1)
      [ -n "$NEW_PORT" ] && break
    fi
    sleep 0.25
  done
  [ -n "$NEW_BACKEND_PID" ] && [ -n "$NEW_PORT" ] || {
    echo "✗ replacement App has no discoverable owned sidecar listener" >&2
    exit 1
  }
  NEW_AUTH_TOKEN=$(ps eww -p "$NEW_BACKEND_PID" | sed -n 's/.*ANSELM_AUTH_TOKEN=\([^ ]*\).*/\1/p' | head -1)
  [ -n "$NEW_AUTH_TOKEN" ] || { echo "✗ replacement sidecar exposes no auth token" >&2; exit 1; }
  printf '%s\n' "$NEW_AUTH_TOKEN" >"$APP_AUTH_TOKEN_FILE"
  chmod 600 "$APP_AUTH_TOKEN_FILE"
  curl -sf "http://127.0.0.1:$NEW_PORT/api/v1/health" \
    -H "Authorization: Bearer $NEW_AUTH_TOKEN" >/dev/null || {
    echo "✗ replacement sidecar health gate failed on :$NEW_PORT" >&2
    exit 1
  }

  if [ -n "$OLD_TAP_PID" ] && kill -0 "$OLD_TAP_PID" 2>/dev/null; then
    case "$(ps -o command= -p "$OLD_TAP_PID" 2>/dev/null || true)" in
      *"/ssetap"*) kill -TERM "$OLD_TAP_PID" 2>/dev/null || true ;;
      *) echo "✗ refusing to stop non-ssetap PID $OLD_TAP_PID" >&2; exit 1 ;;
    esac
    for _ in $(seq 1 40); do kill -0 "$OLD_TAP_PID" 2>/dev/null && sleep 0.25 || break; done
    kill -KILL "$OLD_TAP_PID" 2>/dev/null || true
  fi
  NEW_TAP_PID=$(python3 "$ROOT/testend/rig/spawn.py" --cwd "$ROOT" --out "$SESSION/ssetap.log" -- \
    "$RIG_HOME/bin/ssetap" -base "http://127.0.0.1:$NEW_PORT" -all-workspaces \
    -token "$NEW_AUTH_TOKEN" -out "$SESSION/sse.jsonl")
fi

NOW=$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)
python3 - "$MANIFEST" "$JOURNAL" "$OLD_PID" "$NEW_PID" "$NEW_WINDOW_ID" "$NEW_BOUNDS" \
  "$NOW" "$NEW_BACKEND_PID" "$NEW_PORT" "$NEW_TAP_PID" "$NEW_RECORDER_PID" \
  "$NEW_RECORDING_LIFECYCLE" "$NEW_RECORDING_FILE" <<'PY'
import json
import os
import sys
import tempfile

manifest_path, journal_path, old_pid, new_pid, window_id, bounds, now, backend_pid, port, tap_pid, recorder_pid, recording_lifecycle, recording_file = sys.argv[1:]
with open(manifest_path, encoding="utf-8") as f:
    manifest = json.load(f)
previous = int(manifest.get("appRebindCount", 0))
old_backend = manifest.get("backendPid", "")
event = {
    "ts": now,
    "event": "app_rebounded",
    "fromPid": old_pid,
    "toPid": new_pid,
    "windowId": window_id,
    "bounds": bounds,
    "binary": manifest["appBinary"],
}
manifest["appLaunchPid"] = new_pid
manifest["appPid"] = new_pid
manifest["appWindowId"] = window_id
manifest["appWindowBounds"] = bounds
manifest["appRebindCount"] = previous + 1
manifest["lastAppRebindAt"] = now
manifest["lastAppRebindFromPid"] = old_pid
manifest["lastAppRebindToPid"] = new_pid
manifest["recorderPid"] = recorder_pid
manifest["recordingLifecycle"] = recording_lifecycle
segments = manifest.get("screenRecordingSegments", [manifest.get("session", "") + "/screen.mov"])
if recording_file not in segments:
    segments.append(recording_file)
manifest["screenRecordingSegments"] = segments
if backend_pid:
    manifest["backendPid"] = backend_pid
    manifest["appSidecarPid"] = backend_pid
    manifest["port"] = int(port)
    manifest["appBackendUrl"] = f"http://127.0.0.1:{port}"
    manifest["tapPid"] = tap_pid
    event["backendFromPid"] = old_backend
    event["backendToPid"] = backend_pid
    event["port"] = int(port)

directory = os.path.dirname(manifest_path)
fd, temp_path = tempfile.mkstemp(prefix="manifest.", dir=directory, text=True)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
        f.flush()
        os.fsync(f.fileno())
    os.replace(temp_path, manifest_path)
finally:
    if os.path.exists(temp_path):
        os.unlink(temp_path)

with open(journal_path, "a", encoding="utf-8") as f:
    f.write(json.dumps(event, ensure_ascii=False) + "\n")
PY
printf '[conductor] App rebound (PID %s → %s; window %s; bounds %s)\n' \
  "$OLD_PID" "$NEW_PID" "$NEW_WINDOW_ID" "$NEW_BOUNDS" >>"$SESSION/frontend.log"
if [ "$APP_OWNS_BACKEND" = "1" ]; then
  echo "✓ App + owned sidecar rebound: App $OLD_PID → $NEW_PID; backend $OLD_BACKEND_PID → $NEW_BACKEND_PID; port :$NEW_PORT; recorder $NEW_RECORDER_PID"
else
  echo "✓ App rebound: PID $OLD_PID → $NEW_PID; window $NEW_WINDOW_ID; recorder $NEW_RECORDER_PID"
fi
