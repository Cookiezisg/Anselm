#!/usr/bin/env bash
# rig-up owns every acceptance observer and the real Flutter app. A channel that merely could run
# is not evidence; the conductor starts it, records its PID, and refuses success until it is alive.
#
# rig-up 亲自持有每个验收观察者与真实 Flutter app。一个「理论上能跑」的通道不算证据；导演器
# 必须启动它、记录 PID，并在它真实存活前拒绝报绿。
set -euo pipefail

source "$(dirname "$0")/scope.sh"

usage() {
  cat <<'EOF'
Usage: testend/rig/rig-up.sh

Start a complete acceptance rig. Configure the rig with environment variables such as
RIG_HOME, RIG_PORT, RIG_DATA, RIG_SEED, RIG_LLMTAP, RIG_RECORD, RIG_APP, RIG_APP_FIRST,
RIG_EXPECT_BACKEND_FAILURE, RIG_STARTUP_FAILURE_SETTLE_SEC,
RIG_BACKEND_START_DELAY_SEC, RIG_APP_PROXY, RIG_APP_PROXY_PORT, RIG_APP_PROXY_DELAY_MS,
RIG_APP_PROXY_FAIL_COUNT, RIG_APP_PROXY_FAIL_STATUS, RIG_LLMTAP_FAIL_PATH, RIG_LLMTAP_FAIL_COUNT,
RIG_LLMTAP_FAIL_STATUS, RIG_LLMTAP_FAIL_KIND (including speech-handshake, speech-upstream-closed, and speech-frame-invalid), RIG_LLMTAP_INJECT_WAV_METADATA,
RIG_BACKEND_AUTH_TOKEN,
RIG_APP_PROXY_AUTH_TOKEN, RIG_APP_PROXY_AUTH_PATH, RIG_APP_PROXY_DROP_WORKSPACE_HEADER_COUNT,
RIG_APP_PROXY_REWRITE_HOST_PATH, RIG_APP_PROXY_REWRITE_HOST, RIG_APP_PROXY_REWRITE_HOST_COUNT,
RIG_APP_PROXY_REWRITE_PATH_FROM, RIG_APP_PROXY_REWRITE_PATH_TO, RIG_APP_PROXY_REWRITE_PATH_COUNT,
RIG_APP_PROXY_REWRITE_METHOD_PATH, RIG_APP_PROXY_REWRITE_METHOD_FROM, RIG_APP_PROXY_REWRITE_METHOD_TO,
RIG_APP_PROXY_REWRITE_METHOD_COUNT,
RIG_APP_ARGS (space-separated arguments passed to the direct macOS App),
RIG_ENGINE_SWITCHES (space-separated Flutter engine switches),
ANSELM_RIG_MODEL_CATALOG_URL,
ANSELM_RIG_MEDIA_PROCESS_DELAY_MS, ANSELM_RIG_PREFILL_SKILL_SOURCE.
The command takes no positional arguments; use --help only to print this message.
EOF
}

case "${1:-}" in
  "") ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

require_rig_home

cd "$(dirname "$0")/../.."
ROOT="$(pwd)"
PORT="${RIG_PORT:-8742}"
SESSION="$RIG_HOME/sessions/$(date +%Y%m%d-%H%M%S)"
SEED="${RIG_SEED:-1}"
DATA="${RIG_DATA:-$RIG_HOME/data}"
BACKEND_WAIT_SEC="${RIG_BACKEND_WAIT_SEC:-60}"
LLMTAP="${RIG_LLMTAP:-1}"
LLMTAP_PORT="${RIG_LLMTAP_PORT:-8788}"
LLM_UPSTREAM="${RIG_LLM_UPSTREAM:-https://api.anselm.website}"
LLMTAP_FAIL_PATH="${RIG_LLMTAP_FAIL_PATH:-}"
LLMTAP_FAIL_COUNT="${RIG_LLMTAP_FAIL_COUNT:-0}"
LLMTAP_FAIL_STATUS="${RIG_LLMTAP_FAIL_STATUS:-503}"
LLMTAP_FAIL_KIND="${RIG_LLMTAP_FAIL_KIND:-generic}"
LLMTAP_INJECT_WAV_METADATA="${RIG_LLMTAP_INJECT_WAV_METADATA:-0}"
RECORD="${RIG_RECORD:-1}"
APP="${RIG_APP:-1}"
APP_FIRST="${RIG_APP_FIRST:-0}"
APP_OWNS_BACKEND="${RIG_APP_OWNS_BACKEND:-0}"
EXPECTED_BACKEND_FAILURE="${RIG_EXPECT_BACKEND_FAILURE:-0}"
STARTUP_FAILURE_SETTLE_SEC="${RIG_STARTUP_FAILURE_SETTLE_SEC:-3}"
BACKEND_START_DELAY_SEC="${RIG_BACKEND_START_DELAY_SEC:-0}"
APP_PROXY="${RIG_APP_PROXY:-0}"
APP_PROXY_PORT="${RIG_APP_PROXY_PORT:-8790}"
APP_PROXY_DELAY_MS="${RIG_APP_PROXY_DELAY_MS:-0}"
APP_PROXY_PATH="${RIG_APP_PROXY_PATH:-/api/v1/workspaces}"
APP_PROXY_FAIL_COUNT="${RIG_APP_PROXY_FAIL_COUNT:-0}"
APP_PROXY_FAIL_STATUS="${RIG_APP_PROXY_FAIL_STATUS:-503}"
APP_PROXY_DROP_AFTER_MS="${RIG_APP_PROXY_DROP_AFTER_MS:-0}"
APP_PROXY_DROP_COUNT="${RIG_APP_PROXY_DROP_COUNT:-0}"
APP_PROXY_FAIL_AFTER_DROP_COUNT="${RIG_APP_PROXY_FAIL_AFTER_DROP_COUNT:-0}"
APP_PROXY_FAIL_AFTER_DROP_DELAY_MS="${RIG_APP_PROXY_FAIL_AFTER_DROP_DELAY_MS:-0}"
APP_PROXY_AUTH_TOKEN="${RIG_APP_PROXY_AUTH_TOKEN:-}"
APP_PROXY_AUTH_PATH="${RIG_APP_PROXY_AUTH_PATH:-}"
APP_PROXY_DROP_WORKSPACE_HEADER_COUNT="${RIG_APP_PROXY_DROP_WORKSPACE_HEADER_COUNT:-0}"
APP_PROXY_REWRITE_HOST_PATH="${RIG_APP_PROXY_REWRITE_HOST_PATH:-}"
APP_PROXY_REWRITE_HOST="${RIG_APP_PROXY_REWRITE_HOST:-}"
APP_PROXY_REWRITE_HOST_COUNT="${RIG_APP_PROXY_REWRITE_HOST_COUNT:-0}"
APP_PROXY_REWRITE_PATH_FROM="${RIG_APP_PROXY_REWRITE_PATH_FROM:-}"
APP_PROXY_REWRITE_PATH_TO="${RIG_APP_PROXY_REWRITE_PATH_TO:-}"
APP_PROXY_REWRITE_PATH_COUNT="${RIG_APP_PROXY_REWRITE_PATH_COUNT:-0}"
APP_PROXY_REWRITE_METHOD_PATH="${RIG_APP_PROXY_REWRITE_METHOD_PATH:-}"
APP_PROXY_REWRITE_METHOD_FROM="${RIG_APP_PROXY_REWRITE_METHOD_FROM:-}"
APP_PROXY_REWRITE_METHOD_TO="${RIG_APP_PROXY_REWRITE_METHOD_TO:-}"
APP_PROXY_REWRITE_METHOD_COUNT="${RIG_APP_PROXY_REWRITE_METHOD_COUNT:-0}"
APP_BACKEND_URL="http://127.0.0.1:$PORT"
MISE="${MISE:-mise}"
PREFILL_SKILL_SOURCE_CONFIGURED=False
[ -n "${ANSELM_RIG_PREFILL_SKILL_SOURCE:-}" ] && PREFILL_SKILL_SOURCE_CONFIGURED=True

