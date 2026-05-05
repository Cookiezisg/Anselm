BACKEND_DATA_DIR ?= /tmp/forgify-dev
PORT             ?= 8742

# `set -a; source .env` exports every var so child processes (go test,
# go run) inherit them. Targets that don't need secrets can skip this.
# `set -a; source .env` 让 .env 里所有变量成为环境变量被子进程继承。
SHELL := /bin/bash
LOAD_ENV := set -a; [ -f .env ] && source .env; set +a;

DEVBOX_LAUNCHER := $(HOME)/.local/bin/devbox

# Auto-devbox dispatcher — every daily-use target's first recipe line.
# If not already inside `devbox shell`, re-invoke the same target via
# `devbox run` so the recipe body runs in the devbox env. Inside devbox,
# fall through to the rest of the recipe.
#
# 自动进 devbox 派发块：日常 target 第一行调它。不在 devbox shell 里就用
# devbox run 重新执行同一 target；在则继续往下跑 recipe。
define AUTO_DEVBOX
@if [ -z "$$DEVBOX_SHELL_ENABLED" ]; then \
	exec $(DEVBOX_LAUNCHER) run -- $(MAKE) $@; \
fi
endef

.DEFAULT_GOAL := help

# ── Primary commands ─────────────────────────────────────────────────────────

help:
	@echo "Forgify — make targets"
	@echo ""
	@echo "  Setup (run once on a new machine):"
	@echo "    make environment    Install devbox + Nix + Go tools + sandbox resources."
	@echo ""
	@echo "  Daily (from any shell — auto-enters devbox):"
	@echo "    make test-console   Live-reload backend + open testend in browser. Ctrl+C to stop."
	@echo "    make test-unit      Unit suite (no external deps)."
	@echo "    make test-pipeline  E2e pipeline suite. Sources .env — Live_/sandbox tests run"
	@echo "                        when keys/resources are present, skip gracefully when not."
	@echo "    make stop           Kill anything bound to port $(PORT)."
	@echo ""
	@echo "  Optional:"
	@echo "    make clear          Reset dev data dir."

# environment — first-time / new-machine setup. Must run from outer shell:
# the recipe needs to invoke `devbox install` / `devbox run`, which can't
# happen from inside a devbox shell.
#
# environment——首次环境装配，必须在外层 shell（recipe 要调 devbox install /
# devbox run，devbox shell 内无法跑）。
environment:
	@[ -z "$$DEVBOX_SHELL_ENABLED" ] || { \
		echo "✗ 'make environment' must run from your normal shell, not inside devbox."; \
		echo "  Exit devbox shell first (Ctrl+D), then re-run."; \
		exit 1; \
	}
	@if [ ! -x "$(DEVBOX_LAUNCHER)" ] && ! command -v devbox >/dev/null 2>&1; then \
		echo "→ installing devbox launcher to $(DEVBOX_LAUNCHER)..."; \
		mkdir -p $(HOME)/.local/bin; \
		curl -fsSL "https://releases.jetify.com/devbox?os=$$(uname -s | tr A-Z a-z)&arch=$$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')" \
			-o $(DEVBOX_LAUNCHER); \
		chmod +x $(DEVBOX_LAUNCHER); \
	else \
		echo "✓ devbox launcher present"; \
	fi
	@DEVBOX=$$(command -v devbox || echo $(DEVBOX_LAUNCHER)); \
	echo "→ devbox install (may prompt for sudo on first run for Nix)..."; \
	$$DEVBOX install; \
	echo "→ devbox run bootstrap (Go tools + sandbox resources)..."; \
	$$DEVBOX run bootstrap
	@echo ""
	@echo "✓ environment ready. now run:"
	@echo "    make test-console"

