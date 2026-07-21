# ──────────────────────────────────────────────────────────────────
# Anselm 前端（Flutter 桌面端，ADR 0004）— 单词目标，在 frontend/ 下跑。
# 后端 + 仓库级目标在仓库根 Makefile。flutter 由 mise 提供（真·可写官方 SDK）。
#
# 三种启动:  make demo     真 app 形态 + fixture 数据、零后端（看效果）
#            make gallery  组件画廊（UI 套件落地后启用）
#            make app      真 app + 后端 sidecar
# 开发门禁:  setup / gen / analyze / test / verify
# ──────────────────────────────────────────────────────────────────

MISE ?= $(shell command -v mise 2>/dev/null || printf '%s/.local/bin/mise' "$$HOME")
RUN := $(MISE) exec --
DEVICE ?= macos

.DEFAULT_GOAL := help

help:
	@echo "Anselm 前端（Flutter）— 在 frontend/ 下:"
	@echo "  启动:  make app      真 app + 真后端(自动起后端 + 热重载)"
	@echo "         make demo     fixture demo"
	@echo "         make gallery  组件画廊（看每个 An* 全态）"
	@echo "         make perf     profile demo + 帧探针"
	@echo "         默认设备为 macos；其他 Flutter 设备：make <命令> DEVICE=<设备>"
	@echo "  开发:  make setup    确保 Flutter/Dart 依赖已就绪"
	@echo "         make format   写入官方 Dart 格式"
	@echo "         make gen      codegen（dart run slang → i18n strings.g.dart）"
	@echo "         make analyze  flutter analyze（须净）"
	@echo "         make test     flutter test"
	@echo "         make verify   pre-push 门禁（gen + analyze + test）"
	@echo "         make doctor   检查 Flutter / 原生桌面前置条件"
	@echo "  截图:  make shots    无头渲染 shell + 画廊全类 → test/dev/out/*.png"
	@echo "  清理:  make clean    清可重建产物(build/ + .dart_tool/,官方 flutter clean)"

# setup — 拉前端依赖（首次或改 pubspec 后）。package_config 是 Flutter
# 自己的依赖就绪事实；clean 删掉它，后续任意开发命令都会自动补回。
toolchain:
	@test -x "$(MISE)" || $(MAKE) -C .. toolchain

.dart_tool/package_config.json: pubspec.yaml pubspec.lock
	@echo "→ resolving Flutter packages…"
	@$(RUN) flutter pub get
	@echo "✓ frontend dependencies ready"

setup: toolchain .dart_tool/package_config.json

deps: setup

# A native runner is an explicit host concern, not a mysterious downstream
# Xcode/CocoaPods stack trace. Flutter doctor remains the source of truth.
doctor: deps
	@$(RUN) flutter doctor
	@echo "✓ Flutter doctor completed"

# gen — codegen。两套:① slang i18n(dart run slang,自有 runner)② freezed+json(build_runner,
# 范围见 build.yaml:contract+features/data)。产物均入库(deterministic,fresh checkout 直接 analyze);
# 改 i18n json / 契约 DTO 后跑,verify 也会重跑以抓漂移。
gen: deps
	@$(RUN) dart run slang
	@$(RUN) dart run build_runner build --delete-conflicting-outputs

# format — 只使用 Dart 官方 formatter。格式化是纯机械变换；当升级 SDK
# 或首次接入门禁导致全仓 diff 时，完整重排就是正确的基线，不拆成手工挑选。
format: deps
	@$(RUN) dart format lib test
	@echo "✓ frontend formatted"

# analyze — 静态分析（须净）。
analyze: deps
	@$(RUN) flutter analyze

# test — 单测。
test: deps
	@$(RUN) flutter test

# verify — pre-push 门禁:codegen + 分析净 + 单测绿。
verify: deps
	@$(RUN) dart format --output=none --set-exit-if-changed lib test || { \
		echo "✗ Dart files need formatting. Run: make -C frontend format"; exit 1; }
	@echo "→ gen(slang)…"        && $(RUN) dart run slang
	@echo "→ gen(build_runner)…" && $(RUN) dart run build_runner build --delete-conflicting-outputs
	@echo "→ analyze…"           && $(RUN) flutter analyze
	@echo "→ test…"              && $(RUN) flutter test
	@echo "" && echo "✓ verify 全绿（gen + analyze + test）"

