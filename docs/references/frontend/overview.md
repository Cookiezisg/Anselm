---
id: DOC-047
type: reference
status: active
owner: @weilin
created: 2026-06-30
reviewed: 2026-06-30
review-due: 2026-09-28
audience: [human, ai]
---

# 前端鸟瞰 —— 第 0 篇(读完就懂,无需翻代码)

> 这是前端的「读我先读」。想快速建立心智模型看本篇;**文件住哪 / 路由 / 装配**看 [`architecture.md`](architecture.md);**原语目录 / 设计令牌**看 [`design-system.md`](design-system.md);**后端线缆的 Dart 投影**看 [`contract.md`](contract.md);**怎么协作 + 进展 + 路线**看 [`working/frontend/README.md`](../../working/frontend/README.md);**工程纪律(binding)**看 [`CLAUDE.md`](../../../CLAUDE.md)。

## 1. 一句话

Anselm 是**本地优先的 agentic workflow 平台**——一个 **Flutter 桌面 app**,内嵌一个 **Go 后端作 sidecar**(单进程、单用户、SQLite 落盘,**不做 SaaS**)。**前端 = 这个 Go 二进制的纯客户端**:它不持有业务规则,所有用例都在后端;前端只负责经 localhost HTTP+SSE 把后端的状态**渲染成通透轻盈的桌面体验**,并把用户意图发回去。

## 2. 心智模型:三岛壳 + 海洋 + sidecar + 三条流

整个 app 是一个壳 **`AnShell`**,横向分**三岛**;中心岛随「当前海洋」换内容。

```
┌─ AnShell ───────────────────────────────────────────────────────────┐
│ ┌──────────────┐ ┌────────────────────────┐ ┌────────────────────┐ │
│ │ 左岛(可拖收) │ │  中心:海洋 Ocean        │ │ 右岛:Inspector     │ │
│ │              │ │  (当前海洋的主舞台)     │ │ (按需揭示,选中才开)│ │
│ │ ◹ 海洋切换器 │ │                        │ │                    │ │
│ │ ▤ 当前海洋的 │ │  chat → 对话正文        │ │ run 终端 /         │ │
│ │   rail(列表) │ │  entities → 实体详情    │ │ entity-workspace / │ │
│ │ ⚙ 底栏       │ │  scheduler/documents…  │ │ …(随海洋而定)      │ │
│ │ (workspace/  │ │                        │ │                    │ │
│ │  设置/通知)  │ │  + 浮层头(面包屑随滚动) │ │ 滑入/滑出、不重排  │ │
│ └──────────────┘ └────────────────────────┘ └────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
        ⌘B 收/开左岛                                  ⌘\ 收/开右岛
```

- **四海洋**:`chat`(对话)· `entities`(实体:Function/Handler/Agent/Workflow)· `scheduler`(调度)· `documents`(文档),外加齿轮进的 `settings`。左岛顶部 `AnOceanSwitcher` 切换(matched-geometry 滑动药丸)。**`chat`/`entities`/`documents` 三海洋已完整建成(rail + 中心);`scheduler` 占位「即将推出」**。海洋切换暂走 provider(`selectedOceanProvider`),未路由化;**首次启动落 `chat` 初始页,此后恢复上次选中的海洋(shared_preferences 持久化键 `fy.ocean`)**。
- **左岛两条独立轴**:① `selectedOceanProvider`(选哪个海洋,驱动 rail + 中心)② `notificationsOpenProvider`(铃 toggle,接管左岛中段、不动中心)。
- **`AnShell` 自身 Riverpod-free**:状态由 app 层以 props 喂入;壳只管布局/揭示动效/红绿灯对齐。

## 3. 分层:`core → features → app`(feature-first 3-tier)

```
core/       跨切共享(不依赖上层):contract(DTO)· net(HTTP)· sse(三流网关)· process(sidecar 监督)
            · runtime(DI 装配)· perf(每帧合并器)· error(错误边界)· design(token)· ui(An* 原语 + 壳)
            · model/messages(框架无关纯模型:BlockTreeReducer / status)· overlay(命令式 toast/dialog)
features/   各域自管 data + state + ui(+ 纯 model);feature 之间互不依赖,跨片走 core provider / 导航 intent
app/        装配根 + 唯一壳 app_shell.dart + 路由 + 启动门控
```

