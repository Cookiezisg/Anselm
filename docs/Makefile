# Documentation-local checks. The checker is implemented in backend/cmd/docs but owned here.

MISE ?= $(shell command -v mise 2>/dev/null || printf '%s/.local/bin/mise' "$$HOME")
RUN := $(MISE) exec --

.DEFAULT_GOAL := help

help:
	@echo "Anselm documentation"
	@echo ""
	@echo "  make setup     ensure the documentation checker is runnable"
	@echo "  make verify    validate documentation contracts and links"

toolchain:
	@test -x "$(MISE)" || $(MAKE) -C .. toolchain

setup: toolchain
	@$(RUN) go version >/dev/null
	@echo "✓ documentation checker ready"

verify: setup
	@cd ../backend && $(RUN) go run ./cmd/docs --root=..
	@echo "✓ documentation verified"

.PHONY: help toolchain setup verify
