---
id: DOC-118
type: reference
status: active
owner: @weilin
created: 2026-06-05
reviewed: 2026-06-05
review-due: 2026-09-01
audience: [human, ai]
---
# Notification Domain — 通知中心（持久化事件 + 实时推送）

> **核心地位**：Notification 是用户**通知中心**的后端——一份持久化、按 workspace 的事件日志。任何模块经 `Emitter` 端口发一条通知，它**存 DB**（前端通知中心列出、badge 计数、关机重开仍在）**并**在 notifications SSE 流推一条实时 signal。后端只给 `type + payload`，**人类文案由前端渲染**。

---

## 1. 物理模型
```go
type Notification struct {
    ID          string         `db:"id,pk"`              // noti_<16hex>
    WorkspaceID string         `db:"workspace_id,ws"`
    Type        string         `db:"type"`               // 事件类型 <域>.<动作>，如 memory.updated
    Payload     map[string]any `db:"payload,json"`       // producer 定义、前端渲染
    ReadAt      *time.Time     `db:"read_at"`            // nil = 未读
    CreatedAt   time.Time      `db:"created_at,created"`
}
```
- **workspace 隔离**（orm 自动）；**无软删**（只增；自动清理是延后特性）。
- 索引：`(workspace_id, created_at DESC)` 撑通知中心列表；partial `WHERE read_at IS NULL` 撑 badge 计数。

## 2. 核心原理

### 2.1 持久 + 实时双写
`Emit(type, payload)`：① 存 DB（真相源）② best-effort 在 notifications SSE 流推一条 **durable signal**。SSE 推失败只 log——通知已落库，前端下次 `List` 兜回。**关机重开后通知中心仍在**（不同于只兜短时重连的 SSE replay 环）。

### 2.2 与 SSE 流的关系（见 events.md）
推送形态：
```
scope = { kind: "notification", id: "noti_x" }   // 锚到这条通知实体
frame = signal (durable)
node  = { type: "memory.updated", content: {…payload} }
```
- **workspace 不在 scope**——它是 Bus 从 ctx 取的分流轴（前端按当前 workspace 订阅，防多窗口串台），不是渲染锚点。
- **事件类型在 `node.type`**（`<域>.<动作>`），payload 在 `node.content`。

### 2.3 后端不拼文案
后端只发 `type + payload`，**前端按 type 自渲染**人类可读文案（不把渲染逻辑塞进后端，利于 i18n）。

## 3. 端点（通知中心）
| 端点 | 作用 |
|---|---|
| `GET /api/v1/notifications` | 通知中心列表（最新优先，keyset 分页） |
| `GET /api/v1/notifications/unread-count` | badge 未读数 |
| `PUT /api/v1/notifications/{id}/read` | 标记一条已读 |
| `POST /api/v1/notifications/read-all` | 全部已读 |
| `GET /api/v1/notifications/stream` | SSE 实时订阅（Last-Event-ID 续传） |

## 4. 跨域集成
- **任何模块**（memory / sandbox / …）经 `Emitter.Emit(type, payload)` 发通知——producer 不碰存储/传输。
- **boot 装配（M7）**：notification app 注入 notifications stream `Bridge`（推 SSE）；各 producer 注入 `Emitter`。

## 5. 错误
| Sentinel | Wire Code | HTTP | 场景 |
|---|---|---|---|
| `ErrNotFound` | `NOTIFICATION_NOT_FOUND` | 404 | MarkRead 未知 id |
| `ErrInvalidType` | `NOTIFICATION_INVALID_TYPE` | 400 | Emit 空 type |
