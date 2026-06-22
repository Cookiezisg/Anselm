# ──────────────────────────────────────────────────────────────────
# Anselm 前端（Flutter 桌面端，ADR 0004）— 单词目标，在 frontend/ 下跑。
# 后端 + 仓库级目标在仓库根 Makefile。flutter 由 mise 提供（真·可写官方 SDK）。
#
# 三种启动:  make demo     真 app 形态 + fixture 数据、零后端（看效果）
#            make gallery  组件画廊（UI 套件落地后启用）
#            make app      真 app + 后端 sidecar
# 开发门禁:  setup / gen / analyze / test / verify
# ──────────────────────────────────────────────────────────────────

RUN := mise exec --

.DEFAULT_GOAL := help

help:
	@echo "Anselm 前端（Flutter）— 在 frontend/ 下:"
	@echo "  启动:  make demo     真 app 形态 + fixture、零后端"
	@echo "         make app      真 app + 后端"
	@echo "  开发:  make setup    拉依赖（flutter pub get）"
	@echo "         make gen      codegen（dart run slang → i18n strings.g.dart）"
	@echo "         make analyze  flutter analyze（须净）"
	@echo "         make test     flutter test"
	@echo "         make verify   pre-push 门禁（gen + analyze + test）"

# setup — 拉前端依赖（首次或改 pubspec 后）。
setup:
	@$(RUN) flutter pub get

# gen — codegen。当前只有 slang i18n（dart run slang，非 build_runner）。产物入库（deterministic）。
# 改 lib/i18n/*.i18n.json 后跑。freezed/json 待契约层落地再加进来。
gen:
	@$(RUN) dart run slang

# analyze — 静态分析（须净）。
analyze:
	@$(RUN) flutter analyze

# test — 单测。
test:
	@$(RUN) flutter test

# verify — pre-push 门禁:codegen + 分析净 + 单测绿。
verify:
	@echo "→ gen…"     && $(RUN) dart run slang
	@echo "→ analyze…" && $(RUN) flutter analyze
	@echo "→ test…"    && $(RUN) flutter test
	@echo "" && echo "✓ verify 全绿（gen + analyze + test）"

# demo — 真 app 形态（骨架阶段:三岛空壳;后续接 fixture 数据）。
demo:
	@LANG=en_US.UTF-8 $(RUN) flutter run -d macos

# app — 真 app + 后端 sidecar（后续接 backend）。
app:
	@LANG=en_US.UTF-8 $(RUN) flutter run -d macos

.PHONY: help setup gen analyze test verify demo app
