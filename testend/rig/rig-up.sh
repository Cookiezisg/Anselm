#!/usr/bin/env bash
# rig-up — acceptance-rig conductor (WRK-087): owns the backend + SSE tap lifecycle so every
# observation channel's journal provably belongs to the process it claims to describe. The D1
# self-check is the reason this script exists: a backend that lost the port race dies instantly
# while its journal keeps looking plausible — so after health, the PID holding the port MUST be
# the PID whose stdout we captured, or the rig refuses to run.
#
# rig-up — 验收台架 conductor(WRK-087):亲自持有后端 + SSE tap 的生命周期,使每条观测通道的
# journal 可证明地属于它声称描述的那个进程。D1 自检是本脚本存在的理由:抢端口失败的后端瞬间
# 死掉、journal 却依然像样——故 health 之后,持有端口的 PID 必须 == 我们捕获 stdout 的 PID,
# 否则台架拒绝开工。
set -euo pipefail

cd "$(dirname "$0")/../.."   # repo root
ROOT="$(pwd)"
PORT="${RIG_PORT:-8742}"
RIG_HOME="${RIG_HOME:-$HOME/.anselm-rig}"
SESSION="$RIG_HOME/sessions/$(date +%Y%m%d-%H%M%S)"
SEED="${RIG_SEED:-1}"
DATA="${RIG_DATA:-$RIG_HOME/data}"

mkdir -p "$SESSION" "$RIG_HOME/bin" "$DATA"

echo "→ rig session: $SESSION (port :$PORT, data $DATA)"

# --- pre-flight: the port must be free — adopting a foreign backend is exactly the D1 accident.
# --- 预检:端口必须空闲——收养别人的后端正是 D1 那场事故。
if HOLDER=$(lsof -ti ":$PORT" -sTCP:LISTEN 2>/dev/null | head -1) && [ -n "${HOLDER:-}" ]; then
  echo "✗ port :$PORT already held by PID $HOLDER ($(ps -o comm= -p "$HOLDER" 2>/dev/null || echo '?'))." >&2
  echo "  The rig refuses to adopt a process it did not start (D1). Stop it or set RIG_PORT." >&2
  exit 1
fi

# --- build the rig binaries fresh (go's cache makes this cheap when warm).
# --- 台架二进制现建(go 缓存使温态近零成本)。
echo "→ building server + ssetap + llmtap …"
(cd "$ROOT/backend" && go build -o "$RIG_HOME/bin/server" ./cmd/server)
(cd "$ROOT/testend" && go build -o "$RIG_HOME/bin/ssetap" ./cmd/ssetap && go build -o "$RIG_HOME/bin/llmtap" ./cmd/llmtap)

# --- channel 5: LLM-wire witness in front of the managed gateway. The backend is pointed at it
# --- via ANSELM_GATEWAY_URL, so every managed-route crossing is on record before the backend
# --- even boots. RIG_LLMTAP=0 opts out (backend then talks to the gateway directly).
# --- 通道五:受管网关前的 LLM 线缆见证者。后端经 ANSELM_GATEWAY_URL 指向它,故后端还没起,
# --- 受管路由的每次穿越就已注定入账。RIG_LLMTAP=0 退出(后端直连网关)。
LLMTAP="${RIG_LLMTAP:-1}"
LLMTAP_PORT="${RIG_LLMTAP_PORT:-8788}"
LLM_UPSTREAM="${RIG_LLM_UPSTREAM:-https://api.anselm.website}"
LLMTAP_PID=""
GATEWAY_ENV=()
if [ "$LLMTAP" = "1" ]; then
  if [ -n "$(lsof -ti ":$LLMTAP_PORT" -sTCP:LISTEN 2>/dev/null | head -1)" ]; then
    echo "✗ llmtap port :$LLMTAP_PORT already held — same D1 rule as the backend port." >&2
    exit 1
  fi
  "$RIG_HOME/bin/llmtap" -listen "127.0.0.1:$LLMTAP_PORT" -upstream "$LLM_UPSTREAM" \
    -out "$SESSION/llm.jsonl" >"$SESSION/llmtap.log" 2>&1 &
  LLMTAP_PID=$!
  for i in $(seq 1 40); do
    [ -n "$(lsof -ti ":$LLMTAP_PORT" -sTCP:LISTEN 2>/dev/null | head -1)" ] && break || sleep 0.25
  done
  # ANSELM_PROOF_HOST pairs with the URL override: requests travel via the tap, but the
  # device-proof htu must name the TRUE audience or the gateway rightly answers 401.
  # ANSELM_PROOF_HOST 与 URL 覆盖成对:请求途经 tap,但 device-proof 的 htu 必须点名
  # **真实受众**,否则网关理直气壮地 401。
  UPSTREAM_HOST=$(python3 -c "from urllib.parse import urlparse; print(urlparse('$LLM_UPSTREAM').netloc)")
  GATEWAY_ENV=(ANSELM_GATEWAY_URL="http://127.0.0.1:$LLMTAP_PORT/v1" ANSELM_PROOF_HOST="$UPSTREAM_HOST")
  echo "✓ llmtap up (PID $LLMTAP_PID, → $LLM_UPSTREAM)"
fi

# --- channel 2: backend with journaled stdout.
# --- 通道二:后端,stdout 落 journal。
env ANSELM_DEV=1 ANSELM_ADDR=":$PORT" ANSELM_DATA_DIR="$DATA" "${GATEWAY_ENV[@]}" \
  "$RIG_HOME/bin/server" >"$SESSION/backend.log" 2>&1 &
BACKEND_PID=$!

for i in $(seq 1 80); do
  curl -sf "http://127.0.0.1:$PORT/api/v1/health" >/dev/null 2>&1 && break || sleep 0.25
