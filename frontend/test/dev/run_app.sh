#!/usr/bin/env bash
# `make app` for DEV — the real shell against a real backend, with hot reload. The bundled-sidecar spawn
# path (production) needs the Go binary built INTO the signed .app (a distribution task, WRK-043); for dev
# we use the dev-attach escape hatch (ANSELM_BACKEND_URL) and auto-ensure a backend so `make app` just
# works. Ensures a backend on the dev port (starts `make server` in the background + persists it across
# app restarts — `make stop` kills it), then runs the real app attached to it.
# 开发版 make app:真壳 + 真后端 + 热重载。生产的"spawn 打包 sidecar"需把 Go 二进制签进 .app(发行阶段,
# WRK-043);开发走 dev-attach + 自动起后端,使 make app 开箱即用(后端后台常驻,make stop 关)。
set -euo pipefail
cd "$(dirname "$0")/../.."   # frontend/
ROOT="$(cd .. && pwd)"
PORT="${ANSELM_DEV_PORT:-8742}"
URL="http://127.0.0.1:$PORT"

if ! curl -sf "$URL/api/v1/health" >/dev/null 2>&1; then
  echo "→ no backend on :$PORT — starting it (make server) in the background …"
  ( cd "$ROOT" && make server ) >/tmp/anselm-dev-server.log 2>&1 &
  for i in $(seq 1 80); do curl -sf "$URL/api/v1/health" >/dev/null 2>&1 && break || sleep 0.5; done
  curl -sf "$URL/api/v1/health" >/dev/null \
    || { echo "✗ backend didn't come up (see /tmp/anselm-dev-server.log)"; exit 1; }
  echo "  backend up on :$PORT (persists across app restarts — 'make stop' from repo root to kill)."
else
  echo "→ reusing backend already on :$PORT."
fi

echo "→ flutter run -d macos (real app, attached to $URL, hot reload on) …"
exec env ANSELM_BACKEND_URL="$URL" LANG=en_US.UTF-8 mise exec -- flutter run -d macos -t lib/main.dart
