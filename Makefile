# Anselm workspace entrypoint. Root owns only cross-project actions; use each directory's Makefile
# for local work. 根目录只编排跨域动作；具体开发进入对应目录。

SHELL := /bin/bash
MISE ?= $(shell command -v mise 2>/dev/null || printf '%s/.local/bin/mise' "$$HOME")

.DEFAULT_GOAL := help

help:
	@echo "Anselm workspace"
	@echo ""
	@echo "  make setup    prepare every locked development dependency"
	@echo "  make verify   verify backend + frontend + docs + web demo"
	@echo "  make clean    remove every recreatable workspace artifact"
	@echo "  make doctor   report the host prerequisites for desktop development"
	@echo ""
	@echo "  Local commands: make -C backend help | make -C frontend help | make -C docs help"

# Internal bootstrap only. The official installer lands in ~/.local/bin, which is
# not necessarily on PATH until the next shell; invoke that exact binary in this
# shell so a fresh macOS/Linux checkout can continue without a restart.
toolchain:
	@set -euo pipefail; \
	if command -v mise >/dev/null 2>&1; then mise_bin="$$(command -v mise)"; \
	else \
		case "$$(uname -s)" in \
			Darwin|Linux) \
				command -v curl >/dev/null 2>&1 || { echo "✗ setup needs curl to install mise"; exit 1; }; \
				echo "→ installing mise…"; curl -fsSL https://mise.run | sh; mise_bin="$$HOME/.local/bin/mise" ;; \
			*) echo "✗ install mise first, then rerun make setup (Windows: scoop install mise)"; exit 1 ;; \
		esac; \
	fi; \
	test -x "$$mise_bin" || { echo "✗ mise installation did not produce an executable"; exit 1; }; \
	echo "→ preparing pinned toolchain…"; "$$mise_bin" trust -a; "$$mise_bin" install

setup: toolchain
	@echo "→ preparing backend…"
	@$(MAKE) -C backend setup MISE="$(MISE)"
	@echo "→ preparing frontend…"
	@$(MAKE) -C frontend setup MISE="$(MISE)"
	@echo "→ preparing web demo…"
	@$(MAKE) -C demo setup MISE="$(MISE)"
	@echo "✓ workspace ready"

# The four sub-gates are INDEPENDENT (different toolchains, zero shared state) — run them
# concurrently and the wall clock is max(), not sum(). Each writes its own log; a failing gate
# prints its full log at the end (interleaved four-way output would be soup). Frontend and backend
# both parallelize internally already, so the box is CPU-saturated but not oversubscribed for long:
# backend's test wall is mostly Go-cache hits and docs/demo are seconds.
# 四子门禁彼此独立(工具链不同、零共享态)——并发跑,墙钟=max 而非 sum。各写独立 log,失败门禁末尾
# 整段打印(四路交错输出是一锅粥)。前端/后端各自内部已并行,但后端测试墙多为缓存命中、docs/demo
# 秒级,长时间超订不存在。
verify: toolchain
	@echo "→ verifying backend + frontend + docs + web demo (parallel)…"
	@LOGDIR=$$(mktemp -d "$${TMPDIR:-/tmp}/anselm-rootverify-XXXXXX"); \
	fail=0; pids=""; \
	for gate in backend frontend docs demo; do \
		$(MAKE) -C $$gate verify MISE="$(MISE)" > "$$LOGDIR/$$gate.log" 2>&1 & \
		pids="$$pids $$gate:$$!"; \
	done; \
	for entry in $$pids; do \
		gate=$${entry%%:*}; pid=$${entry##*:}; \
		if wait $$pid; then \
			echo "  ✓ $$gate"; \
		else \
			fail=1; echo ""; echo "✗ $$gate verify FAILED — full log:"; cat "$$LOGDIR/$$gate.log"; echo ""; \
		fi; \
	done; \
	if [ $$fail = 0 ]; then rm -rf "$$LOGDIR"; echo "✓ workspace verified"; else echo "  (logs kept in $$LOGDIR)"; exit 1; fi

# Clears generated development state only: backend dev data/build output plus Flutter build caches.
# It NEVER touches tracked codegen, Git state, global SDK caches, or ~/.anselm user data.
clean: toolchain
	@echo "→ cleaning backend…"
	@$(MAKE) -C backend clean MISE="$(MISE)"
	@echo "→ cleaning frontend…"
	@$(MAKE) -C frontend clean MISE="$(MISE)"
	@echo "→ cleaning web demo…"
	@$(MAKE) -C demo clean MISE="$(MISE)"
	@echo "✓ workspace cleaned"

doctor: toolchain
	@echo "→ checking Flutter desktop host…"
	@$(MISE) exec -- flutter doctor
	@echo "✓ doctor completed (fix every red item before running a native desktop target)"

.PHONY: help toolchain setup verify clean doctor