# demo — 真 app 形态（骨架阶段:三岛空壳;后续接 fixture 数据）。
# demo — 真 app 壳（AppShell，同 make app）+ 假数据（fixture override、零后端、跳启动门控）。
# 「真 app + 假数据」唯一面:凡接进 AppShell 的 feature 在此自动出现。绝不加 per-feature 入口。
demo: deps
	@LANG=en_US.UTF-8 $(RUN) flutter run -d $(DEVICE) -t lib/dev/demo_main.dart

# perf — demo 的 PROFILE 构建(AOT,接近发行性能)+ 帧探针。**判断性能一律用它**——
# `make demo` 是 debug(JIT+断言,慢 3-5 倍),拿 debug 手感判卡顿全是幻觉(0716 教训:用户报「滚动
# 粘滞」,profile 实测满 120fps 零掉帧)。PERF_HUD=true 装帧探针(stdout 报 build/raster/fps,
# 见 lib/dev/perf_probe.dart)+ 种 STRESS 压力文档;要看探针数字,直接跑二进制而非 open:
#   ./build/macos/Build/Products/Profile/anselm.app/Contents/MacOS/anselm
# --no-tree-shake-icons: 图标按语义键动态路由(AnIcons.byKey 等)静态摇树不掉,profile/release 必带
# (debug 不摇树故 make demo 无感;发行链同此,WRK-043)。
perf: deps
	@LANG=en_US.UTF-8 $(RUN) flutter build macos --profile --no-tree-shake-icons \
		--dart-define=PERF_HUD=true -t lib/dev/demo_main.dart
	@open build/macos/Build/Products/Profile/anselm.app
	@echo "" && echo "✓ profile demo 已启动(帧探针开;数字看法见 Makefile 本目标注释)"

# gallery — 组件画廊（dev/gallery_main.dart）：双栏目录看每个 An* 组件全态（视觉，与 app/demo 正交）。
gallery: deps
	@LANG=en_US.UTF-8 $(RUN) flutter run -d $(DEVICE) -t lib/dev/gallery_main.dart

# app — 真 app 壳（AppShell）+ 真后端,带热重载。自动起后端(make -C backend run,后台常驻)+ dev-attach。
# 生产的"spawn 打包 sidecar"需把签名 Go 二进制打进 .app(发行阶段 WRK-043)。详见 test/dev/run_app.sh。
app: deps
	@MISE="$(MISE)" DEVICE=$(DEVICE) bash test/dev/run_app.sh

# shots — 无头渲染截图(Skia toImage,免 Xcode)→ test/dev/out/*.png 供肉眼/AI 对照 demo 审。
# capture_*.dart 把 toImage/toByteData 包进 tester.runAsync:它们是引擎线程真异步,在 testWidgets 的
# fake-async zone 里 Future 永不解析→hang(flutter#49317/#50783)。一次截一类(同隔离多 toImage 卡 teardown)。
# 类目数变了就同步下面的列表(同 S22「状态即重述」)。
shots: deps
	@$(RUN) flutter test test/dev/capture_shell.dart
	@for i in 0 1 2 3 4 5 6; do $(RUN) flutter test test/dev/capture_gallery.dart --dart-define=CAT=$$i; done
	@echo "" && echo "✓ 截图落 test/dev/out/(shell.png + gallery_0..6.png)"

# clean — 清前端可重建产物。走官方 `flutter clean`(其定义逐字即「Delete the build/ and
# .dart_tool/ directories」)——一并清 build/test_cache(flutter test 内容寻址 kernel 缓存,
# 无 LRU/无大小上限、从不驱逐;dev 天长日久累到数 GB,本机曾实测 6.9GB/99 个 .dill 跨 23 天)
# 与 .dart_tool/flutter_build 增量编译缓存。不手搓 rm——flutter clean 就是官方清理入口(原则 #8)。
# 清后 .dart_tool/package_config.json 一并没了；下次任一前端命令会自动恢复它。
# **刻意不入 verify**:清缓存会逼下轮全量重编、拖慢每次门禁;缓存涨了(du -sh build .dart_tool)手动跑一次。
clean: toolchain
	@$(RUN) flutter clean
	@echo "" && echo "✓ 已清 build/ + .dart_tool/(flutter clean)。下次任一前端命令会自动恢复依赖。"

.PHONY: help toolchain setup deps doctor format gen analyze test verify demo perf gallery app shots clean