BACKEND_PID=""
APP_SIDECAR_PID=""
APP_AUTH_TOKEN=""
APP_AUTH_TOKEN_FILE=""
BACKEND_AUTH_TOKEN="${RIG_BACKEND_AUTH_TOKEN:-}"
BACKEND_AUTH_TOKEN_FILE=""
BACKEND_LOG_PID=""
TAP_PID=""
LLMTAP_PID=""
APP_PROXY_PID=""
APP_PROXY_JOURNAL=""
RUNNER_PID=""
APP_LAUNCH_PID=""
APP_PID=""
APP_BINARY=""
APP_ARGS_STRING="${RIG_APP_ARGS:-}"
APP_ARGS=()
if [ -n "$APP_ARGS_STRING" ]; then
  read -r -a APP_ARGS <<<"$APP_ARGS_STRING"
fi
ENGINE_SWITCHES_STRING="${RIG_ENGINE_SWITCHES:-}"
ENGINE_SWITCHES=()
ENGINE_ENV=()
if [ -n "$ENGINE_SWITCHES_STRING" ]; then
  read -r -a ENGINE_SWITCHES <<<"$ENGINE_SWITCHES_STRING"
  ENGINE_ENV+=("FLUTTER_ENGINE_SWITCHES=${#ENGINE_SWITCHES[@]}")
  for i in "${!ENGINE_SWITCHES[@]}"; do
    ENGINE_ENV+=("FLUTTER_ENGINE_SWITCH_$((i + 1))=${ENGINE_SWITCHES[$i]}")
  done
fi
APP_WINDOW_ID=""
APP_WINDOW_BOUNDS=""
RECORDER_PID=""
RECORDER_LIFECYCLE=""
BASELINE_APP_PIDS=""
BASELINE_APP_PIDS_CAPTURED=0
ARMED=1

stop_pid() {
  local pid="${1:-}" signal="${2:-TERM}"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && kill -"$signal" -"$pid" 2>/dev/null || true
}

stop_exact_pid() {
  local pid="${1:-}" signal="${2:-TERM}"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && kill -"$signal" "$pid" 2>/dev/null || true
}

app_pids() {
  ps -axo pid=,command= | awk '$0 ~ /\/anselm\.app\/Contents\/MacOS\/anselm([ ]|$)/ {print $1}'
}

listener_pid() {
  local pids
  pids=$(lsof -ti ":$1" -sTCP:LISTEN 2>/dev/null || true)
  printf '%s\n' "$pids" | awk 'NF {print; exit}'
}

stop_new_apps() {
  local pid
  for pid in $(app_pids); do
    case " $BASELINE_APP_PIDS " in
      *" $pid "*) ;;
      *) stop_exact_pid "$pid" ;;
    esac
  done
}

cleanup_failed_start() {
  [ "$ARMED" = "1" ] || return
  stop_exact_pid "$APP_PID"
  # Before start_app_and_record captures a baseline, every visible App is external to this
  # attempt. Never kill it while cleaning up an early preflight failure (for example, a port
  # collision with an already-running rig). 在捕获 baseline 前，所有 App 都不属于本次尝试；
  # 前置失败清理不能把现有台架的 App 当成新进程误杀。
  [ "$BASELINE_APP_PIDS_CAPTURED" = "1" ] && stop_new_apps
  stop_pid "$APP_LAUNCH_PID"
  stop_pid "$RUNNER_PID"
  stop_pid "$APP_PROXY_PID"
  stop_pid "$BACKEND_PID"
  stop_pid "$TAP_PID"
  stop_pid "$LLMTAP_PID"
  stop_pid "$RECORDER_PID" INT
}
trap cleanup_failed_start EXIT INT TERM

startup_event() {
  printf '{"ts":"%s","event":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)" "$1" >>"$SESSION/startup-gate.jsonl"
}

check_screen_recording_permission() {
  # Diagnostic runs deliberately skip TCC probing; an intentional skip is success, not a
  # `set -e` failure. 诊断模式刻意跳过 TCC 探测；这是成功跳过，不应被 `set -e` 当成失败。
  [ "$RECORD" = "1" ] || return 0
  local probe_dir probe_file
  probe_dir=$(mktemp -d "${TMPDIR:-/tmp}/anselm-rig-screen.XXXXXX")
  probe_file="$probe_dir/permission.png"
  if ! screencapture -x "$probe_file" >/dev/null 2>&1 || [ ! -s "$probe_file" ]; then
    rm -rf "$probe_dir"
    echo "✗ Screen Recording permission unavailable — grant it to the current Anselm build before rig-up" >&2
    echo "  No backend, observer, Flutter build, or App was started; channel 1 is required for acceptance." >&2
    exit 1
  fi
  rm -rf "$probe_dir"
  startup_event screen_recording_permission_ok
}

