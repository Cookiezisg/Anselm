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
TAP_PID=$(field tapPid)
LLMTAP_PID=$(field llmtapPid)
APP_PROXY_PID=$(field appProxyPid)
RECORDER_PID=$(field recorderPid)

# App first: it observes an orderly end instead of a manufactured backend outage. The runner and the
# actual app have separate PIDs: stopping only the runner can leave a detached macOS app behind.
# Backend then drains
# while ssetap remains connected to witness its terminal frames. Recorder is last and receives INT so
# screencapture writes the MOV trailer instead of leaving an unreadable file.
stop_matching "Flutter runner" "$RUNNER_PID" 'flutter_tools\.snapshot run'
stop_exact "Flutter app" "$APP_PID" '/anselm\.app/Contents/MacOS/anselm($| )'
stop_matching "App API perturbation proxy" "$APP_PROXY_PID" '/appproxy($| )'
stop_matching "backend" "$BACKEND_PID" '/server($| )'
stop_matching "ssetap" "$TAP_PID" '/ssetap($| )'
stop_matching "llmtap" "$LLMTAP_PID" '/llmtap($| )'
stop_matching "screen recorder" "$RECORDER_PID" 'screencapture.*-v' INT

if [ -f "$SESSION/screen.mov" ]; then
  ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$SESSION/screen.mov" >"$SESSION/screen.duration" 2>"$SESSION/ffprobe.log" || {
    echo "✗ screen.mov is not readable; evidence channel 1 invalid" >&2; exit 1;
  }
  echo "✓ recording finalized ($(cat "$SESSION/screen.duration")s)"
fi

rm -f "$RIG_HOME/current"
echo "✓ rig down — journals preserved in $SESSION"