done
if ! curl -sf "http://127.0.0.1:$PORT/api/v1/health" >/dev/null 2>&1; then
  echo "✗ backend did not come up — journal tail:" >&2
  tail -5 "$SESSION/backend.log" >&2
  kill "$BACKEND_PID" 2>/dev/null || true
  exit 1
fi

# --- D1: journal attribution — the port holder must be the exact PID we captured.
# --- D1:journal 归属——持有端口者必须恰是我们捕获的那个 PID。
LISTENER=$(lsof -ti ":$PORT" -sTCP:LISTEN | sort -u)
if [ "$LISTENER" != "$BACKEND_PID" ]; then
  echo "✗ D1 attribution failure: port :$PORT held by [$LISTENER], but captured stdout belongs to $BACKEND_PID." >&2
  echo "  backend.log would be a dead process's journal. Refusing." >&2
  kill "$BACKEND_PID" 2>/dev/null || true
  exit 1
fi
echo "✓ backend up (PID $BACKEND_PID == port holder — D1 attribution verified)"

# --- optional standard demo dataset, then resolve the workspace for the tap.
# --- 可选灌标准演示数据,再为 tap 解析 workspace。
if [ "$SEED" = "1" ]; then
  (cd "$ROOT/backend" && go run ./cmd/seed -base "http://127.0.0.1:$PORT") | tail -3
fi
WS=$(curl -sf "http://127.0.0.1:$PORT/api/v1/workspaces" | python3 -c 'import json,sys; d=json.load(sys.stdin)["data"]; print(d[0]["id"] if d else "")')

# --- channel-5 wiring guard: base_url is persisted AT PROVISION TIME (freetier.go stores
# --- AnselmGatewayBase()), so a DATA dir provisioned under different wiring keeps its old
# --- pointer forever — the silent form bypasses the tap while llm.jsonl merely looks quiet.
# --- Provisioning is async; poll briefly, and refuse on a wrong pointer rather than warn.
# --- 通道五接线闸:base_url 在 **provision 时**落库(freetier.go 存 AnselmGatewayBase()),
# --- 换过接线的旧数据目录会永远抱着旧指针——静默形态=受管流量绕开 tap 而 llm.jsonl 只是安静。
# --- provision 是异步的:短轮询;指针错了直接拒绝而非提醒。
if [ "$LLMTAP" = "1" ] && [ -n "$WS" ]; then
  ANSELM_BASE="ABSENT"
  for i in $(seq 1 20); do
    ANSELM_BASE=$(curl -sf "http://127.0.0.1:$PORT/api/v1/api-keys?limit=100" \
      -H "X-Anselm-Workspace-ID: $WS" | python3 -c '
import json, sys
rows = json.load(sys.stdin).get("data") or []
print(next((r.get("baseUrl", "") for r in rows if r.get("provider") == "anselm"), "ABSENT"))' \
      2>/dev/null || echo "ABSENT")
    [ "$ANSELM_BASE" != "ABSENT" ] && break || sleep 0.5
  done
  case "$ANSELM_BASE" in
    "ABSENT") echo "· managed key not provisioned yet (async) — rig-check will re-assert the wiring" ;;
    "http://127.0.0.1:$LLMTAP_PORT"*) echo "✓ channel-5 wiring: managed base_url → tap ($ANSELM_BASE)" ;;
    *)
      echo "✗ channel-5 wiring: managed base_url is $ANSELM_BASE, not the tap — this DATA dir was provisioned under different wiring; managed traffic would be unwitnessed." >&2
      echo "  Use a fresh RIG_DATA (or align RIG_LLMTAP_PORT with the stored pointer). Refusing." >&2
      kill "$BACKEND_PID" 2>/dev/null || true
      [ -n "$LLMTAP_PID" ] && kill "$LLMTAP_PID" 2>/dev/null || true
      exit 1 ;;
  esac
fi
if [ -z "$WS" ]; then
  echo "⚠ no workspace yet — ssetap not started (start it after onboarding: rig-tap.sh)" >&2
  TAP_PID=""
else
  # --- channel 3: independent SSE witness.
  # --- 通道三:独立 SSE 见证者。
  # stdout/stderr must be detached from the caller's pipe — an inherited fd keeps any
  # `rig-up | tail` style invocation blocked forever after rig-up itself has exited.
  # stdout/stderr 必须与调用方管道脱钩——继承的 fd 会让 `rig-up | tail` 式调用在 rig-up
  # 自己退出后仍被钉住。
  "$RIG_HOME/bin/ssetap" -base "http://127.0.0.1:$PORT" -ws "$WS" -out "$SESSION/sse.jsonl" \
    >"$SESSION/ssetap.log" 2>&1 &
  TAP_PID=$!
  echo "✓ ssetap up (PID $TAP_PID, ws $WS)"
fi

# --- manifest: one file every other rig script reads; `current` symlink names the live session.
# --- manifest:其余台架脚本只读这一份;current 软链指认活会话。
cat >"$SESSION/manifest.json" <<EOF
{"port": $PORT, "backendPid": $BACKEND_PID, "tapPid": "${TAP_PID}", "ws": "$WS",
 "llmtapPid": "${LLMTAP_PID}", "llmtapPort": $LLMTAP_PORT, "llmUpstream": "$LLM_UPSTREAM",
 "data": "$DATA", "session": "$SESSION", "startedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
ln -sfn "$SESSION" "$RIG_HOME/current"

echo "✓ rig up — journals in $SESSION"
echo "  attach the app with: ANSELM_BACKEND_URL=http://127.0.0.1:$PORT (make -C frontend app reuses :8742 automatically)"
