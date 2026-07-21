MISE ?= $(shell command -v mise 2>/dev/null || printf '%s/.local/bin/mise' "$$HOME")
RUN := $(MISE) exec --

.DEFAULT_GOAL := help

help:
	@echo "Anselm web demo"
	@echo ""
	@echo "  make setup     install locked Node dependencies + Chromium"
	@echo "  make serve     preview the demo"
	@echo "  make lint      check design-system source rules"
	@echo "  make test      run the Playwright matrix"
	@echo "  make verify    run lint + Playwright matrix"
	@echo "  make clean     remove local Node dependencies"

# The stamp gives day-to-day commands dependency self-healing without making
# every `make test` reinstall node_modules. npm ci is frozen by package-lock;
# Playwright's browser binary is version-coupled to that lock.
toolchain:
	@test -x "$(MISE)" || $(MAKE) -C .. toolchain

node_modules/.anselm-ready: package.json package-lock.json
	@echo "→ installing locked demo packages…"
	@$(RUN) npm ci
	@echo "→ installing Playwright Chromium…"
	@$(RUN) npx playwright install chromium
	@touch $@
	@echo "✓ demo dependencies ready"

setup: toolchain node_modules/.anselm-ready

deps: setup

serve: deps
	@$(RUN) node tools/serve.mjs

lint: deps
	@$(RUN) node tools/lint.mjs

test: deps
	@$(RUN) node tools/matrix.mjs

verify: lint test
	@echo "✓ web demo verified"

clean:
	@rm -rf node_modules
	@echo "✓ demo dependencies cleaned"

.PHONY: help toolchain setup deps serve lint test verify clean
