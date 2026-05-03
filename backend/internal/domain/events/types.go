// Package events defines the typed payloads streamed over the in-process
// Bridge and out to clients via SSE. The model is **entity-state**: each
// event carries the full current snapshot of one domain entity, in the
// same shape returned by the corresponding REST GET endpoint. Subscribers
// render purely by replacing their local copy keyed on the entity's ID.
//
// Three event types, one per user-facing domain:
//
//   - ChatMessage    — a Message changed (token streamed, tool call started,
//     tool result arrived, status updated, error). Payload = full Message.
//   - Forge          — a Forge changed (CRUD, pending lifecycle, mid-tool
//     code streaming during create_forge / edit_forge). Payload = full Forge.
//   - Conversation   — a Conversation changed (auto-title, archive, etc.).
//     Payload = full Conversation.
//
// Naming: snake_case, dot-separated. e.g. "chat.message", "forge",
// "conversation".
//
// Package events 定义流过进程内 Bridge 并通过 SSE 推到客户端的类型化载荷。
// 模型是 **entity-state**：每个事件携带某个 domain entity 的完整当前快照，
// 形状与对应的 REST GET 端点返回一致。订阅方按 entity ID 替换本地拷贝即可渲染。
//
// 三种事件，每个用户可见 domain 一种：
//
//   - ChatMessage    — Message 发生变化（token 流入、tool call 出现、
//     tool result 返回、状态更新、error）。载荷 = 完整 Message。
//   - Forge          — Forge 发生变化（CRUD、pending 生命周期、create_forge /
//     edit_forge 期间内嵌 LLM 代码逐 token 流入）。载荷 = 完整 Forge。
//   - Conversation   — Conversation 发生变化（auto-title、归档等）。
//     载荷 = 完整 Conversation。
//
// 命名：snake_case，按 domain 加点号前缀。如 "chat.message"、"forge"、
// "conversation"。
package events

import (
	"encoding/json"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	convdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	forgedomain "github.com/sunweilin/forgify/backend/internal/domain/forge"
	taskdomain "github.com/sunweilin/forgify/backend/internal/domain/task"
)

// Event is any typed message flowing through a Bridge. Implementations
// must marshal to the same JSON shape as the corresponding REST GET response.
//
// Event 是在 Bridge 中流动的类型化消息。实现必须 marshal 出与对应
// REST GET 响应一致的 JSON 形状。
type Event interface {
	EventName() string
}

// ── ChatMessage ───────────────────────────────────────────────────────────────

// ChatMessage carries a full Message snapshot. Fired at message-level
// milestones — never per-byte inside tool execution.
//
// Trigger points:
//   - Initial publish when the assistant message slot opens
//   - Each LLM text / reasoning token (text block grows)
//   - When a tool call is first identified (tool_call block appears with name only)
//   - When tool call args are complete
//   - When a tool result returns (tool_result block added)
//   - On final write (status = completed | cancelled | error)
//
// JSON shape: identical to GET /api/v1/messages/{id} — the embedded
// *chatdomain.Message marshals at top level (no wrapper key).
//
// ChatMessage 携带完整 Message 快照。在 message 级关键时刻触发——绝不在
// tool 执行内部逐字节推送。
//
// 触发点：
//   - assistant message 槽位创建时初始发布
//   - 每个 LLM text / reasoning token（text block 生长）
//   - tool call 首次被识别时（tool_call block 仅有 name）
//   - tool call args 完整时
//   - tool result 返回时（tool_result block 加入）
//   - 最终写入（status = completed | cancelled | error）
//
// JSON 形状：与 GET /api/v1/messages/{id} 一致——嵌入的 *chatdomain.Message
// 字段直接出现在顶层（无 wrapper key）。
type ChatMessage struct {
	*chatdomain.Message
}

// EventName returns "chat.message".
// EventName 返回 "chat.message"。
func (ChatMessage) EventName() string { return "chat.message" }

