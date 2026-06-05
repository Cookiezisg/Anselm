# Round 0024 — notification 模块新建 + stream 三流 scope 厘清 + R0018 分桶翻转

类型 / 目标：把 SSE 通知从"内存广播"重新设计为**持久化通知中心实体模块**；连带厘清三流 scope 协议、翻转 R0018"资源不分桶"决策。设计经业界调研（MemGPT/Mem0/LangMem/Claude memory tool）+ 多轮讨论敲定。

## 核心方针（一句话）
**通知是实体（DB 持久 + 通知中心 + 实时 SSE），scope=notification:noti_x；workspace 是 Bus 分流轴非 scope；一切 workspace 隔离、~/.forgify 按 workspace 分桶。**

## 关键设计决策（经讨论拍板）
1. **notifications 升格为实体模块**：之前是"内存 replay 环广播"（关机即丢、无通知中心）。重设计为 `Notification{ID,Type,Payload,ReadAt,CreatedAt}` 实体——存 DB（workspace 隔离）、前端通知中心列出/badge/标已读、关机重开仍在。
2. **订阅锚点 vs 事件类型分离**：scope=`notification:noti_x`（锚通知实体）；**workspace 不在 scope**（Bus 从 ctx 分流、前端订阅防多窗口串台）；事件类型在 `node.type`=`<域>.<动作>`（memory.updated）；payload 在 node.content。后端只发 type+payload，**前端自渲文案**。
3. **持久 + 实时双写**：`Emit(type,payload)` = 存 DB（真相）+ best-effort 推 durable signal；推失败只 log，下次 List 兜回。
4. **Emitter 端口**：任何 producer 经 `notification.Emitter.Emit` 发，不碰存储/传输；boot 注入（M7）。
5. **R0018 翻转**：推翻"应用资源不分桶"——一切 workspace 隔离，`~/.forgify/` 按 workspace 分桶（memory/skills/settings/mcp 各 workspace 一份）。

## stream 清理（无历史包袱，零外部牵连）
- scope.go：删 `KindWorkspace`（Bus 分流轴非渲染锚点）+ 加 `KindNotification`；注释讲清 Kind=锚点类型、事件类型在 node.type。
- bridge.go：删 `ListReader`（为"无 DB notifications 内存快照"设计，现 notifications 有 DB）；ErrSeqTooOld 注释改。
- bus.go：`var _ ListReader`→`Bridge`；删 infra/stream/list.go + list_test.go。
- notifications 流此前**无 handler/router 消费**，删除零风险。

## 业界调研（4 并行 agent：MemGPT/Letta · Mem0/LangMem · 产品化 · 学术 2025 综述）
- 简单 ≥ 复杂（LOCOMO：full-context 72.9% > Mem0 66.9%，记忆系统买省 token 非准确率）。
- 原文 > 抽取（summarization drift）。趋势：文件/可见可编辑 > 隐藏 DB。
- 该砍：向量/图/reflection/decay/MemGPT 虚拟内存 paging（单机过度工程）。
- → 指导 memory 下一步重设计为**文件式**；本轮先把通知基础设施做对。

## 新实现
- **domain/notification**：Notification 实体 + Emitter 端口 + Repository + 错误（NOT_FOUND/INVALID_TYPE）。
- **infra/store/notification**：orm + DDL（noti_、workspace 隔离、read_at、unread partial index、无软删）。
- **app/notification**：Service 实现 Emitter（Emit 存 DB + 推 durable signal scope=notification:id）+ List/MarkRead/MarkAllRead/CountUnread；持 stream.Bridge（注入 M7）。
- **handler**：GET /notifications（通知中心分页）+ /unread-count + PUT /{id}/read + POST /read-all + GET /stream（SSE）。

## 测试
app 5（fake repo+fake bridge）：Emit 存+推 scope=notification/durable signal/node.type、空 type 拒、nil bridge 仍持久、推失败仍成功、MarkRead NotFound。stream 测试迁移（KindWorkspace→KindNotification + 删 List 断言）。

## 验证
`gofmt -l` 干净 · `go build ./...` 0 · `go vet ./...` 0 · `go test ./... -race` 全 ok。

## 契约
domains/notification.md 新；database.md +notifications 表 +noti_ 前缀；api.md notifications 1→5 端点；error-codes +NOTIFICATION_* 2；events.md notifications 段重写（scope=notification/持久化/通知中心）；stream scope.go/bridge.go 注释。

## 遗留 / 下一步
- **memory（M1.7，下一步）**：文件式重设计（~/.forgify/workspaces/<wsID>/memories/*.md），发通知 = 调 notification.Emitter。
- Emitter 注入各 producer + notification app 注入 notifications Bridge + SSE 装配 → M7。
- scope-relation EntityKind 收口（实体 kind 词表归一）→ 单独评估。
- R0018 分桶布局落地（~/.forgify/workspaces/<wsID>/）→ M7。
