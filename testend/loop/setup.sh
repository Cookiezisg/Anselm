#!/usr/bin/env bash
# setup.sh — one-time per session. Configures the ALREADY-RUNNING real backend (`make -C backend run`,
# :8742) for the iteration loop: creates a workspace + a deepseek api-key (from repo-root .env) +
# default models, and writes the connection handle to /tmp/anselm_selfiter/serve.json (read by
# turn.sh). Run AFTER `make -C backend run`. Re-run to make a fresh workspace.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
set -a; [ -f "$ROOT/.env" ] && source "$ROOT/.env"; set +a
BASE="${ANSELM_BASE:-http://127.0.0.1:8742}"
KEY="${DEEPSEEK_API_KEY:?set DEEPSEEK_API_KEY in repo-root .env}"
URL="${EVALS_BASE_URL:-https://api.deepseek.com}"
MODEL="${EVALS_MODEL:-deepseek-v4-flash}"

echo "waiting for backend at $BASE ..."
for _ in $(seq 1 60); do curl -sf "$BASE/api/v1/health" >/dev/null 2>&1 && break; sleep 1; done

# Unique name per run — workspace names must be unique, so a fixed "loop" conflicts on re-setup
# (WORKSPACE_NAME_CONFLICT → error envelope → null id). 唯一名：workspace 名唯一，固定名重跑会冲突。
WS=$(curl -s -X POST "$BASE/api/v1/workspaces" -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg n "loop-$(date +%s)-$RANDOM" '{name:$n,language:"en"}')" | jq -r .data.id)
H="X-Anselm-Workspace-ID: $WS"
KID=$(curl -s -X POST "$BASE/api/v1/api-keys" -H "$H" -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg k "$KEY" --arg u "$URL" '{provider:"deepseek",displayName:"deepseek",key:$k,baseUrl:$u}')" | jq -r .data.id)
curl -s -X POST "$BASE/api/v1/api-keys/$KID:test" -H "$H" >/dev/null
for sc in dialogue utility agent; do
  curl -s -X PUT "$BASE/api/v1/workspaces/$WS/default-models/$sc" -H "$H" -H 'Content-Type: application/json' \
    -d "$(jq -nc --arg k "$KID" --arg m "$MODEL" '{apiKeyId:$k,modelId:$m}')" >/dev/null
done

mkdir -p /tmp/anselm_selfiter
jq -nc --arg b "$BASE" --arg w "$WS" --arg m "$MODEL" '{baseURL:$b,workspaceId:$w,model:$m}' \
  > /tmp/anselm_selfiter/serve.json
echo "configured: base=$BASE  ws=$WS  model=$MODEL  →  /tmp/anselm_selfiter/serve.json"
