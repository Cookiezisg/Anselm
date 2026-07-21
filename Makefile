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

verify: toolchain
	@echo "→ verifying backend…"
	@$(MAKE) -C backend verify MISE="$(MISE)"
	@echo "→ verifying frontend…"
	@$(MAKE) -C frontend verify MISE="$(MISE)"
	@echo "→ verifying docs…"
	@$(MAKE) -C docs verify MISE="$(MISE)"
	@echo "→ verifying web demo…"
	@$(MAKE) -C demo verify MISE="$(MISE)"
	@echo "✓ workspace verified"

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