start_app_and_record() {
  if [ "$APP" != "1" ]; then
    : >"$SESSION/frontend.disabled"
    return
  fi
  BASELINE_APP_PIDS=$(app_pids)
  BASELINE_APP_PIDS_CAPTURED=1
  EXISTING_APP_PIDS="$BASELINE_APP_PIDS"
  [ -z "$EXISTING_APP_PIDS" ] || {
    echo "✗ Anselm App already running (PID $EXISTING_APP_PIDS); the rig never adopts an external App" >&2
    echo "  Close that App or use a fresh acceptance machine before starting the rig." >&2
    exit 1
  }
  : >"$SESSION/frontend.log"
  : >"$SESSION/frontend-build.log"
  startup_event app_build_requested
  if [ -n "${ANSELM_RIG_PREFILL_SKILL_SOURCE:-}" ]; then
    FRONTEND_BUILD=(--dart-define="ANSELM_RIG_PREFILL_SKILL_SOURCE=${ANSELM_RIG_PREFILL_SKILL_SOURCE}")
  else
    FRONTEND_BUILD=()
  fi
  if [ "${#FRONTEND_BUILD[@]}" -eq 0 ]; then
    (cd "$ROOT/frontend" && "$MISE" exec -- flutter build macos --debug -t lib/main.dart) \
      >"$SESSION/frontend-build.log" 2>&1 || {
      echo "✗ Flutter macOS build failed" >&2
      tail -80 "$SESSION/frontend-build.log" >&2
      exit 1
    }
  elif ! (cd "$ROOT/frontend" && "$MISE" exec -- flutter build macos --debug -t lib/main.dart "${FRONTEND_BUILD[@]}") \
      >"$SESSION/frontend-build.log" 2>&1; then
    echo "✗ Flutter macOS build failed" >&2
    tail -80 "$SESSION/frontend-build.log" >&2
    exit 1
  fi
  APP_BINARY="$ROOT/frontend/build/macos/Build/Products/Debug/anselm.app/Contents/MacOS/anselm"
  [ -x "$APP_BINARY" ] || {
    echo "✗ built macOS App binary missing: $APP_BINARY" >&2
    exit 1
  }
  # The build is long enough for a Computer Use probe (or another launcher) to start
  # an App after the initial baseline check. Re-check immediately before launch so
  # the conductor never races an unowned process into the same bundle.
  EXISTING_APP_PIDS=$(app_pids)
  [ -z "$EXISTING_APP_PIDS" ] || {
    echo "✗ Anselm App appeared during build (PID $EXISTING_APP_PIDS); refusing an ambiguous rig" >&2
    exit 1
  }
  startup_event app_launch_requested
  launch_direct_app() {
    local -a command=(env)
    if [ "$APP_OWNS_BACKEND" = "1" ]; then
      command+=(
        ANSELM_DEV=1
        ANSELM_DATA_DIR="$DATA"
        ANSELM_RELAUNCH_LOG="$SESSION/frontend.log"
        LANG=en_US.UTF-8
      )
      command+=("${GATEWAY_ENV[@]}")
    else
      command+=(
        ANSELM_BACKEND_URL="$APP_BACKEND_URL"
        ANSELM_DATA_DIR="$DATA"
        ANSELM_RELAUNCH_LOG="$SESSION/frontend.log"
        LANG=en_US.UTF-8
      )
    fi
    if [ "${#ENGINE_ENV[@]}" -gt 0 ]; then
      command+=("${ENGINE_ENV[@]}")
    fi
    command+=("$APP_BINARY")
    if [ "${#APP_ARGS[@]}" -gt 0 ]; then
      command+=("${APP_ARGS[@]}")
    fi
    python3 "$ROOT/testend/rig/spawn.py" --cwd "$ROOT" --out "$SESSION/frontend.log" -- "${command[@]}"
  }
  if [ "$APP_OWNS_BACKEND" = "1" ]; then
    # The production App owns this child.  Keep the sidecar next to the exact bundle executable so
    # the in-product relaunch follows the same resolution path as a shipped install.
    cp "$RIG_HOME/bin/server" "$(dirname "$APP_BINARY")/anselm-server"
    chmod +x "$(dirname "$APP_BINARY")/anselm-server"
  fi
  APP_LAUNCH_PID=$(launch_direct_app)
  printf '[conductor] direct macOS App started (PID %s; backend=%s)\n' \
    "$APP_LAUNCH_PID" "$APP_BACKEND_URL" >>"$SESSION/frontend.log"
  for _ in $(seq 1 360); do
    kill -0 "$APP_LAUNCH_PID" 2>/dev/null || break
    APP_PID=$(app_pids | awk -v pid="$APP_LAUNCH_PID" '$1 == pid {print $1}')
    [ "$APP_PID" = "$APP_LAUNCH_PID" ] && break
    sleep 0.5
  done
  kill -0 "$APP_LAUNCH_PID" 2>/dev/null || {
    echo "✗ direct macOS App exited" >&2
    tail -80 "$SESSION/frontend.log" >&2
    exit 1
  }
  APP_PID=$(app_pids | awk -v pid="$APP_LAUNCH_PID" '$1 == pid {print $1}')
  [ "$APP_PID" = "$APP_LAUNCH_PID" ] || {
    echo "✗ launched App PID is not the exact Anselm process" >&2
    tail -80 "$SESSION/frontend.log" >&2
    exit 1
  }
  UNATTRIBUTED_APP_PIDS=$(app_pids | awk -v expected="$APP_LAUNCH_PID" '$1 != expected {print $1}')
  [ -z "$UNATTRIBUTED_APP_PIDS" ] || {
    echo "✗ another Anselm App appeared beside conductor PID $APP_LAUNCH_PID: $UNATTRIBUTED_APP_PIDS" >&2
    echo "  The rig will not record or adopt an ambiguous window." >&2
    exit 1
  }
  startup_event app_binary_resident
  echo "✓ direct macOS App up (PID $APP_PID, console journaled)"

  # The direct binary inherits its attach/owned-backend environment; resolving the exact PID below is still required
  # for the window binding and for refusing PID reuse.  There is deliberately no Flutter runner in
  # this mode: flutter run's launch-services child did not inherit env from the PTY runner.
  for _ in $(seq 1 120); do
    APP_PID=$(app_pids | awk -v pid="$APP_LAUNCH_PID" '$1 == pid {print $1}')
    [ -n "$APP_PID" ] && break
    sleep 0.25
  done
  [ -n "$APP_PID" ] || {
    echo "✗ direct App launch returned but its exact macOS App process is missing" >&2
    tail -80 "$SESSION/frontend.log" >&2
    exit 1
  }
  startup_event app_window_process_resolved

  if [ "$RECORD" = "1" ]; then
    # Record the Anselm window's screen region, not the whole desktop. A region keeps menus and
    # OverlayPortal popovers in the frame while an unrelated foreground permission dialog outside
    # the app geometry can never become a false product frame in the acceptance evidence.
    for _ in $(seq 1 40); do
      APP_WINDOW_ID=$(swift -e 'import CoreGraphics; let target = Int(CommandLine.arguments[1])!; let ws = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []; for w in ws { let owner = w[kCGWindowOwnerName as String] as? String ?? ""; let name = w[kCGWindowName as String] as? String ?? ""; let pid = w[kCGWindowOwnerPID as String] as? Int ?? -1; if pid == target && owner.lowercased() == "anselm" && name == "anselm" { print(w[kCGWindowNumber as String] ?? ""); exit(0) } }' "$APP_PID" 2>/dev/null | tr -d '[:space:]')
      [ -n "$APP_WINDOW_ID" ] && break
      sleep 0.25
    done
    [ -n "$APP_WINDOW_ID" ] || {
      echo "✗ could not resolve the Anselm window ID — refusing desktop-wide recording" >&2; exit 1;
    }
    APP_WINDOW_BOUNDS=$(swift -e 'import Foundation; import CoreGraphics; let target = Int(CommandLine.arguments[1])!; let ws = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []; for w in ws { let owner = w[kCGWindowOwnerName as String] as? String ?? ""; let name = w[kCGWindowName as String] as? String ?? ""; let pid = w[kCGWindowOwnerPID as String] as? Int ?? -1; if pid == target && owner.lowercased() == "anselm" && name == "anselm", let b = w[kCGWindowBounds as String] as? [String: Any], let x = b["X"] as? NSNumber, let y = b["Y"] as? NSNumber, let width = b["Width"] as? NSNumber, let height = b["Height"] as? NSNumber { print("\(x.intValue),\(y.intValue),\(width.intValue),\(height.intValue)"); exit(0) } }' "$APP_PID" 2>/dev/null | tr -d '[:space:]')
    [ -n "$APP_WINDOW_BOUNDS" ] || {
      echo "✗ could not resolve the Anselm window geometry — refusing unbounded recording" >&2; exit 1;
    }
    startup_event app_window_geometry_resolved
    RECORDER_LIFECYCLE="$SESSION/recording-lifecycle.json"
    # A newly-created Flutter window can be visible to CoreGraphics before ScreenCaptureKit has
    # accepted it as a recordable source. Retry the bounded hand-off instead of turning that
    # one-frame startup race into a false channel-1 permission failure. Each retry overwrites the
    # lifecycle record, so the surviving recorder is the only one whose microsecond timestamps are
    # used by later measurements.
    #
    # Flutter 新窗口可能已经被 CoreGraphics 看见，但 ScreenCaptureKit 尚未接受它作为可录制源。
    # 这里对交接做有界重试，避免一次启动竞态被误判成 channel-1 权限失败。每次重试覆盖 lifecycle，
    # 因而后续测量使用的微秒时间戳只属于最后存活的 recorder。
    RECORDER_PID=""
    for RECORD_ATTEMPT in $(seq 1 5); do
      RECORDER_PID=$(python3 "$ROOT/testend/rig/spawn.py" --cwd "$ROOT" --out "$SESSION/recording.log" --lifecycle "$RECORDER_LIFECYCLE" -- \
        screencapture -v -C -k -l "$APP_WINDOW_ID" "$SESSION/screen.mov")
      sleep 1
      if kill -0 "$RECORDER_PID" 2>/dev/null; then
        break
      fi
      printf '[conductor] screen recorder attempt %s exited before the recordable window hand-off\n' \
        "$RECORD_ATTEMPT" >>"$SESSION/recording.log"
      RECORDER_PID=""
    done
    [ -n "$RECORDER_PID" ] && kill -0 "$RECORDER_PID" 2>/dev/null || {
      echo "✗ screen recorder exited after bounded retries — check Screen Recording permission and $SESSION/recording.log" >&2; exit 1;
    }
    startup_event window_recording_started
    echo "✓ window recording (Anselm window $APP_WINDOW_ID, PID $RECORDER_PID)"
  else
    : >"$SESSION/recording.disabled"
  fi
}