- **无 use-case / domain 层**——Go 二进制即用例,DTO 都是后端投影,客户端零业务规则。
- **唯一框架无关纯模型层**:`BlockTreeReducer`(把 SSE 帧折成嵌套块树,run 终端 + chat 共用)/ `GraphModel`——脱 widget/socket 单测。
- 详细文件图见 [`architecture.md`](architecture.md) §2。

## 4. 状态 + 实时:Riverpod 托管 server-state + 三条常驻流

- **Riverpod**(经典 provider 写法,**非 codegen**——此 SDK + freezed 3 太新,生态没跟上,见 [`ADR 0004`](../../decisions/0004-frontend-flutter-architecture.md))。server-state 用 `AsyncNotifier`(分页 `loadMore`)。
- **三条 SSE 流,永不再加**:`messages` / `entities` / `notifications`,启动即常驻全连(`keepAlive`)。三流 **workspace 级、后端不过滤**——前端经 `SseGateway` 的 plain-Dart `Map<Scope,Stream>` **demux 自滤**(不在 Riverpod 里逐帧 `.where`)。
- **铁律:DB 行是真相、流只为实时**。帧带 `seq`:`seq>0` 才 durable(改耐久缓存 + 推进续传游标);`seq=0` ephemeral(delta/tick,只改瞬时视图态、不进缓存)。重连断线 → REST 重取再续。
- 流式渲染**绝不整页重绘**:靠 L0–L6 分层(网关 demux / ephemeral 分流 / 每帧合并器 / family provider / `.select` slice / 叶子 Consumer+RepaintBoundary / `ListView.builder` 虚拟化)。原语 L0–L2 在 `core/` 已建,叶子写法在 feature 落地。

## 5. 进程模型:Go sidecar + loopback 安全

- Go 后端作 **sidecar**:Dart 抢一个临时端口 → 经 `ANSELM_ADDR` 拉起后端 → `/api/v1/health` 门控就绪才显壳。dev 时用 `ANSELM_BACKEND_URL` 挂已跑的后端(`make -C backend run`),零后端改。
- **loopback 三把锁**(在后端):默认绑 `127.0.0.1` + `RequireBearerToken`(`ANSELM_AUTH_TOKEN`)+ `RequireLoopbackHost`(防 DNS rebinding)。
- **DIP 注入**:**workspace**(唯一鉴权轴,header `X-Anselm-Workspace-ID`)+ **baseUrl** 由 `app` 经 `ProviderScope` override 注入;401/410 在 net 层拦截。

## 6. 视觉灵魂

明亮、通透、轻盈。`Tokens.rowHeight = 32` 紧凑;**字体只两档字重**(正文 w300 / 加粗 w400,**禁 w500/w600**,层级靠字号+颜色)。颜色/度量全走 design token,**禁内联硬编码**。**一切视觉由原语组装**(gallery-first,见 §7)。`tool_call` / `reasoning` 默认折叠。度量/色值的事实源是 [`design-system.md`](design-system.md)。

## 7. 怎么造的(一句话,详见协作规范)

**原语先行、禁手搓**:任何视觉先在 gallery 里有 `An*` 原语(`make gallery` 看目录),app/demo 只组装、不手搓。**调研先行**:对接后端前先扇出读后端 + `references/backend`,再联网查 best-practice。完整建造流水线 + 进展 + 路线见 [`working/frontend/README.md`](../../working/frontend/README.md)。

## 8. 三个启动面(永不增 per-feature 入口)

| 命令 | 是什么 |
|---|---|
| `make gallery` | 组件视觉目录(每个 `An*` 原语全态) |
| `make app` | 真壳 + 真后端 sidecar(`AppShell` + Live repository + 启动门控) |
| `make demo` | 真壳 + 假数据零后端(`AppShell` + fixture override + 跳门控) |

`make app` 与 `make demo` **共用唯一壳 `app/app_shell.dart`**,只差①数据源②启动门控。新 feature 接进 `AppShell` 一次、app+demo 同时拥有。
