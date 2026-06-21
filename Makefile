# ──────────────────────────────────────────────────────────────────
# Anselm — make 命令（后端 Go 单体 + 前端 Flutter 桌面端）
# ──────────────────────────────────────────────────────────────────
#
#   环境   setup    创建开发环境（mise 装 pin 的 go + flutter）
#   运行   server   起后端服务（ANSELM_DEV，端口 $(BACKEND_PORT)）
#          stop     优雅关停后端（SIGTERM → App.Serve 有序关停）
#   测试   unit     Go 单测（in-memory SQLite）
#          testend  全功能黑盒验收（testend/ 真起后端二进制 + llmmock；分钟级，不进 verify）
#          evals    金标 LLM 旅程（testend/golden，真模型烧钱；手动触发）
#   文档   docs     文档规范门禁（cmd/docs，GOVERNANCE §11 全套）
#   出包   build    后端二进制 → bin/anselm-server
#   门禁   verify   后端 pre-push：gofmt + vet + build + unit + docs（host 平台）
#   前端   fe-gen   codegen（freezed/json/slang，build_runner）
#          fe-analyze / fe-test  Flutter 静态分析 / 单测
#          fe-verify Flutter pre-push：gen + analyze + test
#          fe-run   起桌面 app（dev 挂到已跑后端）
#   清理   clean    清 dev 数据目录
#
# ──────────────────────────────────────────────────────────────────

BACKEND_DATA_DIR ?= /tmp/anselm-dev
BACKEND_PORT     ?= 8742

SHELL    := /bin/bash
LOAD_ENV := set -a; [ -f .env ] && source .env; set +a;

# 工具链 = mise（替代 devbox/nix）。`mise exec --` 把 mise.toml 钉的 go/flutter 放上 PATH 再跑——
# 不依赖 shell 是否已激活 mise（make recipe 跑在 /bin/bash、未必激活）。装真·可写官方 SDK
# （nix 只读 store 构建不了 macOS app，见 ADR 0005）。
MISE ?= mise
RUN  := $(MISE) exec --

.DEFAULT_GOAL := help

help:
	@echo "Anselm（后端 Go 单体 + 前端 Flutter 桌面端）"
	@echo ""
	@echo "  环境:   make setup    创建开发环境（mise: go + flutter）"
	@echo "  运行:   make server   起后端服务（:$(BACKEND_PORT)）"
	@echo "          make stop     优雅关停后端"
	@echo "  测试:   make unit     Go 单测"
	@echo "          make testend  全功能黑盒验收（真二进制 + llmmock，分钟级）"
	@echo "          make evals    金标 LLM 旅程（真模型，烧钱，手动跑）"
	@echo "  文档:   make docs     文档规范门禁（GOVERNANCE §11）"
	@echo "  出包:   make build    后端二进制 → bin/anselm-server"
	@echo "  门禁:   make verify   后端 pre-push（gofmt+vet+build+unit+docs）"
	@echo "  前端:   make fe-gen   codegen（freezed/json/slang）"
	@echo "          make fe-verify Flutter pre-push（gen+analyze+test）"
	@echo "          make fe-run   起桌面 app（dev，先 make server）"
	@echo "          make fe-gallery 起设计画廊（独立入口,零后端）"
	@echo "  清理:   make clean    清 dev 数据（$(BACKEND_DATA_DIR)）"

# ── 环境 ────────────────────────────────────────────────────────────

