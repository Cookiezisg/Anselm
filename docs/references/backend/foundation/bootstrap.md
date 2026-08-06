---
id: DOC-034
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Bootstrap

## 1. 定位

`internal/bootstrap` 是 composition root，也是唯一横跨全部 app/infra 的 package。
`cmd/server` 只负责配置、Serve 与信号。

Build 顺序：

```text
settings + logger + crypto + SQLite/migrations
→ stores and infra singletons
→ app services by dependency tier
→ narrow adapters and post-injection
→ tool registries
→ HTTP handlers/router
→ App lifecycle
```

循环依赖通过后注入与窄接口拆开。Subagent 需要最终 Toolset，而 Toolset 又包含
Subagent tool 时，使用 holder 延迟读取，不让 package graph 成环。

## 2. Settings 与基础设施

`<dataDir>/settings.json` 统一保存 limits、network、retention。缺文件使用默认；
坏文件使 Boot 失败。写任一 section 时三段整体持久化，不能丢掉其它配置。

- Limits 是热读 provider；
- Network 在 Boot/Patch 应用 proxy env，已有 transport 完整生效可能需重启；
- Retention 每轮现读，0 表示永久保留；Patch 触发一次非阻塞即时 sweep。

Logger 同时写 stderr 与轮转 JSON 文件。Encryptor 使用显式 fingerprint，缺席时
读取机器 fingerprint，再以 data dir 派生本地 fallback。

SQLite migrations 先建/加列，再执行需要真实表存在的 CHECK rebuild。

## 3. Boot

主要顺序：

1. Sandbox bootstrap，失败进入 degraded；
2. 回收 Sandbox 与 background shell 的 crash orphan process groups；
3. 启动 Trigger、Search 与 Scheduler Advance worker pool；
4. Scheduler 把 running Flowruns 入队恢复；
5. 对每个 workspace 播种 context 后执行：
   - Handler/MCP best-effort warm-up；
   - managed free-tier ensure；
   - Chat non-terminal orphan sweep；
   - Attachment blob 与 Media artifact orphan sweep；
   - Workflow active listener reattach；
   - Trigger misfire sweep。
6. 全部 workspace 的 GC 完成后启动 Media worker；
7. 启动 firing drain、approval timeout、misfire 与 retention loops。

Misfire 必须在 Workflow reattach 后，因为 listener registry 决定哪些 workflow
应入账。Blob sweep 只在 Boot 做，避免与 `blob.Put → attachment row Create`
上传窗口竞态。

Search worker 可在 workspace list 为空时启动；Media worker 必须等 Boot GC 完成，但两者都由
后续变更驱动。新 Workspace 通过 OnCreated hook best-effort provision managed default。

## 4. Background workspace

`forEachWorkspace(parentCtx,fn)` 在 parent context 上为每个 workspace 派生
seeded context。这样：

- ORM 查询始终隔离；
- caller 的 cancel/Shutdown 继续传播；
- 长 retention batch 可在批间退出。

Boot 可传 Background，因为 Boot 本身尚无 shutdown loop；常驻 goroutine 必须传
自己的可取消 context，不能无条件 Detached。

Retention loop 由 ticker 与 buffered kick 驱动。真实删除 terminal runs 后，
全局调用一次 SQLite free-page reclaim。

## 5. Shutdown

Serve 先取消 base request context，使常驻 SSE 断开，再执行 HTTP Shutdown。
App Shutdown：

1. 同时 stop 各 ticker/loop，再等待 done；
2. 给 Scheduler pool 有界排空时间，再 cancel in-flight Advance 并停池；
3. 停 Trigger 与 Chat queues；Chat 接收剩余关停预算，running turn 被取消，自动标题等可选
   后台任务收到 chat lifecycle cancel 且不得在 DB close 后写入；
4. 停 Search worker；
5. 关闭 MCP/Handler resident instances；
6. 停 Media worker；
7. Sandbox 收割 long-lived/one-shot；
8. Shell manager 收割 background process groups；
9. flush logger；
10. checkpoint/close DB。

各步 best-effort，但依赖顺序保证后台 DB writer 在 DB close 前退出。整个流程受
桌面宿主 SIGTERM grace 约束；超时会被升级为强杀，因此每个 wait 都必须有界。

## 6. 契约

App Config 包含 data dir、listen address、fingerprint 与 dev mode。Background
context、retention wiring 与 shutdown budget 由 bootstrap tests 守卫。

Durable 执行恢复见 [`scheduler-flowrun.md`](scheduler-flowrun.md)，SQLite
细节见 [`platform-pkgs.md`](platform-pkgs.md)。
