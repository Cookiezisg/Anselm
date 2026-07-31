---
id: DOC-044
type: reference
status: active
owner: @weilin
created: 2026-06-22
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# 前端架构——Flutter 桌面端的当前物理结构

> 本篇只回答代码住哪、怎样装配、路由与依赖如何约束。产品鸟瞰见 [`overview.md`](overview.md)，原语见 [`design-system.md`](design-system.md)，Dart 契约见 [`contract.md`](contract.md)，桌面宿主见 [`platform.md`](platform.md)，架构裁决见 [`ADR 0004`](../../decisions/0004-frontend-flutter-architecture.md)。

## 1. 一句话

Flutter 桌面端是 Go sidecar 的纯客户端，采用 `core ← features ← app` 的 feature-first 三层结构。业务规则和 durable 真相留在后端；前端负责契约投影、实时状态、桌面交互与视觉表达，不另建客户端 use-case/domain 层。

## 2. 物理地图

```text
frontend/lib/
├── main.dart                 # 生产入口、窗口初始化、ProviderScope
├── app/
│   ├── app.dart              # MaterialApp.router 与全局 gate
│   ├── router.dart           # URL 是产品选区唯一事实
│   ├── app_shell.dart        # app/demo 共用的唯一三岛壳
│   ├── app_startup_gate.dart # sidecar 就绪门
│   └── workspace_gate.dart   # workspace 创建/激活门
├── core/
│   ├── contract/             # Go DTO 的 Dart 投影
│   ├── net/ + sse/           # HTTP 边界与三条 workspace SSE
│   ├── process/              # sidecar 生命周期
│   ├── design/ + ui/         # token 与 An* 原语
│   ├── media/ + editor/      # 跨 feature 媒体和原生编辑器
│   ├── graph/ + run/         # 框架无关图/运行纯模型
│   ├── router/ + shell/      # 导航意图与壳状态
│   └── platform/、settings/、workspace/、notice/ 等共享能力
├── features/
│   ├── chat/
│   ├── entities/
│   ├── library/
│   ├── notifications/
│   ├── scheduler/
│   └── settings/
├── dev/                      # gallery/demo/onboarding 等开发入口
└── i18n/                     # slang 源文案与生成物
```

每个业务 feature 自有 `data/`、`state/`、`ui/`，需要时再有纯 `model/`。`Live*Repository` 接真实 HTTP/SSE，`Fixture*Repository` 驱动 demo 与测试；repository 是 feature 的唯一数据缝。

## 3. 依赖纪律

```text
app  →  features  →  core
```

- `core` 不依赖 feature 或 app。
- feature 之间不直接 import；跨域协作通过 core 契约、provider、媒体能力或导航意图。
- `app` 只做依赖注入、路由、gate 和唯一壳装配，不承载业务规则。
- widget 不直接拼 HTTP/SSE；网络只经 repository 与 `ApiClient`/`SseGateway`。
- UI 值只来自 `core/design` 与 `core/ui`，不在业务 widget 散落颜色、尺寸和动效常量。

## 4. 路由与壳身份

| 位置 | 当前含义 |
|---|---|
| `/`、`/entities` | Entities 总览 |
| `/entities/graph` | 全屏关系图 |
| `/entities/:kind/:id` | 实体详情 |
| `/entities/workflow/:id/editor` | 全屏 workflow 图编辑器 |
| `/chat/:id` | 对话线程；无选中时 Chat 显示 landing |
| `/library/:id` | document page |
| `/library/skill/:name` | skill page |
| `/scheduler` | Scheduler Overview |
| `/scheduler/w/:id` | workflow 运营页 |
| `/scheduler/w/:id/runs/:frId` | run 卷宗 |
| `/scheduler/runs/:frId` | 按 run id 解析父 workflow 后中继 |

除关系图和 workflow 编辑器两个全屏页外，业务位置都返回同一个常量 page key 的 `AppShell`。因此 URL 切换只改变 rail/ocean/inspector 的投影，不重挂三岛壳。当前选区必须单向派生自路由；provider 不维护第二份可漂移的选择状态。

## 5. 数据、实时与恢复

- `ApiClient` 统一注入 base URL、workspace、loopback bearer 与标准错误 envelope。
- 全系统只有 `messages`、`entities`、`notifications` 三条 workspace 级 SSE；`SseGateway` 在 plain Dart 层按 scope/kind 分发。
- REST/数据库行是 durable 真相。`seq>0` 推进续传水位；`seq=0` 的 delta、tick、interaction 只更新瞬时视图。
- 断线或 410 后，消费方重取相应 REST 真相再续流；依赖某条 lifecycle signal 的 provider 同时订阅该流的 resync。
- workspace 热切换先离开旧深链，再切 workspace 轴，使 repository、HTTP 与 SSE 一起换代，避免旧 id 在新 workspace 下重取。
- 流式高频面只重建活动叶；settled 子树保持 identity，并以 sliver、缓存、coalescing 与 `RepaintBoundary` 控制成本。

## 6. 装配与运行面

`app/app_shell.dart` 是产品壳的唯一组合点。生产 app 与 demo 使用同一壳和同一 feature widget，只在数据源与启动门控上不同。

| 命令 | 形态 |
|---|---|
| `make -C frontend gallery` | `An*` 原语与状态目录 |
| `make -C frontend demo` | 真壳 + fixture repository，零后端 |
| `make -C frontend onboard` | 首次 workspace 创建到真壳的旅程 |
| `make -C frontend app` | 真壳 + live repository + Go sidecar |

不得新增 per-feature app 入口来复制壳。新 feature 接入 `AppShell` 一次，生产、demo 与壳级测试同时获得它。

## 7. 门禁

- `make -C frontend quick`：按 diff 选择的开发内环。
- `make -C frontend verify`：codegen、analyze 与分组测试的完整前端门禁。
- `make -C frontend shots`：无头截图回归。
- `make doctor`：仓库级桌面工具链诊断。

前端事实变化必须在同一提交更新对应 reference；建造过程与已完成 iteration 进入 `docs/archive/`，不得继续污染当前架构篇。