# setup — 装 mise（若缺）再 mise install（按 mise.toml 装 pin 的 go + flutter）。运行时
# （python/node/uv/dotnet）首次使用时由后端 directInstaller 从上游按需下,无需预装。
# 装好后:后端 make server;前端 make fe-gen 再 make fe-run。
setup:
	@command -v $(MISE) >/dev/null 2>&1 || { \
		echo "→ 装 mise…"; \
		brew install mise 2>/dev/null || curl -fsSL https://mise.run | sh; }
	@$(MISE) trust >/dev/null 2>&1; $(MISE) install
	@echo ""
	@echo "✓ setup 完成（mise 装了 pin 的 go + flutter）。"
	@echo "  fish 已自动激活;bash/zsh 把 'eval \"\$$($(MISE) activate <shell>)\"' 加进 profile。"
	@echo "  现在：make server"

# ── 运行 ────────────────────────────────────────────────────────────

# server — 起后端。main 读环境变量（ANSELM_DEV/ADDR/DATA_DIR），非 flag。
server:
	@$(LOAD_ENV) cd backend && ANSELM_DEV=1 ANSELM_ADDR=:$(BACKEND_PORT) ANSELM_DATA_DIR=$(BACKEND_DATA_DIR) $(RUN) go run ./cmd/server

# stop — 给监听进程发 SIGTERM → App.Serve 跑有序优雅关停（SSE 流 → HTTP 排空 → 后台 → DB）。非 -9。
stop:
	@PIDS=$$(lsof -ti :$(BACKEND_PORT) 2>/dev/null || true); \
	if [ -n "$$PIDS" ]; then \
		echo "→ SIGTERM :$(BACKEND_PORT)（pid $$(echo $$PIDS | tr '\n' ' ')），等优雅关停…"; \
		echo "$$PIDS" | xargs kill -TERM 2>/dev/null || true; \
		for i in $$(seq 1 20); do lsof -ti :$(BACKEND_PORT) >/dev/null 2>&1 || break; sleep 0.5; done; \
		echo "✓ 已停"; \
	else echo "✓ 没在跑"; fi

# ── 测试 / 文档 ──────────────────────────────────────────────────────

unit:
	@cd backend && $(RUN) go test -count=1 ./...

# testend — 全功能黑盒验收：编译并拉起真 backend 二进制，纯 HTTP/SSE 打全功能场景（零 backend import）。
# 首跑会下载 sandbox 运行时（之后走 ~/.anselm-testend-cache 缓存）。
testend:
	@cd testend && $(RUN) go test -count=1 -timeout 30m ./scenarios/...

# evals — 金标 LLM 旅程：真模型端到端（柱C）。烧钱，手动跑。自动 source 仓库根 .env（若存在）注入
# key——默认认 DEEPSEEK_API_KEY + deepseek-v4-flash；EVALS_BASE_URL/EVALS_MODEL/EVALS_KEY 可覆盖。
evals:
	@if [ -f .env ]; then set -a; . ./.env; set +a; fi; cd testend && EVALS=1 $(RUN) go test -count=1 -timeout 60m ./golden/...

# docs — 文档规范门禁：frontmatter / 类型 / 生命周期 / INDEX≤50 / 孤儿链接（GOVERNANCE §11）。
docs:
	@cd backend && $(RUN) go run ./cmd/docs --root=..

# ── 出包 ────────────────────────────────────────────────────────────

# build — 后端 host 二进制。TODO：打包时把它作为 sidecar 二进制随 Flutter app 分发（flutter build
# <platform> + 把 anselm-server 放进 bundle，客户端经 ANSELM_ADDR 拉起，见 ADR 0004 §1）。
build:
	@cd backend && $(RUN) go build -o bin/anselm-server ./cmd/server
	@echo "✓ backend/bin/anselm-server"

# ── 门禁 ────────────────────────────────────────────────────────────

# verify — pre-push 门禁：gofmt 净 + vet + build + 单测 + 文档门禁。
# 跨平台 release 现在就是 `cd backend && GOOS=x GOARCH=y go build ./cmd/server`——无内嵌、无预拉；
# 运行时（python/node/uv/dotnet）在目标机首次使用时按需下，故无平台依赖、go build 可直接交叉编译。
verify:
	@echo "→ gofmt…"
	@cd backend && f=$$($(RUN) gofmt -l .); [ -z "$$f" ] || { echo "✗ gofmt 未净:"; echo "$$f"; exit 1; }
	@echo "→ go vet…"
	@cd backend && $(RUN) go vet ./...
	@echo "→ go build…"
	@cd backend && $(RUN) go build ./...
	@echo "→ unit…"
	@cd backend && $(RUN) go test -count=1 ./...
	@echo "→ docs…"
	@cd backend && $(RUN) go run ./cmd/docs --root=..
	@echo ""
	@echo "✓ verify 全绿（gofmt + vet + build + unit + docs）"

# ── 前端（Flutter 桌面端，ADR 0004）────────────────────────────────────
#
# flutter 由 mise 提供（真·可写官方 SDK）。macOS 原生构建用系统 Xcode 工具链——mise 不像 nix
# 那样注入编译器 wrapper,故 xcodebuild 环境干净（ADR 0005 记此取舍）。

# fe-setup — 拉前端依赖（首次或改 pubspec 后）。
fe-setup:
	@cd frontend && $(RUN) flutter pub get

# fe-gen — codegen：freezed/json_serializable/slang 经 build_runner 生成 *.g.dart / *.freezed.dart。
# 注:本仓库 codegen 产物入库（源等价、deterministic），故 fresh checkout 直接 fe-analyze 即可；
# 改了带注解的源或 i18n 文案后重跑本目标。
fe-gen:
	@cd frontend && $(RUN) flutter pub run build_runner build

# fe-analyze — Flutter 静态分析（须净）。
fe-analyze:
	@cd frontend && $(RUN) flutter analyze

# fe-test — Flutter 单测。
fe-test:
	@cd frontend && $(RUN) flutter test

# fe-verify — 前端 pre-push 门禁：codegen + 分析净 + 单测绿。
# （桌面真跑 fe-run 需完整 Xcode + CocoaPods，属机器层面、不入门禁。）
fe-verify:
	@cd frontend \
		&& echo "→ fe codegen…"  && $(RUN) flutter pub run build_runner build \
		&& echo "→ fe analyze…"  && $(RUN) flutter analyze \
		&& echo "→ fe test…"     && $(RUN) flutter test \
		&& echo "" && echo "✓ fe-verify 全绿（gen + analyze + test）"

# fe-run — 起桌面 app（dev:挂到已跑后端,先 make server）。macOS 真跑需完整 Xcode + CocoaPods。
fe-run:
	@cd frontend && LANG=en_US.UTF-8 ANSELM_BACKEND_URL=http://127.0.0.1:$(BACKEND_PORT) $(RUN) flutter run -d macos

# fe-gallery — 起设计画廊（独立入口,零后端:验收单色设计语言 + UI 套件）。macOS 真跑需完整 Xcode + CocoaPods。
fe-gallery:
	@cd frontend && LANG=en_US.UTF-8 $(RUN) flutter run -t lib/dev/gallery_main.dart -d macos

# ── 清理 ────────────────────────────────────────────────────────────

# clean — 停服务 + 清 dev 数据目录（SQLite + 附件 + sandbox 运行时 + mcp + skills 都在 $(BACKEND_DATA_DIR)）。
# 不碰 ~/.anselm（真实用户数据）、不碰 docs/。
clean: stop
	@rm -rf $(BACKEND_DATA_DIR)
	@echo "✓ 已清 $(BACKEND_DATA_DIR)"

.PHONY: help setup server stop unit docs build verify clean testend evals \
        fe-setup fe-gen fe-analyze fe-test fe-verify fe-run fe-gallery
