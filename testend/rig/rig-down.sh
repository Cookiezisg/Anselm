#!/usr/bin/env bash
# rig-down stops only processes whose current command still matches the role recorded in manifest.
# This prevents a stale manifest from killing an unrelated process after PID reuse.
set -euo pipefail

source "$(dirname "$0")/scope.sh"
case "${1:-}" in
  "") ;;
  -h|--help)
    cat <<'EOF'
Usage: testend/rig/rig-down.sh

Stop and finalize the live rig selected by the explicitly exported absolute RIG_HOME.
EOF
    exit 0
    ;;
  *)
    echo "Usage: testend/rig/rig-down.sh" >&2
    exit 2
    ;;
esac
require_rig_home
MANIFEST="$RIG_HOME/current/manifest.json"
[ -f "$MANIFEST" ] || { echo "✗ no live rig session"; exit 1; }
field() { python3 -c "import json; print(json.load(open('$MANIFEST')).get('$1',''))"; }
matches() {
  local pid="$1" pattern="$2"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && ps -o command= -p "$pid" | grep -Eq "$pattern"
}
stop_matching() {
  local label="$1" pid="$2" pattern="$3" signal="${4:-TERM}"
  if matches "$pid" "$pattern"; then
    kill -"$signal" -"$pid"
    for _ in $(seq 1 40); do kill -0 "$pid" 2>/dev/null || break; sleep 0.25; done
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL -"$pid" 2>/dev/null || true
      echo "⚠ $label required SIGKILL"
    else
      echo "✓ $label stopped"
    fi
  elif [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    echo "✗ refusing to kill PID $pid for $label: command identity no longer matches" >&2
    return 1
  else
    echo "· $label already gone"
  fi
}
stop_exact() {
  local label="$1" pid="$2" pattern="$3" signal="${4:-TERM}"
  if matches "$pid" "$pattern"; then
    kill -"$signal" "$pid"
    for _ in $(seq 1 40); do kill -0 "$pid" 2>/dev/null || break; sleep 0.25; done
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
      echo "⚠ $label required SIGKILL"
    else
      echo "✓ $label stopped"
    fi
  elif [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    echo "✗ refusing to kill PID $pid for $label: command identity no longer matches" >&2
    return 1
  else
    echo "· $label already gone"
  fi
}

SESSION=$(field session)
RUNNER_PID=$(field runnerPid)
APP_LAUNCH_PID=$(field appLaunchPid)
APP_PID=$(field appPid)
BACKEND_PID=$(field backendPid)
APP_OWNS_BACKEND=$(field appOwnsBackend)
TAP_PID=$(field tapPid)
LLMTAP_PID=$(field llmtapPid)
APP_PROXY_PID=$(field appProxyPid)
RECORDER_PID=$(field recorderPid)

# Seal the frame channel before taking the App away. Otherwise the tail of the MOV records the desktop
# exposed after the App exits, which makes a valid in-run frame look like a false final product frame.
# Recorder receives INT so screencapture writes the MOV trailer instead of leaving an unreadable file.
stop_matching "screen recorder" "$RECORDER_PID" 'screencapture.*-v' INT

# The runner and the actual app have separate PIDs: stopping only the runner can leave a detached macOS
# app behind. Then stop the backend and taps; their terminal events remain journaled even though the frame
# witness is already sealed.
stop_matching "Flutter runner" "$RUNNER_PID" 'flutter_tools\.snapshot run'
stop_exact "Flutter app" "$APP_PID" '/anselm\.app/Contents/MacOS/anselm($| )'
stop_matching "App API perturbation proxy" "$APP_PROXY_PID" '/appproxy($| )'
stop_matching "backend" "$BACKEND_PID" '/server($| )'
stop_matching "ssetap" "$TAP_PID" '/ssetap($| )'
stop_matching "llmtap" "$LLMTAP_PID" '/llmtap($| )'

if [ "$APP_OWNS_BACKEND" = "1" ]; then
  # BackendController captured the owned sidecar stderr in frontend.log. Seal its channel-2
  # projection only after the App and child have stopped so no final lines are lost.
  awk '
    /\[backend\] / { sub(/^.*\[backend\] /, ""); print; next }
    /^flutter: 20[0-9][0-9]-[0-9][0-9-]+T/ { sub(/^flutter: /, ""); print }
  ' "$SESSION/frontend.log" >"$SESSION/backend.log"
fi

if [ -f "$SESSION/recording.disabled" ]; then
  echo "· recording disabled — channel 1 was intentionally omitted"
elif [ ! -s "$SESSION/screen.mov" ]; then
  # A successful shutdown without a sealed MOV is not an acceptance session. Do not let a
  # missing recorder artifact silently turn a five-channel run into a four-channel claim.
  rm -f "$RIG_HOME/current"
  echo "✗ screen.mov is missing or empty; evidence channel 1 invalid" >&2
  exit 1
else
  ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$SESSION/screen.mov" >"$SESSION/screen.duration" 2>"$SESSION/ffprobe.log" || {
    echo "✗ screen.mov is not readable; evidence channel 1 invalid" >&2; exit 1;
  }
  echo "✓ recording finalized ($(cat "$SESSION/screen.duration")s)"
fi

rm -f "$RIG_HOME/current"
echo "✓ rig down — journals preserved in $SESSION"
