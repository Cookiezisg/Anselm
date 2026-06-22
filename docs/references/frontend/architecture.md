---
id: DOC-044
type: reference
status: active
owner: @weilin
created: 2026-06-22
reviewed: 2026-06-22
review-due: 2026-09-22
audience: [human, ai]
---

# 前端架构 —— Flutter 桌面端的物理结构

> 本篇是前端的**第 0 篇**:整体怎么分层、文件住哪、纪律是什么。决策依据见 [`ADR 0004`](../../decisions/0004-frontend-flutter-architecture.md);设计语言见 [design-system](design-system.md);契约见 [contract](contract.md);SSE 见 [sse-gateway](sse-gateway.md);三岛壳见 [shell](shell.md)。

## 1. 一句话

Go 后端作 **sidecar**,Flutter 桌面端是其纯客户端(localhost HTTP+SSE)。**3-tier feature-first**:`core`(跨切共享)→ `features`(各域)→ `app`(装配根 + shell)。**无 use-case/domain 层**——Go 二进制即用例,DTO 都是后端投影。

## 2. 物理结构(`frontend/lib/`)

```
main.dart                  # 入口:窗口 init → 拉 sidecar → ProviderScope
app/                       # 装配根
  app.dart                 # 根 widget(sidecar 生命周期门控)
  backend_controller.dart  # sidecar 进程:抢端口 → ANSELM_ADDR 拉起 → /health 门控
  providers.dart           # DI 根(baseUrl / workspace / dio / sse 经 override 注入)
  router.dart              # go_router
  shell/app_shell.dart     # 三岛 shell 装配(用 core/ui 的 AnShell)
core/                      # 跨切共享层(无 feature 依赖)
  contract/                # 全部后端投影 DTO + envelope/page/error(见 contract.md)
  net/                     # dio 客户端(envelope 拆封 / 分页 / 错误 typed)
  sse/                     # SSE gateway(见 sse-gateway.md)
  platform/                # OS 缝:host_platform(dart:io 收口)+ window_chrome(红绿灯对齐通道)
  design/                  # tokens/colors/typography/syntax/theme(见 design-system.md)
  ui/                      # An* 组件套件 + icons(Lucide)+ 单一 barrel ui.dart
features/                  # ★中间层:每域 data+state+ui+model(见 features/README.md)
i18n/                      # slang(en/zh .i18n.json + 生成的 strings*.g.dart)
```
**dev 工具**(源码入库,非产品路径):`lib/dev/`(`demo_main`=真 shell+fixture · `gallery_main`+`gallery_page`=组件画廊);截图夹具 `test/dev/capture_gallery.dart`;其产物 `test/dev/out/` **gitignore、不入库**。

## 3. 依赖规则(三层)

`app → features → core`,单向。**features 互不依赖**(跨片走 core provider / 导航 intent)。`core` 不依赖上层。UI 只用 `core/ui` + `core/design` 组合,**禁内联配色/度量**。详见 [`features/README.md`](../../../frontend/lib/features/README.md)。

## 4. 状态 + DI

Riverpod 托管 server-state(`AsyncNotifier` 分页)+ 三条 `keepAlive` SSE 流。装配根 = `app/app.dart` 的 `ProviderScope`;运行期发现的 baseUrl + 选定 workspace 经 `overrides` 注入(镜像后端"唯一全知者"为 scope override)。

## 5. 工具链与门禁

- 工具链 = **mise**(go + flutter)。
- codegen:**build_runner**(freezed/json_serializable)+ **slang CLI**(`dart run slang`,i18n)——产物入库(deterministic)。
- 门禁 = `frontend/Makefile` 的 `make verify`(在 `frontend/` 下跑):`gen + analyze 净 + test 绿`。
- **三种启动**(单词目标):`make demo`(真 app 形态 + fixture、零后端,看效果)· `make gallery`(组件画廊)· `make app`(真 app + 后端 sidecar)。demo 与 app 共用 `app/shell/app_shell.dart`,差别只在数据源(fixture vs 后端)+ 是否起 sidecar。开发门禁目标:`setup/gen/analyze/test/verify`。
- 后端 + 仓库级目标在仓库根 `Makefile`(`server/verify/docs/testend/…`)。

## 6. 文档纪律(延伸到前端)

改后端字段 → **同提交**改 `core/contract` 的 DTO + 本 `references/frontend/` 对应篇(同后端 doc-sync 铁律,CLAUDE.md)。每个 feature 落地附 `references/frontend/slices/<域>.md` + 端到端旅程测试。
