# Anselm workspace entrypoint. Root owns only cross-project actions; use each directory's Makefile
# for local work. 根目录只编排跨域动作；具体开发进入对应目录。

.DEFAULT_GOAL := help

help:
	@echo "Anselm workspace"
	@echo ""
	@echo "  make setup    prepare the shared toolchain"
	@echo "  make verify   verify backend + frontend + docs"
	@echo "  make clean    clean all generated development state"
	@echo ""
	@echo "  Local commands: make -C backend help | make -C frontend help | make -C docs help"

setup:
	@command -v mise >/dev/null 2>&1 || { \
		echo "→ install mise…"; \
		brew install mise 2>/dev/null || curl -fsSL https://mise.run | sh; }
	@mise trust >/dev/null 2>&1; mise install
	@$(MAKE) -C frontend setup
	@echo "✓ workspace ready"

verify:
	@$(MAKE) -C backend verify
	@$(MAKE) -C frontend verify
	@$(MAKE) -C docs verify
	@echo "✓ workspace verified"

# Clears generated development state only: backend dev data/build output plus Flutter build caches.
# It NEVER touches tracked codegen, Git state, global SDK caches, or ~/.anselm user data.
clean:
	@$(MAKE) -C backend clean
	@$(MAKE) -C frontend clean
	@echo "✓ workspace cleaned"

.PHONY: help setup verify clean
