# Backend-local commands. All targets act only on the Go service and its development state.

ROOT := ..
DATA ?= /tmp/anselm-dev
PORT ?= 8742
RUN := mise exec --
SHELL := /bin/bash

.DEFAULT_GOAL := help

help:
	@echo "Anselm backend"
	@echo ""
	@echo "  make run       start the development server on :$(PORT)"
	@echo "  make stop      gracefully stop the development server"
	@echo "  make test      run Go unit tests"
	@echo "  make testend   run black-box acceptance tests (slow)"
	@echo "  make evals     run real-model golden journeys (costs tokens)"
	@echo "  make build     build ../bin/anselm-server"
	@echo "  make verify    run format, vet, build, and tests"
	@echo "  make clean     remove backend build output and dev data"

run:
	@set -a; [ -f $(ROOT)/.env ] && source $(ROOT)/.env; set +a; \
	ANSELM_DEV=1 ANSELM_ADDR=:$(PORT) ANSELM_DATA_DIR=$(DATA) $(RUN) go run ./cmd/server

stop:
	@PIDS=$$(lsof -ti :$(PORT) 2>/dev/null || true); \
	if [ -n "$$PIDS" ]; then \
		echo "→ SIGTERM :$(PORT)"; echo "$$PIDS" | xargs kill -TERM 2>/dev/null || true; \
		for i in $$(seq 1 20); do lsof -ti :$(PORT) >/dev/null 2>&1 || break; sleep 0.5; done; \
	fi

test:
	@$(RUN) go test -count=1 ./...

testend:
	@cd $(ROOT)/testend && $(RUN) go test -count=1 -timeout 30m ./scenarios/...

evals:
	@set -a; [ -f $(ROOT)/.env ] && source $(ROOT)/.env; set +a; \
	cd $(ROOT)/testend && EVALS=1 $(RUN) go test -count=1 -timeout 30m ./golden/...

build:
	@mkdir -p $(ROOT)/bin
	@$(RUN) go build -o $(ROOT)/bin/anselm-server ./cmd/server

verify:
	@$(RUN) gofmt -w $$(find . -name '*.go' -not -path './vendor/*')
	@$(RUN) go vet ./...
	@$(MAKE) build
	@$(MAKE) test

clean: stop
	@rm -rf $(DATA) $(ROOT)/bin/anselm-server
	@echo "✓ backend cleaned"

.PHONY: help run stop test testend evals build verify clean
