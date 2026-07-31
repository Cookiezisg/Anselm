#!/usr/bin/env bash
# rig-down — stop the rig session recorded in the manifest, backend first via SIGTERM so its
# graceful-shutdown path (scheduler drain, sandbox reap) runs; the tap dies after, so the
# journal's last frames are the backend's own shutdown truth, not an artificial cut.
#
# rig-down — 按 manifest 停台架:后端先走 SIGTERM 使优雅关停路径(调度排空、sandbox 收割)
# 真跑;tap 后死,journal 的最后几帧是后端自己的关停真相、不是人为切断。
set -euo pipefail

RIG_HOME="${RIG_HOME:-$HOME/.anselm-rig}"
MANIFEST="$RIG_HOME/current/manifest.json"
[ -f "$MANIFEST" ] || { echo "✗ no live rig session ($MANIFEST missing)"; exit 1; }

BACKEND_PID=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['backendPid'])")
TAP_PID=$(python3 -c "import json; print(json.load(open('$MANIFEST'))['tapPid'])")

if kill -0 "$BACKEND_PID" 2>/dev/null; then
  kill -TERM "$BACKEND_PID"
  for i in $(seq 1 40); do kill -0 "$BACKEND_PID" 2>/dev/null || break; sleep 0.25; done
  kill -0 "$BACKEND_PID" 2>/dev/null && { echo "⚠ backend still alive after 10s — SIGKILL"; kill -9 "$BACKEND_PID"; }
  echo "✓ backend stopped"
else
  echo "· backend already gone"
fi

if [ -n "$TAP_PID" ] && kill -0 "$TAP_PID" 2>/dev/null; then
  kill -TERM "$TAP_PID"
  echo "✓ ssetap stopped"
fi

LLMTAP_PID=$(python3 -c "import json; print(json.load(open('$MANIFEST')).get('llmtapPid',''))")
if [ -n "$LLMTAP_PID" ] && kill -0 "$LLMTAP_PID" 2>/dev/null; then
  kill -TERM "$LLMTAP_PID"
  echo "✓ llmtap stopped"
fi

rm -f "$RIG_HOME/current"
echo "✓ rig down — journals preserved in the session directory"
