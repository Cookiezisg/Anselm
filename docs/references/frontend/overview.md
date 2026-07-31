---
id: DOC-047
type: reference
status: active
owner: @weilin
created: 2026-06-30
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# 前端鸟瞰——第 0 篇

> 先读本篇建立心智模型；物理结构见 [`architecture.md`](architecture.md)，原语见 [`design-system.md`](design-system.md)，Dart 线缆见 [`contract.md`](contract.md)，平台能力见 [`platform.md`](platform.md)，各产品面见 [`features/`](features/)。

## 1. 一句话

Flutter 桌面端是 Go sidecar 的纯客户端：后端持有业务规则和 durable 真相，前端通过 loopback HTTP + 三条 SSE 把它们变成可操作、可解释的本地产品体验。

## 2. 产品骨架

```text
AppShell
├── 左岛：海洋切换 + 当前 rail + workspace/settings/notifications
├── 中心：chat | entities | library | scheduler | settings
├── 右岛：按当前海洋与真实选区揭示的 inspector
└── 顶带：全 app 唯一即时消息舞台
```

| 海洋 | 当前入口 | 当前形态 |
|---|---|---|
| Chat | 无选中 landing；线程 `/chat/:id` | 对话、附件、多模态、工具、人在环、驻地、队列、分叉/重试/版本、侧幕 |
| Entities | `/`、`/entities/:kind/:id` | 总览、Quadrinity 与支撑实体、版本、执行调试台、workflow 图编辑器 |
| Library | 无选中草稿；`/library/:id`、`/library/skill/:name` | Documents/Skills 树、原生编辑器、属性/大纲/反链 |
| Scheduler | `/scheduler`、workflow 与 run 子路由 | Overview、运营页、运行卷宗与节点 inspector |
| Settings | 壳内 settings 选区 | 13 面板、机器/工作区两轴、密钥/模型/MCP/存储/网络/快捷键 |

## 3. 分层与依赖

```text
core  ←  features  ←  app
```

- `core/`：contract、HTTP、SSE、process、router、design/UI、media、editor、graph/run 纯模型、平台适配。
- `features/<域>/`：各自拥有 data + state + ui；feature 之间不直接依赖。
- `app/`：DI、路由、启动门控与唯一 `AppShell`。
- 无客户端 use-case/domain 层；Go sidecar 即用例层。跨 feature 协作只经 core provider、契约或导航意图。

## 4. 状态与实时

- Riverpod 托管 server-state；分页集合用 notifier 显式 `loadMore`。
- 全系统只有 `messages`、`entities`、`notifications` 三条 workspace 级 SSE。`SseGateway` 在 plain Dart 层按 scope demux。
- DB 行是真相：`seq>0` 的 durable 帧推进续传水位；`seq=0` 的 delta/tick/interaction 只进入瞬时视图。
- 断线或 410 后先重取 REST，再续流；interaction 等 ephemeral 状态必须通过专用 REST 补拉。
- 流式面只重建活动叶；settled 内容保持 identity，并以 `RepaintBoundary`、缓存和懒 sliver 控制成本。

## 5. 三个运行面

| 命令 | 形态 |
|---|---|
| `make -C frontend gallery` | 原语与状态目录 |
| `make -C frontend demo` | 真壳 + fixture repository，零后端 |
| `make -C frontend app` | 真壳 + Go sidecar + live repository |

app 与 demo 共用唯一 `app/app_shell.dart`，只替换数据源与启动门控。当前协作流程和工程纪律只在 [`CLAUDE.md`](../../../CLAUDE.md) 维护，不再另设前端 working hub。
