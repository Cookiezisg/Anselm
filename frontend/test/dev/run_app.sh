#!/usr/bin/env bash
# `make app` for DEV — the real shell against a real backend, with hot reload. The bundled-sidecar spawn
# path (production) needs the Go binary built INTO the signed .app (a distribution task, WRK-043); for dev
# we use the dev-attach escape hatch (ANSELM_BACKEND_URL) and auto-ensure a backend so `make app` just
# works. Ensures a backend on the dev port (starts `make -C backend run` in the background + persists it across
# app restarts — `make -C backend stop` kills it), then runs the real app attached to it.
# 开发版 make app:真壳 + 真后端 + 热重载。生产的"spawn 打包 sidecar"需把 Go 二进制签进 .app(发行阶段,
# WRK-043);开发走 dev-attach + 自动起后端,使 make app 开箱即用(后端后台常驻,make -C backend stop 关)。
set -euo pipefail
cd "$(dirname "$0")/../.."   # frontend/
ROOT="$(cd .. && pwd)"
PORT="${ANSELM_DEV_PORT:-8742}"
URL="http://127.0.0.1:$PORT"
DEVICE="${DEVICE:-macos}"
MISE="${MISE:-mise}"

if ! curl -sf "$URL/api/v1/health" >/dev/null 2>&1; then
  echo "→ no backend on :$PORT — starting it (make -C backend run) in the background …"
  ( cd "$ROOT" && make -C backend run ) >/tmp/anselm-dev-server.log 2>&1 &
  for i in $(seq 1 80); do curl -sf "$URL/api/v1/health" >/dev/null 2>&1 && break || sleep 0.5; done
  curl -sf "$URL/api/v1/health" >/dev/null \
    || { echo "✗ backend didn't come up (see /tmp/anselm-dev-server.log)"; exit 1; }
  echo "  backend up on :$PORT (persists across app restarts — 'make -C backend stop' from repo root to kill)."
else
  # Say HOW OLD it is. Reuse is the right default (the backend outlives app restarts), but a silent
  # reuse turns 真机验收 into a lie: a session can run the whole acceptance against a binary from
  # hours ago and draw conclusions about code that is not running. Observed 0727 — a real-machine
  # video playback "failure" was a backend started 3h before the `http.ServeContent` fix landed,
  # and the elapsed line below is exactly what would have caught it in one glance.
  #
  # **说清它多老。** 复用是对的默认(后端活得比 app 重启久),但**静默**复用会把真机验收变成谎言:一个会话
  # 可以拿三小时前的二进制跑完整套验收,然后对**根本没在跑的代码**下结论。0727 实地撞上——一次真机播放
  # 「失败」,真因是后端启动于 `http.ServeContent` 那个修复落地前 3 小时;下面这行「跑了多久」正是当时
  # 一眼就能看破它的东西。
  started=$(ps -o lstart= -p "$(lsof -ti :"$PORT" -sTCP:LISTEN 2>/dev/null | head -1)" 2>/dev/null | sed 's/^ *//')
  if [ -n "$started" ]; then
    echo "→ reusing backend already on :$PORT (started $started)."
    echo "  ⚠ it is NOT rebuilt — if your Go code is newer, 'make -C backend stop' first or you are testing an old binary."
  else
    echo "→ reusing backend already on :$PORT (start time unknown)."
    echo "  ⚠ it is NOT rebuilt — 'make -C backend stop' first if your Go code changed."
  fi
fi

echo "→ flutter run -d $DEVICE (real app, attached to $URL, hot reload on) …"
exec env ANSELM_BACKEND_URL="$URL" LANG=en_US.UTF-8 "$MISE" exec -- flutter run -d "$DEVICE" -t lib/main.dart