discover_app_backend() {
  local child port socket_info
  for _ in $(seq 1 240); do
    child=$(ps -axo pid=,ppid=,command= | awk -v parent="$APP_PID" \
      '$2 == parent && $0 ~ /\/anselm\.app\/Contents\/MacOS\/anselm-server([ ]|$)/ {print $1}')
    if [ -n "$child" ]; then
      socket_info=$(lsof -a -p "$child" -iTCP -sTCP:LISTEN -n -P 2>/dev/null || true)
      port=$(printf '%s\n' "$socket_info" | awk 'match($0, /127\.0\.0\.1:[0-9]+/) {print substr($0, RSTART+10, RLENGTH-10); exit}')
      if [ -n "$port" ]; then
        APP_SIDECAR_PID="$child"
        BACKEND_PID="$child"
        PORT="$port"
        APP_BACKEND_URL="http://127.0.0.1:$PORT"
        APP_AUTH_TOKEN=$(ps eww -p "$child" | awk 'match($0, /ANSELM_AUTH_TOKEN=[^ ]+/) {print substr($0, RSTART+18, RLENGTH-18)}')
        [ -n "$APP_AUTH_TOKEN" ] || {
          echo "✗ App-owned sidecar exposed a port but no ANSELM_AUTH_TOKEN was observable" >&2
          return 1
        }
        APP_AUTH_TOKEN_FILE="$SESSION/app-auth-token"
        printf '%s\n' "$APP_AUTH_TOKEN" >"$APP_AUTH_TOKEN_FILE"
        chmod 600 "$APP_AUTH_TOKEN_FILE"
        printf '{"ts":"%s","event":"app_auth_token_observed","length":%s}\n' \
          "$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)" "${#APP_AUTH_TOKEN}" >>"$SESSION/startup-gate.jsonl"
        return 0
      fi
    fi
    sleep 0.25
  done
  echo "✗ App-owned sidecar did not expose a discoverable loopback listener" >&2
  tail -80 "$SESSION/frontend.log" >&2
  return 1
}

wait_expected_backend_failure() {
  local child state
  for _ in $(seq 1 20); do
    child=$(ps -axo pid=,ppid=,command= | awk -v parent="$APP_PID" \
      '$2 == parent && $0 ~ /\/anselm\.app\/Contents\/MacOS\/anselm-server([ ]|$)/ {print $1}')
    [ -n "$child" ] && break
    sleep 0.25
  done
  if [ -n "${child:-}" ]; then
    APP_SIDECAR_PID="$child"
    BACKEND_PID="$child"
    for _ in $(seq 1 120); do
      state=$(ps -o state= -p "$child" 2>/dev/null | tr -d '[:space:]')
      case "$state" in
        ""|Z*) break ;;
      esac
      sleep 0.25
    done
    state=$(ps -o state= -p "$child" 2>/dev/null | tr -d '[:space:]')
    case "$state" in
      ""|Z*) ;;
      *) echo "✗ expected startup failure sidecar is still alive (PID $child)" >&2; return 1 ;;
    esac
  else
    # A malformed settings file can make the sidecar exit before the 250ms process scan sees it.
    # The App's stderr pipe is the authoritative child-output witness in this mode: accept only an
    # explicit bootstrap/settings fatal line, and only with no loopback listener. Do not invent a PID.
    # 坏配置可能在 250ms 进程扫描前就让 sidecar 退出；此模式以 App stderr 管道为子进程输出真相，
    # 必须同时有明确 bootstrap/settings 致命行和无 loopback listener，绝不编造 PID。
    APP_SIDECAR_PID=""
    BACKEND_PID=""
    grep -Eiq '\[backend\].*(bootstrap|settings.*parse)' "$SESSION/frontend.log" || {
      echo "✗ expected startup failure found no sidecar bootstrap/settings fatal line" >&2
      return 1
    }
  fi
  startup_event backend_expected_startup_failure
  # BackendController's bounded health gate needs to finish before the final frame is captured;
  # otherwise the probe would only prove the connecting screen, not the user-visible failure.
  sleep "$STARTUP_FAILURE_SETTLE_SEC"
  awk '/\[backend\] / { sub(/^.*\[backend\] /, ""); print; next }
       /^flutter: 20[0-9][0-9]-[0-9][0-9-]+T/ { sub(/^flutter: /, ""); print }' \
    "$SESSION/frontend.log" >"$SESSION/backend.log"
  [ -s "$SESSION/backend.log" ] || {
    echo "✗ expected startup failure produced no backend journal" >&2
    return 1
  }
}

