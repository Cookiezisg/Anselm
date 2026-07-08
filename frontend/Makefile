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
	@echo "         make gallery  组件画廊（看每个 An* 全态）"
	@echo "         make app      真 app + 真后端(自动起后端 + 热重载)"
	@echo "  开发:  make setup    拉依赖（flutter pub get）"
	@echo "         make gen      codegen（dart run slang → i18n strings.g.dart）"
	@echo "         make analyze  flutter analyze（须净）"
	@echo "         make test     flutter test"
	@echo "         make verify   pre-push 门禁（gen + analyze + test）"
	@echo "  截图:  make shots    无头渲染 shell + 画廊全类 → test/dev/out/*.png"

# setup — 拉前端依赖（首次或改 pubspec 后）。
setup:
	@$(RUN) flutter pub get

# gen — codegen。两套:① slang i18n(dart run slang,自有 runner)② freezed+json(build_runner,
# 范围见 build.yaml:contract+features/data)。产物均入库(deterministic,fresh checkout 直接 analyze);
# 改 i18n json / 契约 DTO 后跑,verify 也会重跑以抓漂移。
gen:
	@$(RUN) dart run slang
	@$(RUN) dart run build_runner build --delete-conflicting-outputs

# analyze — 静态分析（须净）。
analyze:
	@$(RUN) flutter analyze

# test — 单测。
test:
	@$(RUN) flutter test

# verify — pre-push 门禁:codegen + 分析净 + 单测绿。
verify:
	@echo "→ gen(slang)…"        && $(RUN) dart run slang
	@echo "→ gen(build_runner)…" && $(RUN) dart run build_runner build --delete-conflicting-outputs
	@echo "→ analyze…"           && $(RUN) flutter analyze
	@echo "→ test…"              && $(RUN) flutter test
	@echo "" && echo "✓ verify 全绿（gen + analyze + test）"

# demo — 真 app 形态（骨架阶段:三岛空壳;后续接 fixture 数据）。
# demo — 真 app 壳（AppShell，同 make app）+ 假数据（fixture override、零后端、跳启动门控）。
# 「真 app + 假数据」唯一面:凡接进 AppShell 的 feature 在此自动出现。绝不加 per-feature 入口。
demo:
	@LANG=en_US.UTF-8 $(RUN) flutter run -d macos -t lib/dev/demo_main.dart

# gallery — 组件画廊（dev/gallery_main.dart）：双栏目录看每个 An* 组件全态（视觉，与 app/demo 正交）。
gallery:
	@LANG=en_US.UTF-8 $(RUN) flutter run -d macos -t lib/dev/gallery_main.dart

# app — 真 app 壳（AppShell）+ 真后端,带热重载。自动起后端(make server,后台常驻)+ dev-attach。
# 生产的"spawn 打包 sidecar"需把签名 Go 二进制打进 .app(发行阶段 WRK-043)。详见 test/dev/run_app.sh。
app:
	@bash test/dev/run_app.sh

# shots — 无头渲染截图(Skia toImage,免 Xcode)→ test/dev/out/*.png 供肉眼/AI 对照 demo 审。
# capture_*.dart 把 toImage/toByteData 包进 tester.runAsync:它们是引擎线程真异步,在 testWidgets 的
# fake-async zone 里 Future 永不解析→hang(flutter#49317/#50783)。一次截一类(同隔离多 toImage 卡 teardown)。
# 类目数变了就同步下面的列表(同 S22「状态即重述」)。
shots:
	@$(RUN) flutter test test/dev/capture_shell.dart
	@for i in 0 1 2 3 4 5 6; do $(RUN) flutter test test/dev/capture_gallery.dart --dart-define=CAT=$$i; done
	@echo "" && echo "✓ 截图落 test/dev/out/(shell.png + gallery_0..6.png)"

# shot-app — 真跑终检截图:构建+启动 gallery .app、截运行中窗口 → test/dev/out/app.png(Impeller 真渲染
# + 红绿灯,headless 还原不了)。BUILD=0 复用已构建 app 跳过重构。详见 test/dev/shot_app.sh。
shot-app:
	@bash test/dev/shot_app.sh

# shot-app-real — 真·端到端:真壳 make app 挂真后端(非 fixture)。起后端 + 经 API 种 workspace/实体
# → flutter run 真 app 挂上它 → 截运行窗口 → test/dev/out/app.png。验证 sidecar 挂载 + 冷启动 +
# rail/详情走真 HTTP/SSE(抓 fixture 路径抓不到的契约漂移)。详见 test/dev/shot_app_real.sh。
shot-app-real:
	@bash test/dev/shot_app_real.sh

.PHONY: help setup gen analyze test verify demo gallery app shots shot-app shot-app-real
