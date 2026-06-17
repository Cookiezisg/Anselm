#!/usr/bin/env bash
# turn.sh — ONE turn of a multi-turn conversation. Claude (the user) calls this by hand each turn:
# it posts ONE user message, waits for the agent's turn to reach terminal (auto-approving danger
# gates each poll), then prints what the agent did (tool calls + args + results + text). Claude
# reads that and composes the NEXT user message by hand — the script is just the curl plumbing,
# the words are Claude's. Connection from /tmp/anselm_selfiter/serve.json (written by setup.sh).
#   turn.sh new                 -> create a fresh conversation, print CONV=cv_xxx
#   turn.sh <convId> "<msg>"    -> send <msg> to that conversation, print the agent's turn
set -euo pipefail
SVC=/tmp/anselm_selfiter/serve.json
BASE=$(jq -r .baseURL "$SVC"); WS=$(jq -r .workspaceId "$SVC")
H_WS="X-Anselm-Workspace-ID: $WS"; H_JSON="Content-Type: application/json"
CID="${1:-}"; MSG="${2:-}"

if [ "$CID" = "new" ] || [ -z "$CID" ]; then
  CID=$(curl -s -X POST "$BASE/api/v1/conversations" -H "$H_WS" -H "$H_JSON" -d '{"title":"loop"}' | jq -r .data.id)
  echo "CONV=$CID"; [ -z "$MSG" ] && exit 0
fi

MID=$(curl -s -X POST "$BASE/api/v1/conversations/$CID/messages" -H "$H_WS" -H "$H_JSON" \
  -d "$(jq -nc --arg c "$MSG" '{content:$c}')" | jq -r .data.id)
for _ in $(seq 1 180); do
  for tc in $(curl -s "$BASE/api/v1/conversations/$CID/interactions" -H "$H_WS" | jq -r '(.data // [])[]?.toolCallId'); do
    curl -s -X POST "$BASE/api/v1/conversations/$CID/interactions/$tc" -H "$H_WS" -H "$H_JSON" \
      -d '{"action":"approve_always"}' >/dev/null || true
  done
  MSGS=$(curl -s "$BASE/api/v1/conversations/$CID/messages?limit=120" -H "$H_WS")
  ST=$(echo "$MSGS" | jq -r --arg m "$MID" '.data[]? | select(.id==$m) | .status')
  if [ -n "$ST" ] && [ "$ST" != "pending" ] && [ "$ST" != "streaming" ]; then
    echo "STATUS=$ST"
    echo "$MSGS" | jq -r --arg m "$MID" '.data[]? | select(.id==$m) | .blocks[]? |
      if .type=="tool_call"   then "  CALL \(.attrs.tool): \(.content)"
      elif .type=="tool_result" then "  RSLT\(if (.error//"")!="" then "[ERR]" else "" end): \(.content)"
      elif .type=="text"      then "  TEXT: \(.content)"
      elif .type=="reasoning" then "  THINK: \(.content)"
      else "  \(.type): \(.content)" end'
    exit 0
  fi
  sleep 1
done
echo "STATUS=TIMEOUT"