write_startup_failure_manifest() {
  for stream in messages entities notifications; do
    printf '{"tap":"not_applicable","stream":"%s","reason":"backend failed before an HTTP listener existed"}\n' "$stream" >>"$SESSION/sse.jsonl"
  done
  printf '%s\n' '{"event":"not_applicable","reason":"backend failed before an LLM request could be issued"}' >>"$SESSION/llm.jsonl"
  python3 - "$SESSION/manifest.json" <<PY
import json, sys
json.dump({
  "port": $PORT,
  "backendPid": "$BACKEND_PID",
  "appSidecarPid": "$APP_SIDECAR_PID",
  "appOwnsBackend": "1",
  "appAuthTokenFile": "",
  "tapPid": "",
  "llmtapPid": "$LLMTAP_PID",
  "llmtapPort": $LLMTAP_PORT,
  "llmUpstream": "$LLM_UPSTREAM",
  "startupFailureProbe": True,
  "startupFailureReason": "malformed_settings",
  "startupFailureBackendExitObserved": True,
  "startupGateJournal": "$SESSION/startup-gate.jsonl",
  "session": "$SESSION",
  "data": "$DATA",
  "appLaunchPid": "$APP_LAUNCH_PID",
  "appPid": "$APP_PID",
  "appBinary": "$APP_BINARY",
  "appArgs": "$APP_ARGS_STRING",
  "engineSwitches": "$ENGINE_SWITCHES_STRING",
  "appWindowId": "$APP_WINDOW_ID",
  "appWindowBounds": "$APP_WINDOW_BOUNDS",
  "recorderPid": "$RECORDER_PID",
  "recordingLifecycle": "$RECORDER_LIFECYCLE",
  "appRebindJournal": "$SESSION/app-rebind.jsonl",
  "appRebindCount": 0,
  "startedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}, open(sys.argv[1], "w"), indent=2)
PY
  ln -sfn "$SESSION" "$RIG_HOME/current"
}

mkdir -p "$SESSION/evidence" "$RIG_HOME/bin" "$DATA"
: >"$SESSION/startup-gate.jsonl"
echo "→ rig session: $SESSION (port :$PORT, data $DATA)"
if [ -n "$BACKEND_AUTH_TOKEN" ]; then
  BACKEND_AUTH_TOKEN_FILE="$SESSION/backend-auth-token"
  printf '%s\n' "$BACKEND_AUTH_TOKEN" >"$BACKEND_AUTH_TOKEN_FILE"
  chmod 600 "$BACKEND_AUTH_TOKEN_FILE"
  printf '{"ts":"%s","event":"backend_auth_token_configured","length":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)" "${#BACKEND_AUTH_TOKEN}" >>"$SESSION/startup-gate.jsonl"
fi
check_screen_recording_permission

case "$APP_FIRST" in
  0|1) ;;
  *) echo "✗ RIG_APP_FIRST must be 0 or 1, got '$APP_FIRST'" >&2; exit 2 ;;
esac
case "$APP_OWNS_BACKEND" in
  0|1) ;;
  *) echo "✗ RIG_APP_OWNS_BACKEND must be 0 or 1, got '$APP_OWNS_BACKEND'" >&2; exit 2 ;;
esac
case "$EXPECTED_BACKEND_FAILURE" in
  0|1) ;;
  *) echo "✗ RIG_EXPECT_BACKEND_FAILURE must be 0 or 1, got '$EXPECTED_BACKEND_FAILURE'" >&2; exit 2 ;;
esac
if [ "$EXPECTED_BACKEND_FAILURE" = "1" ]; then
  [ "$APP_OWNS_BACKEND" = "1" ] || {
    echo "✗ RIG_EXPECT_BACKEND_FAILURE=1 requires RIG_APP_OWNS_BACKEND=1" >&2; exit 2;
  }
  [ "$APP_FIRST" = "1" ] || [ "$APP_OWNS_BACKEND" = "1" ] || {
    echo "✗ RIG_EXPECT_BACKEND_FAILURE=1 requires App-first mode" >&2; exit 2;
  }
  [[ "$STARTUP_FAILURE_SETTLE_SEC" =~ ^[0-9]+([.][0-9]+)?$ ]] || {
    echo "✗ RIG_STARTUP_FAILURE_SETTLE_SEC must be a non-negative number" >&2; exit 2;
  }
fi
if [ "$APP_OWNS_BACKEND" = "1" ]; then
  APP_FIRST=1
  [ "$APP_PROXY" = "0" ] || {
    echo "✗ RIG_APP_OWNS_BACKEND=1 cannot be combined with RIG_APP_PROXY" >&2
    exit 2
  }
fi
if ! [[ "$BACKEND_START_DELAY_SEC" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "✗ RIG_BACKEND_START_DELAY_SEC must be a non-negative number, got '$BACKEND_START_DELAY_SEC'" >&2
  exit 2
fi
if [ "$APP_FIRST" = "1" ] && [ "$APP" != "1" ]; then
  echo "✗ RIG_APP_FIRST=1 requires RIG_APP=1" >&2
  exit 2
fi
case "$APP_PROXY" in
  0|1) ;;
  *) echo "✗ RIG_APP_PROXY must be 0 or 1, got '$APP_PROXY'" >&2; exit 2 ;;
esac
if [ "$APP_PROXY" = "1" ]; then
  [ "$APP" = "1" ] || { echo "✗ RIG_APP_PROXY=1 requires RIG_APP=1" >&2; exit 2; }
  [ "$APP_FIRST" = "0" ] || { echo "✗ RIG_APP_PROXY=1 requires backend-first mode (RIG_APP_FIRST=0)" >&2; exit 2; }
  if ! [[ "$APP_PROXY_PORT" =~ ^[1-9][0-9]*$ ]] || [ "$APP_PROXY_PORT" -gt 65535 ]; then
    echo "✗ RIG_APP_PROXY_PORT must be a TCP port, got '$APP_PROXY_PORT'" >&2; exit 2
  fi
  if ! [[ "$APP_PROXY_DELAY_MS" =~ ^[0-9]+$ ]]; then
    echo "✗ RIG_APP_PROXY_DELAY_MS must be a non-negative integer, got '$APP_PROXY_DELAY_MS'" >&2
    exit 2
  fi
  if ! [[ "$APP_PROXY_FAIL_COUNT" =~ ^[0-9]+$ ]]; then
    echo "✗ RIG_APP_PROXY_FAIL_COUNT must be a non-negative integer, got '$APP_PROXY_FAIL_COUNT'" >&2
    exit 2
  fi
  if ! [[ "$APP_PROXY_DROP_AFTER_MS" =~ ^[0-9]+$ ]] || ! [[ "$APP_PROXY_DROP_COUNT" =~ ^[0-9]+$ ]] || ! [[ "$APP_PROXY_FAIL_AFTER_DROP_COUNT" =~ ^[0-9]+$ ]] || ! [[ "$APP_PROXY_FAIL_AFTER_DROP_DELAY_MS" =~ ^[0-9]+$ ]]; then
    echo "✗ App proxy drop/fail-after-drop values must be non-negative integers" >&2
    exit 2
  fi
  if ! [[ "$APP_PROXY_FAIL_STATUS" =~ ^[45][0-9][0-9]$ ]]; then
    echo "✗ RIG_APP_PROXY_FAIL_STATUS must be an HTTP status in 400..599, got '$APP_PROXY_FAIL_STATUS'" >&2
    exit 2
  fi
  [ -n "$APP_PROXY_PATH" ] || { echo "✗ RIG_APP_PROXY_PATH must not be empty" >&2; exit 2; }
  if [ -n "$APP_PROXY_AUTH_TOKEN" ] && [ -z "$APP_PROXY_AUTH_PATH" ]; then
    echo "✗ RIG_APP_PROXY_AUTH_PATH is required with RIG_APP_PROXY_AUTH_TOKEN" >&2
    exit 2
  fi
  if ! [[ "$APP_PROXY_DROP_WORKSPACE_HEADER_COUNT" =~ ^[0-9]+$ ]]; then
    echo "✗ RIG_APP_PROXY_DROP_WORKSPACE_HEADER_COUNT must be a non-negative integer, got '$APP_PROXY_DROP_WORKSPACE_HEADER_COUNT'" >&2
    exit 2
  fi
  if ! [[ "$APP_PROXY_REWRITE_HOST_COUNT" =~ ^[0-9]+$ ]]; then
    echo "✗ RIG_APP_PROXY_REWRITE_HOST_COUNT must be a non-negative integer, got '$APP_PROXY_REWRITE_HOST_COUNT'" >&2
    exit 2
  fi
  if [ "$APP_PROXY_REWRITE_HOST_COUNT" -gt 0 ] && { [ -z "$APP_PROXY_REWRITE_HOST_PATH" ] || [ -z "$APP_PROXY_REWRITE_HOST" ]; }; then
    echo "✗ RIG_APP_PROXY_REWRITE_HOST_PATH and RIG_APP_PROXY_REWRITE_HOST are required with a rewrite budget" >&2
    exit 2
  fi
  if ! [[ "$APP_PROXY_REWRITE_PATH_COUNT" =~ ^[0-9]+$ ]] || ! [[ "$APP_PROXY_REWRITE_METHOD_COUNT" =~ ^[0-9]+$ ]]; then
    echo "✗ App proxy path/method rewrite counts must be non-negative integers" >&2
    exit 2
  fi
  if [ "$APP_PROXY_REWRITE_PATH_COUNT" -gt 0 ] && { [ -z "$APP_PROXY_REWRITE_PATH_FROM" ] || [ -z "$APP_PROXY_REWRITE_PATH_TO" ]; }; then
    echo "✗ App proxy path rewrite requires from/to paths with a rewrite budget" >&2
    exit 2
  fi
  if [ "$APP_PROXY_REWRITE_METHOD_COUNT" -gt 0 ] && { [ -z "$APP_PROXY_REWRITE_METHOD_PATH" ] || [ -z "$APP_PROXY_REWRITE_METHOD_FROM" ] || [ -z "$APP_PROXY_REWRITE_METHOD_TO" ]; }; then
    echo "✗ App proxy method rewrite requires path/from/to with a rewrite budget" >&2
    exit 2
  fi
