# Backend-local commands. All targets act only on the Go service and its development state.

ROOT := ..
DATA ?= /tmp/anselm-dev
PORT ?= 8742
MISE ?= $(shell command -v mise 2>/dev/null || printf '%s/.local/bin/mise' "$$HOME")
RUN := $(MISE) exec --
SHELL := /bin/bash

.DEFAULT_GOAL := help

help:
	@echo "Anselm backend"
	@echo ""
	@echo "  make setup     ensure Go dependencies for service + acceptance suite"
	@echo "  make run       start the development server on :$(PORT)"
	@echo "  make stop      gracefully stop the development server"
	@echo "  make format    write canonical Go formatting"
	@echo "  make test      run Go unit tests"
	@echo "  make testend   run black-box acceptance tests (slow)"
	@echo "  make evals     run real-model golden journeys (costs tokens)"
	@echo "  make build     build ../bin/anselm-server"
	@echo "  make verify    check format, vet, build, and tests"
	@echo "  make clean     remove backend build output and dev data"

toolchain:
	@test -x "$(MISE)" || $(MAKE) -C .. toolchain

setup: toolchain
	@echo "→ downloading backend Go modules…"
	@$(RUN) go mod download
	@echo "→ downloading acceptance-suite Go modules…"
	@cd $(ROOT)/testend && $(RUN) go mod download
	@echo "✓ backend dependencies ready"

# Kept phony deliberately: Go's module cache is global and can be evicted outside
# this repository. Re-running `go mod download` is cheap when warm and self-heals
# every ordinary command on a fresh or cleaned machine.
deps: setup

run: deps
	@set -a; [ -f $(ROOT)/.env ] && source $(ROOT)/.env; set +a; \
	ANSELM_DEV=1 ANSELM_ADDR=:$(PORT) ANSELM_DATA_DIR=$(DATA) $(RUN) go run ./cmd/server

stop:
	@PIDS=$$(lsof -ti :$(PORT) 2>/dev/null || true); \
	if [ -n "$$PIDS" ]; then \
		echo "→ SIGTERM :$(PORT)"; echo "$$PIDS" | xargs kill -TERM 2>/dev/null || true; \
		for i in $$(seq 1 20); do lsof -ti :$(PORT) >/dev/null 2>&1 || break; sleep 0.5; done; \
	fi

format: deps
	@$(RUN) gofmt -w $$(find . -name '*.go' -not -path './vendor/*')
	@echo "✓ backend formatted"

test: deps
	@$(RUN) go test -count=1 ./...

testend: deps
	@cd $(ROOT)/testend && $(RUN) go test -count=1 -timeout 30m ./scenarios/...

evals: deps
	@set -a; [ -f $(ROOT)/.env ] && source $(ROOT)/.env; set +a; \
	cd $(ROOT)/testend && EVALS=1 $(RUN) go test -count=1 -timeout 30m ./golden/...

build: deps
	@mkdir -p $(ROOT)/bin
	@$(RUN) go build -o $(ROOT)/bin/anselm-server ./cmd/server

verify: deps
	@unformatted="$$($(RUN) gofmt -l $$(find . -name '*.go' -not -path './vendor/*'))"; \
	if [ -n "$$unformatted" ]; then echo "✗ Go files need formatting:"; echo "$$unformatted"; echo "  Run: make -C backend format"; exit 1; fi
	@$(RUN) go vet ./...
	@mkdir -p $(ROOT)/bin
	@$(RUN) go build -o $(ROOT)/bin/anselm-server ./cmd/server
	@$(RUN) go test -count=1 ./...
	@echo "✓ backend verified"

clean: stop
	@rm -rf $(DATA) $(ROOT)/bin/anselm-server
	@echo "✓ backend cleaned"

.PHONY: help toolchain setup deps run stop format test testend evals build verify clean
