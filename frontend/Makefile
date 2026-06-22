# ──────────────────────────────────────────────────────────────────
# Anselm 前端（Flutter 桌面端，ADR 0004）— 单词目标，在 frontend/ 下跑。
# 后端 + 仓库级目标在仓库根 Makefile。flutter 由 mise 提供（真·可写官方 SDK）。
#
# 三种启动:  make demo     真 app 形态 + fixture 数据、零后端（看效果）
#            make gallery  组件画廊
#            make app      真 app + 后端 sidecar（先在仓库根 make server）
# 开发门禁:  setup / gen / analyze / test / verify
# ──────────────────────────────────────────────────────────────────

RUN          := mise exec --
BACKEND_PORT ?= 8742

.DEFAULT_GOAL := help

help:
	@echo "Anselm 前端（Flutter）— 在 frontend/ 下:"
	@echo "  启动:  make demo     真 app 形态 + fixture 数据、零后端"
	@echo "         make gallery  组件画廊"
	@echo "         make app      真 app + 后端（先在仓库根 make server）"
	@echo "  开发:  make setup    拉依赖（flutter pub get）"
	@echo "         make gen      codegen（freezed/json + slang i18n）"
	@echo "         make analyze  flutter analyze（须净）"
	@echo "         make test     flutter test"
	@echo "         make verify   pre-push 门禁（gen + analyze + test）"

# setup — 拉前端依赖（首次或改 pubspec 后）。
setup:
	@$(RUN) flutter pub get

# gen — codegen：build_runner 出 freezed/json_serializable；slang CLI 出 i18n。
# 产物入库（源等价、deterministic）；改带注解的源或 i18n 文案后重跑。
gen:
	@$(RUN) dart run build_runner build --delete-conflicting-outputs
	@$(RUN) dart run slang

# analyze — 静态分析（须净）。
analyze:
	@$(RUN) flutter analyze

# test — 单测。
test:
	@$(RUN) flutter test

# verify — pre-push 门禁：codegen + 分析净 + 单测绿。
# （桌面真跑 demo/gallery/app 需完整 Xcode + CocoaPods,属机器层面、不入门禁。）
verify:
	@echo "→ gen…"     && $(RUN) dart run build_runner build --delete-conflicting-outputs && $(RUN) dart run slang
	@echo "→ analyze…" && $(RUN) flutter analyze
	@echo "→ test…"    && $(RUN) flutter test
	@echo "" && echo "✓ verify 全绿（gen + analyze + test）"

# demo — 真 app 形态 + fixture 数据、零后端（一个入口看所有 feature 效果）。
demo:
	@LANG=en_US.UTF-8 $(RUN) flutter run -t lib/dev/demo_main.dart -d macos

# gallery — 组件画廊（独立入口,零后端:验收单色设计语言 + UI 套件）。
gallery:
	@LANG=en_US.UTF-8 $(RUN) flutter run -t lib/dev/gallery_main.dart -d macos

# app — 真 app + 后端 sidecar（dev:挂到已跑后端,先在仓库根 make server）。
app:
	@LANG=en_US.UTF-8 ANSELM_BACKEND_URL=http://127.0.0.1:$(BACKEND_PORT) $(RUN) flutter run -d macos

.PHONY: help setup gen analyze test verify demo gallery app