fi

PREFLIGHT_PORTS=()
[ "$APP_OWNS_BACKEND" = "0" ] && PREFLIGHT_PORTS+=("$PORT")
[ "$LLMTAP" = "1" ] && PREFLIGHT_PORTS+=("$LLMTAP_PORT")
[ "$APP_PROXY" = "1" ] && PREFLIGHT_PORTS+=("$APP_PROXY_PORT")
for p in "${PREFLIGHT_PORTS[@]}"; do
  if HOLDER=$(listener_pid "$p") && [ -n "${HOLDER:-}" ]; then
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
if [ "$APP_PROXY" = "1" ]; then
  (cd "$ROOT/testend" && "$MISE" exec -- go build -o "$RIG_HOME/bin/appproxy" ./cmd/appproxy)
fi

GATEWAY_ENV=()
if [ "$LLMTAP" = "1" ]; then
  case "$LLMTAP_INJECT_WAV_METADATA" in
    0|1) ;;
    *) echo "✗ RIG_LLMTAP_INJECT_WAV_METADATA must be 0 or 1" >&2; exit 2 ;;
  esac
  LLMTAP_ARGS=(
    -listen "127.0.0.1:$LLMTAP_PORT"
    -upstream "$LLM_UPSTREAM"
    -out "$SESSION/llm.jsonl"
    -fail-path "$LLMTAP_FAIL_PATH"
    -fail-count "$LLMTAP_FAIL_COUNT"
    -fail-status "$LLMTAP_FAIL_STATUS"
    -fail-kind "$LLMTAP_FAIL_KIND"
  )
  [ "$LLMTAP_INJECT_WAV_METADATA" = "1" ] && LLMTAP_ARGS+=(-inject-wav-metadata)
  LLMTAP_PID=$(python3 "$ROOT/testend/rig/spawn.py" --cwd "$ROOT" --out "$SESSION/llmtap.log" -- \
    "$RIG_HOME/bin/llmtap" "${LLMTAP_ARGS[@]}")
  for _ in $(seq 1 40); do
    [ "$(listener_pid "$LLMTAP_PORT")" = "$LLMTAP_PID" ] && break
    sleep 0.25
  done
  [ "$(listener_pid "$LLMTAP_PORT")" = "$LLMTAP_PID" ] || {
    echo "✗ llmtap did not acquire :$LLMTAP_PORT" >&2; exit 1;
  }
  UPSTREAM_HOST=$(python3 -c "from urllib.parse import urlparse; print(urlparse('$LLM_UPSTREAM').netloc)")
  GATEWAY_ENV=(ANSELM_GATEWAY_URL="http://127.0.0.1:$LLMTAP_PORT/v1" ANSELM_PROOF_HOST="$UPSTREAM_HOST")
  echo "✓ llmtap up (PID $LLMTAP_PID, → $LLM_UPSTREAM)"
else
  : >"$SESSION/llm.disabled"
fi

if [ "$APP_FIRST" = "1" ]; then
  # Start the real App before the backend so the recorder captures the actual connecting gate. The
  # normal rig keeps its historical backend-first order; this switch is for deterministic gate
  # acceptance only and is intentionally opt-in.
  start_app_and_record
  if [ "$EXPECTED_BACKEND_FAILURE" = "1" ]; then
    startup_event app_backend_failure_probe_requested
    wait_expected_backend_failure
    write_startup_failure_manifest
    ARMED=0
    trap - EXIT INT TERM
    echo "✓ expected startup failure captured — five-channel negative probe in $SESSION"
    echo "  run: testend/rig/rig-check.sh"
    exit 0
  elif [ "$APP_OWNS_BACKEND" = "1" ]; then
    startup_event app_backend_discovery_requested
    discover_app_backend
    startup_event app_backend_discovered
    echo "✓ App-owned backend up (PID $APP_SIDECAR_PID, port :$PORT)"
  else
    startup_event backend_start_delayed
    sleep "$BACKEND_START_DELAY_SEC"
  fi
fi

AUTH_ARGS=()
if [ "$APP_OWNS_BACKEND" = "1" ]; then
  AUTH_ARGS=(-H "Authorization: Bearer $APP_AUTH_TOKEN")
elif [ -n "$BACKEND_AUTH_TOKEN" ]; then
  AUTH_ARGS=(-H "Authorization: Bearer $BACKEND_AUTH_TOKEN")
