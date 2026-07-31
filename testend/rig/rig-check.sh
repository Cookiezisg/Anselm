#!/usr/bin/env bash
# rig-check — the rig's self-test ("先查夹具再报缺陷", WRK-082 F1 / WRK-087 D1): every
# observation channel must prove it is actually observing before any product verdict is
# trusted. A silent channel reads exactly like a clean product — that is the failure mode
# this script exists to make loud.
#
# rig-check — 台架自检(「先查夹具再报缺陷」,WRK-082 F1 / WRK-087 D1):每条观测通道先
# 证明自己真的在观测,产品裁决才可信。哑掉的通道读起来与干净的产品一模一样——本脚本
# 存在就是为了让这种失败大声。
set -euo pipefail

RIG_HOME="${RIG_HOME:-$HOME/.anselm-rig}"
MANIFEST="$RIG_HOME/current/manifest.json"
FAIL=0
note() { echo "$@"; }
bad()  { echo "$@" >&2; FAIL=1; }

# ① tooling — 帧通道的解帧半与录屏权限。
command -v ffmpeg >/dev/null || bad "✗ ffmpeg missing (frame extraction dead)"
TMP=$(mktemp -d)
if screencapture -x "$TMP/probe.png" 2>/dev/null && [ -s "$TMP/probe.png" ]; then
  note "✓ screen capture permission live"
else
  bad "✗ screencapture denied — Screen Recording permission lost (channel 1 video dead)"
fi
rm -rf "$TMP"

# ② live session + D1 attribution — 通道二的 journal 归属。
if [ ! -f "$MANIFEST" ]; then
  bad "✗ no live rig session — run rig-up.sh first"
else
  PORT=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['port'])")
  BPID=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['backendPid'])")
  SESSION=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['session'])")
  LISTENER=$(lsof -ti ":$PORT" -sTCP:LISTEN 2>/dev/null | sort -u || true)
  if [ "$LISTENER" = "$BPID" ]; then
    note "✓ D1 attribution: port :$PORT holder == journaled backend PID $BPID"
  else
    bad "✗ D1 attribution BROKEN: port holder [$LISTENER] != journaled PID $BPID — backend.log is not the live truth"
  fi
  curl -sf "http://127.0.0.1:$PORT/api/v1/health" >/dev/null && note "✓ backend health ok" \
    || bad "✗ backend health failed"

  # ③ channel 3 — tap 必须活着且真连上了(journal 里有 connect 且进程在)。
  TPID=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['tapPid'])")
  if [ -n "$TPID" ] && kill -0 "$TPID" 2>/dev/null; then
    if grep -q '"tap":"connect"' "$SESSION/sse.jsonl" 2>/dev/null; then
      note "✓ ssetap alive and connected ($(grep -c '"tap":"connect"' "$SESSION/sse.jsonl") connects journaled)"
    else
      bad "✗ ssetap running but no connect record — channel 3 silently blind"
    fi
  else
    bad "✗ ssetap not running (channel 3 dead)"
  fi

  # ③b channel 5 — llmtap 若启用必须活着且在监听(哑掉的线缆见证 == 没有见证)。
  LPID=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['llmtapPid'])")
  LPORT=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['llmtapPort'])")
  if [ -n "$LPID" ]; then
    if kill -0 "$LPID" 2>/dev/null && [ "$(lsof -ti ":$LPORT" -sTCP:LISTEN 2>/dev/null | head -1)" = "$LPID" ]; then
      note "✓ llmtap alive and listening on :$LPORT"
    else
      bad "✗ llmtap dead or not listening — channel 5 blind, managed-route calls unwitnessed"
    fi
  fi

  # ③c channel-5 WIRING — the managed key's base_url is PERSISTED at provision time
  # (freetier.go stores AnselmGatewayBase()), so a data dir provisioned without the tap
  # keeps pointing at production forever: managed traffic then bypasses the tap while
  # llm.jsonl sits there looking merely quiet. Same family as D1 — a silent channel
  # reads exactly like a clean product, so the wiring itself must be asserted.
  # ③c 通道五**接线**——受管 key 的 base_url 在 provision 时**落库**(freetier.go 存的是
  # AnselmGatewayBase()),故不带 tap 开通的数据目录会永远指着生产:受管流量绕开 tap,
  # 而 llm.jsonl 只是安静地空着。与 D1 同族——哑通道读起来与干净产品一样,接线本身必须断言。
  WS=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['ws'])")
  if [ -n "$LPID" ] && [ -n "$WS" ]; then
    ANSELM_BASE=$(curl -sf "http://127.0.0.1:$PORT/api/v1/api-keys?limit=100" \
      -H "X-Anselm-Workspace-ID: $WS" | python3 -c '
import json, sys
rows = json.load(sys.stdin).get("data") or []
print(next((r.get("baseUrl", "") for r in rows if r.get("provider") == "anselm"), "ABSENT"))')
    case "$ANSELM_BASE" in
      "ABSENT") note "· managed key not provisioned yet (async) — re-check after first managed use" ;;
      "http://127.0.0.1:$LPORT"*) note "✓ channel-5 wiring: managed base_url points at the tap ($ANSELM_BASE)" ;;
      *) bad "✗ channel-5 wiring BROKEN: managed base_url is $ANSELM_BASE, not the tap — managed traffic unwitnessed. Re-provision (fresh RIG_DATA) or fix the key row." ;;
    esac
  fi

  # ④ backend journal is being written and carries no unexplained panic.
  # ④ 后端 journal 在动、且无未解释 panic。
  [ -s "$SESSION/backend.log" ] && note "✓ backend journal non-empty" || bad "✗ backend journal empty"
  if grep -q "panic:" "$SESSION/backend.log" 2>/dev/null; then
    bad "✗ panic present in backend journal — read it before anything else"
  fi
fi

if [ "$FAIL" = "0" ]; then echo "✓ rig-check: all channels observing"; else echo "✗ rig-check FAILED"; exit 1; fi
