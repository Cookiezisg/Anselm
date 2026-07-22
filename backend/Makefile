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

# No -count=1: Go's test cache is content-addressed and CORRECT (code/deps/env changes invalidate it
# automatically) — forcing reruns of untouched packages was pure waste. testend below is the opposite
# case: an independent module testing the compiled backend BINARY, whose changes its cache cannot see,
# so -count=1 there is mandatory. 不带 -count=1:Go 测试缓存内容寻址、正确,强制重跑未动的包纯属浪费;
# testend 相反——独立 module 测编译出的后端二进制,缓存看不见其变化,必须 -count=1。
test: deps
	@$(RUN) go test ./...

# -parallel 16: every scenario is a fully isolated universe (own temp data dir + free port + own
# process group), boot-tax dominated — serial execution was pure queueing. -count=1 stays (see
# `test` above: this module tests the compiled backend BINARY, whose changes Go's cache cannot see).
# -parallel 16:每个场景都是完全隔离的宇宙(独立临时数据目录+空闲端口+独立进程组)、boot 税占大头,
# 串行纯属排队。-count=1 保留(见上 test 注释:本 module 测编译出的后端二进制,Go 缓存看不见其变化)。
testend: deps
	@cd $(ROOT)/testend && $(RUN) go test -count=1 -parallel 16 -timeout 15m ./scenarios/...

evals: deps
	@set -a; [ -f $(ROOT)/.env ] && source $(ROOT)/.env; set +a; \
	cd $(ROOT)/testend && EVALS=1 $(RUN) go test -count=1 -timeout 30m ./golden/...

build: deps
	@mkdir -p $(ROOT)/bin
	@$(RUN) go build -o $(ROOT)/bin/anselm-server ./cmd/server

# vet and build+test are independent compile pipelines (both ride Go's build cache) — run vet
# concurrently and the gate's wall clock is max(vet, build+test), not the sum.
# vet 与 build+test 是独立编译管线(都走 Go 构建缓存)——vet 并发跑,门禁墙钟=max 非 sum。
verify: deps
	@unformatted="$$($(RUN) gofmt -l $$(find . -name '*.go' -not -path './vendor/*'))"; \
	if [ -n "$$unformatted" ]; then echo "✗ Go files need formatting:"; echo "$$unformatted"; echo "  Run: make -C backend format"; exit 1; fi
	@vetlog=$$(mktemp); $(RUN) go vet ./... > "$$vetlog" 2>&1 & vetpid=$$!; \
	mkdir -p $(ROOT)/bin && $(RUN) go build -o $(ROOT)/bin/anselm-server ./cmd/server && $(RUN) go test ./...; testrc=$$?; \
	if wait $$vetpid; then vetrc=0; else vetrc=1; fi; \
	if [ $$vetrc != 0 ]; then echo "✗ go vet:"; cat "$$vetlog"; fi; rm -f "$$vetlog"; \
	[ $$testrc = 0 ] && [ $$vetrc = 0 ]
	@echo "✓ backend verified"

clean: stop
	@rm -rf $(DATA) $(ROOT)/bin/anselm-server
	@echo "✓ backend cleaned"

.PHONY: help toolchain setup deps run stop format test testend evals build verify clean