fi
# Keep optional auth expansion safe under `set -u`; an empty array is valid for an external backend.
curl_backend() {
  if (( ${#AUTH_ARGS[@]} )); then
    curl "$@" "${AUTH_ARGS[@]}"
  else
    curl "$@"
  fi
}
if [ "$APP_OWNS_BACKEND" = "0" ]; then
  startup_event backend_launch_requested
  BACKEND_ENV=(ANSELM_DEV=1 ANSELM_ADDR=":$PORT" ANSELM_DATA_DIR="$DATA")
  [ -n "$BACKEND_AUTH_TOKEN" ] && BACKEND_ENV+=(ANSELM_AUTH_TOKEN="$BACKEND_AUTH_TOKEN")
  if [ "$LLMTAP" = "1" ]; then
    BACKEND_PID=$(python3 "$ROOT/testend/rig/spawn.py" --cwd "$ROOT" --out "$SESSION/backend.log" -- \
      env "${BACKEND_ENV[@]}" "${GATEWAY_ENV[@]}" "$RIG_HOME/bin/server")
  else
    BACKEND_PID=$(python3 "$ROOT/testend/rig/spawn.py" --cwd "$ROOT" --out "$SESSION/backend.log" -- \
      env "${BACKEND_ENV[@]}" "$RIG_HOME/bin/server")
  fi
else
  # The App captures its owned sidecar stderr into the Flutter console journal.  Materialize the
  # backend-only projection for the independent channel-2 artifact at every live check and at down.
  : >"$SESSION/backend.log"
fi
if ! [[ "$BACKEND_WAIT_SEC" =~ ^[1-9][0-9]*$ ]]; then
  echo "✗ RIG_BACKEND_WAIT_SEC must be a positive integer, got '$BACKEND_WAIT_SEC'" >&2
  exit 2
fi
for _ in $(seq 1 $((BACKEND_WAIT_SEC * 4))); do
  curl_backend -sf "http://127.0.0.1:$PORT/api/v1/health" >/dev/null 2>&1 && break
  sleep 0.25
done
curl_backend -sf "http://127.0.0.1:$PORT/api/v1/health" >/dev/null || {
  echo "✗ backend did not come up within ${BACKEND_WAIT_SEC}s" >&2; tail -20 "$SESSION/backend.log" >&2; exit 1;
}
startup_event backend_healthy
LISTENER=$(lsof -ti ":$PORT" -sTCP:LISTEN | sort -u)
[ "$LISTENER" = "$BACKEND_PID" ] || {
  echo "✗ D1 attribution: :$PORT holder [$LISTENER] != journaled PID $BACKEND_PID" >&2; exit 1;
}
echo "✓ backend up (PID $BACKEND_PID == port holder)"

if [ "$SEED" = "1" ]; then
  (cd "$ROOT/backend" && "$MISE" exec -- go run ./cmd/seed -base "http://127.0.0.1:$PORT") | tail -3
fi

if [ "$APP_PROXY" = "1" ]; then
  APP_PROXY_JOURNAL="$SESSION/appproxy.jsonl"
  APP_PROXY_ARGS=(
    "$RIG_HOME/bin/appproxy" -listen "127.0.0.1:$APP_PROXY_PORT" -upstream "http://127.0.0.1:$PORT"
    -delay-path "$APP_PROXY_PATH" -delay-ms "$APP_PROXY_DELAY_MS"
    -fail-count "$APP_PROXY_FAIL_COUNT" -fail-status "$APP_PROXY_FAIL_STATUS"
    -drop-after-ms "$APP_PROXY_DROP_AFTER_MS" -drop-count "$APP_PROXY_DROP_COUNT"
    -fail-after-drop-count "$APP_PROXY_FAIL_AFTER_DROP_COUNT"
    -fail-after-drop-delay-ms "$APP_PROXY_FAIL_AFTER_DROP_DELAY_MS"
    -drop-workspace-header-count "$APP_PROXY_DROP_WORKSPACE_HEADER_COUNT" -out "$APP_PROXY_JOURNAL"
    -rewrite-host-path "$APP_PROXY_REWRITE_HOST_PATH" -rewrite-host "$APP_PROXY_REWRITE_HOST"
    -rewrite-host-count "$APP_PROXY_REWRITE_HOST_COUNT"
    -rewrite-path-from "$APP_PROXY_REWRITE_PATH_FROM" -rewrite-path-to "$APP_PROXY_REWRITE_PATH_TO"
    -rewrite-path-count "$APP_PROXY_REWRITE_PATH_COUNT"
    -rewrite-method-path "$APP_PROXY_REWRITE_METHOD_PATH" -rewrite-method-from "$APP_PROXY_REWRITE_METHOD_FROM"
    -rewrite-method-to "$APP_PROXY_REWRITE_METHOD_TO" -rewrite-method-count "$APP_PROXY_REWRITE_METHOD_COUNT"
  )
  if [ -n "$APP_PROXY_AUTH_TOKEN" ]; then
    APP_PROXY_ARGS+=(
      -upstream-auth-token "$APP_PROXY_AUTH_TOKEN"
      -upstream-auth-path "$APP_PROXY_AUTH_PATH"
    )
  fi
  APP_PROXY_PID=$(python3 "$ROOT/testend/rig/spawn.py" --cwd "$ROOT" --out "$SESSION/appproxy.log" -- \
    "${APP_PROXY_ARGS[@]}")
  for _ in $(seq 1 40); do
    [ "$(listener_pid "$APP_PROXY_PORT")" = "$APP_PROXY_PID" ] && break
    sleep 0.25
  done
  [ "$(listener_pid "$APP_PROXY_PORT")" = "$APP_PROXY_PID" ] || {
    echo "✗ appproxy did not acquire :$APP_PROXY_PORT" >&2; exit 1;
  }
  APP_BACKEND_URL="http://127.0.0.1:$APP_PROXY_PORT"
  startup_event app_proxy_started
  echo "✓ App API perturbation proxy up (PID $APP_PROXY_PID, $APP_PROXY_PATH +${APP_PROXY_DELAY_MS}ms, failures=$APP_PROXY_FAIL_COUNT/$APP_PROXY_FAIL_STATUS, drops=$APP_PROXY_DROP_COUNT/${APP_PROXY_DROP_AFTER_MS}ms, post-drop failures=$APP_PROXY_FAIL_AFTER_DROP_COUNT/${APP_PROXY_FAIL_AFTER_DROP_DELAY_MS}ms, drop-workspace-header-count=$APP_PROXY_DROP_WORKSPACE_HEADER_COUNT)"
fi

check_channel5_wiring() {
  local workspaces_json workspaces ws keys_json check
  if ! workspaces_json=$(curl_backend -sf "http://127.0.0.1:$PORT/api/v1/workspaces"); then
    echo "✗ channel 5 preflight could not read the workspace roster" >&2
    return 1
  fi
  if ! workspaces=$(printf '%s' "$workspaces_json" | python3 -c '
import json, sys
payload = json.load(sys.stdin)
rows = payload.get("data") if isinstance(payload, dict) else None
if not isinstance(rows, list) or any(not isinstance(row, dict) or not isinstance(row.get("id"), str) for row in rows):
    raise SystemExit(2)
print("\n".join(row["id"] for row in rows))
'); then
    echo "✗ channel 5 preflight received a malformed workspace roster" >&2
    return 1
  fi
  if [ -z "$workspaces" ]; then
    echo "· channel 5 wiring pending — no workspace yet; onboarding may discover one later"
    return 0
  fi
  while IFS= read -r ws; do
    [ -n "$ws" ] || continue
    if ! keys_json=$(curl_backend -sf "http://127.0.0.1:$PORT/api/v1/api-keys?limit=100" -H "X-Anselm-Workspace-ID: $ws"); then
      echo "✗ channel 5 preflight could not read API keys for $ws" >&2
      return 1
    fi
    check=$(printf '%s' "$keys_json" | python3 "$ROOT/testend/rig/channel5_wiring.py" --port "$LLMTAP_PORT") || {
      echo "✗ channel 5 preflight received malformed API keys for $ws: $check" >&2
      return 1
    }
    case "$check" in
      pending$'\t'*) echo "· managed key pending for $ws" ;;
      ok$'\t'*) echo "✓ channel 5 wiring for $ws → tap ($check)" ;;
      bypass$'\t'*)
        echo "✗ channel 5 wiring for $ws bypasses this tap: $check" >&2
        return 1
        ;;
      invalid$'\t'*)
        echo "✗ channel 5 wiring for $ws is invalid: $check" >&2
        return 1
        ;;
      *)
        echo "✗ channel 5 preflight returned an unknown result for $ws: $check" >&2
        return 1
        ;;
    esac
  done <<< "$workspaces"
}