// MarshalJSON delegates to the embedded *chatdomain.Message so the wire
// shape exactly matches GET /api/v1/messages/{id}. A nil Message produces
// JSON null.
//
// MarshalJSON 委托给嵌入的 *chatdomain.Message，让 wire 形状与
// GET /api/v1/messages/{id} 严格一致。Message 为 nil 时输出 JSON null。
func (e ChatMessage) MarshalJSON() ([]byte, error) {
	if e.Message == nil {
		return []byte("null"), nil
	}
	return json.Marshal(e.Message)
}

// ── Forge ─────────────────────────────────────────────────────────────────────

// Forge carries a full Forge snapshot, including the .Pending field when a
// pending change exists. Fired on every change to a Forge entity, including
// per-token updates while create_forge / edit_forge stream code into the
// entity (or its pending). For create_forge the tool pre-saves a stub Forge
// up front so that streaming snapshots always carry a real, persisted entity.
//
// JSON shape: identical to GET /api/v1/forges/{id}.
//
// Forge 携带完整 Forge 快照，含 .Pending 字段（如有 pending 变更）。Forge entity
// 任何变化都会触发，包括 create_forge / edit_forge 期间逐 token 流入主代码或
// pending 代码。create_forge 进入时会预存 stub Forge，使流式快照始终承载真实落库的
// entity。
//
// JSON 形状：与 GET /api/v1/forges/{id} 一致。
type Forge struct {
	*forgedomain.Forge
}

// EventName returns "forge".
// EventName 返回 "forge"。
func (Forge) EventName() string { return "forge" }

// MarshalJSON delegates to the embedded *forgedomain.Forge.
// MarshalJSON 委托给嵌入的 *forgedomain.Forge。
func (e Forge) MarshalJSON() ([]byte, error) {
	if e.Forge == nil {
		return []byte("null"), nil
	}
	return json.Marshal(e.Forge)
}

// ── Conversation ──────────────────────────────────────────────────────────────

// Conversation carries a full Conversation snapshot. Fired on every change
// (auto-title, archive, system prompt update, etc.).
//
// JSON shape: identical to GET /api/v1/conversations/{id}.
//
// Conversation 携带完整 Conversation 快照。任何变化（auto-title、归档、系统
// prompt 更新等）都会触发。
//
// JSON 形状：与 GET /api/v1/conversations/{id} 一致。
type Conversation struct {
	*convdomain.Conversation
}

// EventName returns "conversation".
// EventName 返回 "conversation"。
func (Conversation) EventName() string { return "conversation" }

// MarshalJSON delegates to the embedded *convdomain.Conversation.
// MarshalJSON 委托给嵌入的 *convdomain.Conversation。
func (e Conversation) MarshalJSON() ([]byte, error) {
	if e.Conversation == nil {
		return []byte("null"), nil
	}
	return json.Marshal(e.Conversation)
}

// ── Task ──────────────────────────────────────────────────────────────────────

// Task carries a full Task snapshot. Fired on Create / Update /
// SoftDelete by the app/task.Service so the LLM (and any UI subscribed
// to chat SSE) sees task-list state changes in near real time.
//
// JSON shape: identical to GET /api/v1/tasks/{id} (when that REST
// endpoint exists; v1 only exposes the SSE event because the LLM tool
// calls are the primary interface).
//
// Task 携带完整 Task 快照。app/task.Service 在 Create / Update /
// SoftDelete 时触发，让 LLM（与订阅 chat SSE 的 UI）近实时看到任务列表
// 变化。
//
// JSON 形状：与 GET /api/v1/tasks/{id} 一致（v1 仅出 SSE 事件——LLM 工具
// 调用是主要接口）。
type Task struct {
	*taskdomain.Task
}

// EventName returns "task".
// EventName 返回 "task"。
func (Task) EventName() string { return "task" }

// MarshalJSON delegates to the embedded *taskdomain.Task.
// MarshalJSON 委托给嵌入的 *taskdomain.Task。
func (e Task) MarshalJSON() ([]byte, error) {
	if e.Task == nil {
		return []byte("null"), nil
	}
	return json.Marshal(e.Task)
}