# test-console — run dev backend in foreground + open testend. Ctrl+C stops.
# Code changes require manual restart (Ctrl+C, re-run).
# Auto-wraps in devbox shell if invoked from outer shell.
# test-console——前台跑 dev backend + 自动开浏览器；改代码要手动重启（Ctrl+C 再跑一次）。
test-console:
	$(AUTO_DEVBOX)
	@lsof -ti :$(PORT) 2>/dev/null | xargs kill 2>/dev/null || true
	@sleep 0.3
	@( while ! curl -sf http://localhost:$(PORT)/api/v1/health >/dev/null 2>&1; do sleep 0.5; done; \
	   echo ""; echo "✓ http://localhost:$(PORT)/dev/ ready"; \
	   open http://localhost:$(PORT)/dev/ 2>/dev/null || true ) &
	@$(LOAD_ENV) cd backend && go run ./cmd/server --dev --port $(PORT) --data-dir $(BACKEND_DATA_DIR) --collections-dir ../testend/collections --integration-dir ../testend

# test-unit — pure-function / in-memory SQLite suite.
# test-unit——纯函数 / 内存 SQLite 套件。
test-unit:
	$(AUTO_DEVBOX)
	@cd backend && go test -count=1 ./... -skip TestIntegration_

# test-pipeline — the one e2e suite. Sources .env so Live_ tests run when
# DEEPSEEK_API_KEY is present; forge sandbox tests run when the v2 PluginSandbox
# bootstraps (i.e. mise binary is embedded — run `make resources` once after
# clone). Tests skip gracefully when prerequisites are absent.
#
# Runs serially (-p 1): each pipeline package boots a fresh harness and lazy-
# installs Python + uv via mise on first use. Parallel package execution
# triggers concurrent mise installs sharing nothing, which exhausts disk /
# trips upstream rate limits / hits race conditions in mise's plugin cache.
# Serial cost is ~4 min total — well worth the determinism.
#
# test-pipeline——唯一的 e2e 套件。自动 source .env：有 DEEPSEEK_API_KEY 则跑
# Live_ 测试；mise binary 已 embed（克隆后跑一次 `make resources`）则跑 forge
# sandbox 测试；缺时均优雅 skip。
#
# 串行（-p 1）：每个 pipeline 包起新 harness，首次用时 lazy 装 Python + uv via
# mise。并行包执行时多个 mise install 互不知情，会撞磁盘 / 触上游限流 /
# 击中 mise plugin 缓存竞态。串行约 4 分钟跑完，换确定性。
test-pipeline:
	$(AUTO_DEVBOX)
	@$(LOAD_ENV) cd backend && go test -count=1 -tags=pipeline -p 1 ./test/...

# stop — kill anything bound to the dev port.
# stop——杀占用 dev 端口的进程。
stop:
	@PIDS=$$(lsof -ti :$(PORT) 2>/dev/null || true); \
	if [ -n "$$PIDS" ]; then \
		echo "→ stopping PID(s): $$(echo $$PIDS | tr '\n' ' ')"; \
		echo "$$PIDS" | xargs kill 2>/dev/null || true; \
		echo "✓ stopped"; \
	else \
		echo "✓ nothing running"; \
	fi

# ── Optional helpers ─────────────────────────────────────────────────────────

# resources — download mise binary into backend/internal/infra/sandbox/mise/
# for go:embed (D2-2). Default: current platform only. Pass ALL=1 to fetch
# all 5 supported platforms (release pipeline use). Pin version via
# MISE_VERSION env (defaults to latest).
#
# resources——把 mise 二进制下到 backend/internal/infra/sandbox/mise/ 给
# go:embed（D2-2）用。默认仅当前平台；ALL=1 拉全 5 平台（release pipeline 用）。
# MISE_VERSION env 钉版本（默认 latest）。
resources:
	$(AUTO_DEVBOX)
	@cd backend && go run ./cmd/resources $(if $(ALL),--all-platforms,)

# clear — stop dev backend + reset data dir.
# clear——停 dev backend + 清数据目录。
clear: stop
	@rm -rf $(BACKEND_DATA_DIR)
	@rm -rf .venv/
	@echo "✓ cleared (db + attachments + stray venv)"

.PHONY: help environment test-console test-unit test-pipeline stop clear