# Do this before ssetap and Flutter. A stale data directory with a persisted managed key
# otherwise creates a convincing-looking App run whose gateway traffic bypasses llmtap.
if [ "$LLMTAP" = "1" ]; then
  check_channel5_wiring
fi

if [ "$APP_FIRST" != "1" ]; then
  # Dynamic discovery is essential: with RIG_SEED=0 there is no workspace until onboarding, and later
  # workspace-switch journeys create more. One resident process discovers and taps all of them.
  SSETAP_ARGS=(-base "http://127.0.0.1:$PORT" -all-workspaces -out "$SESSION/sse.jsonl")
  if [ "$APP_OWNS_BACKEND" = "1" ]; then
    SSETAP_ARGS+=(-token "$APP_AUTH_TOKEN")
  elif [ -n "$BACKEND_AUTH_TOKEN" ]; then
    SSETAP_ARGS+=(-token "$BACKEND_AUTH_TOKEN")
  fi
  TAP_PID=$(python3 "$ROOT/testend/rig/spawn.py" --cwd "$ROOT" --out "$SESSION/ssetap.log" -- \
    "$RIG_HOME/bin/ssetap" "${SSETAP_ARGS[@]}")
  startup_event ssetap_started
  echo "✓ ssetap discovery up (PID $TAP_PID)"
  start_app_and_record
else
  # The App was deliberately started before the backend. Start the SSE witness only after the
  # backend is healthy; its connection time is still captured in the same session manifest.
  SSETAP_ARGS=(-base "http://127.0.0.1:$PORT" -all-workspaces -out "$SESSION/sse.jsonl")
  if [ "$APP_OWNS_BACKEND" = "1" ]; then
    SSETAP_ARGS+=(-token "$APP_AUTH_TOKEN")
  elif [ -n "$BACKEND_AUTH_TOKEN" ]; then
    SSETAP_ARGS+=(-token "$BACKEND_AUTH_TOKEN")
  fi
  TAP_PID=$(python3 "$ROOT/testend/rig/spawn.py" --cwd "$ROOT" --out "$SESSION/ssetap.log" -- \
    "$RIG_HOME/bin/ssetap" "${SSETAP_ARGS[@]}")
  startup_event ssetap_started
  echo "✓ ssetap discovery up (PID $TAP_PID)"
fi

python3 - "$SESSION/manifest.json" <<PY
import json, sys
json.dump({
  "port": $PORT,
  "backendPid": "$BACKEND_PID",
  "appSidecarPid": "$APP_SIDECAR_PID",
  "appOwnsBackend": "$APP_OWNS_BACKEND",
  "appAuthTokenFile": "$APP_AUTH_TOKEN_FILE",
  "backendAuthTokenFile": "$BACKEND_AUTH_TOKEN_FILE",
  "tapPid": "$TAP_PID",
  "llmtapPid": "$LLMTAP_PID",
  "llmtapPort": $LLMTAP_PORT,
  "llmUpstream": "$LLM_UPSTREAM",
  "llmtapFailPath": "$LLMTAP_FAIL_PATH",
  "llmtapFailCount": $LLMTAP_FAIL_COUNT,
  "llmtapFailStatus": $LLMTAP_FAIL_STATUS,
  "llmtapFailKind": "$LLMTAP_FAIL_KIND",
  "llmtapInjectWAVMetadata": "$LLMTAP_INJECT_WAV_METADATA",
  "modelCatalogURL": "${ANSELM_RIG_MODEL_CATALOG_URL:-}",
  "mediaProcessDelayMs": "${ANSELM_RIG_MEDIA_PROCESS_DELAY_MS:-0}",
  "speechCacheBudgetBytes": "${ANSELM_RIG_SPEECH_CACHE_BUDGET_BYTES:-0}",
  "playbackLeaseTtlMs": "${ANSELM_RIG_PLAYBACK_LEASE_TTL_MS:-0}",
  "prefillSkillSourceConfigured": $PREFILL_SKILL_SOURCE_CONFIGURED,
  "appProxyPid": "$APP_PROXY_PID",
  "appProxyPort": $APP_PROXY_PORT,
  "appProxyJournal": "$APP_PROXY_JOURNAL",
  "appProxyDelayMs": $APP_PROXY_DELAY_MS,
  "appProxyFailCount": $APP_PROXY_FAIL_COUNT,
  "appProxyFailStatus": $APP_PROXY_FAIL_STATUS,
  "appProxyDropWorkspaceHeaderCount": $APP_PROXY_DROP_WORKSPACE_HEADER_COUNT,
  "appProxyRewriteHostPath": "$APP_PROXY_REWRITE_HOST_PATH",
  "appProxyRewriteHost": "$APP_PROXY_REWRITE_HOST",
  "appProxyRewriteHostCount": $APP_PROXY_REWRITE_HOST_COUNT,
  "appProxyRewritePathFrom": "$APP_PROXY_REWRITE_PATH_FROM",
  "appProxyRewritePathTo": "$APP_PROXY_REWRITE_PATH_TO",
  "appProxyRewritePathCount": $APP_PROXY_REWRITE_PATH_COUNT,
  "appProxyRewriteMethodPath": "$APP_PROXY_REWRITE_METHOD_PATH",
  "appProxyRewriteMethodFrom": "$APP_PROXY_REWRITE_METHOD_FROM",
  "appProxyRewriteMethodTo": "$APP_PROXY_REWRITE_METHOD_TO",
  "appProxyRewriteMethodCount": $APP_PROXY_REWRITE_METHOD_COUNT,
  "appBackendUrl": "$APP_BACKEND_URL",
  "runnerPid": "$RUNNER_PID",
  "appLaunchPid": "$APP_LAUNCH_PID",
  "appPid": "$APP_PID",
  "appBinary": "$APP_BINARY",
  "appArgs": "$APP_ARGS_STRING",
  "engineSwitches": "$ENGINE_SWITCHES_STRING",
  "initialAppLaunchPid": "$APP_LAUNCH_PID",
  "appWindowId": "$APP_WINDOW_ID",
  "appWindowBounds": "$APP_WINDOW_BOUNDS",
  "recorderPid": "$RECORDER_PID",
  "recordingLifecycle": "$RECORDER_LIFECYCLE",
  "appRebindJournal": "$SESSION/app-rebind.jsonl",
  "appRebindCount": 0,
  "startupGateJournal": "$SESSION/startup-gate.jsonl",
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
