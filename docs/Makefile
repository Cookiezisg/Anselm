# Documentation-local checks. The checker is implemented in backend/cmd/docs but owned here.

RUN := mise exec --

.DEFAULT_GOAL := help

help:
	@echo "Anselm documentation"
	@echo ""
	@echo "  make verify    validate documentation contracts and links"

verify:
	@cd ../backend && $(RUN) go run ./cmd/docs --root=..

.PHONY: help verify
