// Package events defines typed event types for SSE streaming and
// in-process notification. Every event is a concrete Go struct — no
// map[string]any allowed — so the compiler catches shape drift.
//
// Naming: snake_case, dot-separated by domain. e.g. "chat.token",
// "tool.code_updated".
//
// Package events 定义 SSE 流推送和进程内通知的类型化事件。每个事件都是
// 具体的 Go struct——禁止 map[string]any——让编译器捕获载荷形状漂移。
//
// 命名：snake_case，按 domain 加点号前缀。如 "chat.token"、"tool.code_updated"。
package events

// Event is any typed message flowing through a Bridge.
//
// Event 是在 Bridge 中流动的类型化消息。
type Event interface {
	EventName() string
}

// ChatToken fires for every streamed token from the LLM.
// Expect hundreds to thousands per conversation turn.
//
// ChatToken 在 LLM 流式返回的每个 token 到达时触发，单轮对话会产生几百到几千条。
type ChatToken struct {
	ConversationID string `json:"conversationId"`
	MessageID      string `json:"messageId"` // 当前 assistant 消息 id
	Delta          string `json:"delta"`     // 增量文本
}

// EventName returns "chat.token".
// EventName 返回 "chat.token"。
func (ChatToken) EventName() string { return "chat.token" }

// ChatReasoningToken fires for every streamed token of the model's reasoning
// (thinking) content. Only produced by reasoning-capable models such as
// DeepSeek-R1. Clients may display this in a collapsible "Thinking…" block.
//
// ChatReasoningToken 在 LLM 推理内容（thinking）流式返回时触发，
// 仅推理型模型（如 DeepSeek-R1）产生。前端可折叠展示。
type ChatReasoningToken struct {
	ConversationID string `json:"conversationId"`
	MessageID      string `json:"messageId"`
	Delta          string `json:"delta"`
}

// EventName returns "chat.reasoning_token".
// EventName 返回 "chat.reasoning_token"。
func (ChatReasoningToken) EventName() string { return "chat.reasoning_token" }

// ChatToolCallStart fires as soon as the LLM names a tool in its streaming
// output — before arguments are complete. Lets the frontend show "calling X…"
// immediately without waiting for the full tool call.
//
// ChatToolCallStart 在 LLM 流式输出中首次出现 tool name 时立刻触发——
// 此时 arguments 尚未完整，让前端无需等待即可立刻显示"正在调用 X…"。
type ChatToolCallStart struct {
	ConversationID string `json:"conversationId"`
	MessageID      string `json:"messageId"`
	ToolCallID     string `json:"toolCallId"`
	ToolName       string `json:"toolName"`
}

// EventName returns "chat.tool_call_start".
// EventName 返回 "chat.tool_call_start"。
func (ChatToolCallStart) EventName() string { return "chat.tool_call_start" }

// ChatToolCall fires when the Agent decides to call a system tool.
// Arguments are complete and stripped of "summary" + "destructive" at this point.
//
// ChatToolCall 在 Agent 决定调用某个 system tool 时触发。
// 此时 arguments 已完整，且已剥除 "summary" 和 "destructive" 字段。
type ChatToolCall struct {
	ConversationID string `json:"conversationId"`
	MessageID      string `json:"messageId"`
	ToolCallID     string `json:"toolCallId"`
	ToolName       string `json:"toolName"`
	ToolInput      string `json:"toolInput"`   // JSON string of full arguments
	Summary        string `json:"summary"`     // human-readable core info, e.g. "$ git status"
	Destructive    bool   `json:"destructive"` // LLM-marked: this call may cause irreversible damage; UI shows warning
}

// EventName returns "chat.tool_call".
// EventName 返回 "chat.tool_call"。
func (ChatToolCall) EventName() string { return "chat.tool_call" }

// ChatToolResult fires when a tool execution completes.
//
// ChatToolResult 在 tool 执行完成时触发。
type ChatToolResult struct {
	ConversationID string `json:"conversationId"`
	ToolCallID     string `json:"toolCallId"`
	Result         string `json:"result"`
	OK             bool   `json:"ok"`
}

// EventName returns "chat.tool_result".
// EventName 返回 "chat.tool_result"。
func (ChatToolResult) EventName() string { return "chat.tool_result" }

// ChatDone fires when the Agent finishes the full response.
// StopReason distinguishes normal completion from truncation or cancellation.
//
// ChatDone 在 Agent 完成完整回复时触发。
// StopReason 区分正常完成、截断和取消。
type ChatDone struct {
	ConversationID string `json:"conversationId"`
	MessageID      string `json:"messageId"`
	StopReason     string `json:"stopReason"` // end_turn | max_tokens | cancelled | error
	InputTokens    int    `json:"inputTokens"`
	OutputTokens   int    `json:"outputTokens"`
}

// EventName returns "chat.done".
// EventName 返回 "chat.done"。
func (ChatDone) EventName() string { return "chat.done" }

// ChatError fires when the Agent encounters a non-recoverable error.
// Code matches the SCREAMING_SNAKE_CASE error codes in error-codes.md.
//
// ChatError 在 Agent 遇到不可恢复错误时触发。
// Code 与 error-codes.md 中的 SCREAMING_SNAKE_CASE 错误码对应。
type ChatError struct {
	ConversationID string `json:"conversationId"`
	Code           string `json:"code"`
	Message        string `json:"message"`
}

// EventName returns "chat.error".
// EventName 返回 "chat.error"。
func (ChatError) EventName() string { return "chat.error" }

// ConversationTitleUpdated fires after auto-titling writes a generated
// title back to the conversation, so the frontend sidebar updates without
// a manual refresh.
//
// ConversationTitleUpdated 在 auto-titling 把生成的标题写回对话后触发，
// 让前端侧边栏无需手动刷新即可更新。
type ConversationTitleUpdated struct {
	ConversationID string `json:"conversationId"`
	Title          string `json:"title"`
	AutoTitled     bool   `json:"autoTitled"`
}

// EventName returns "conversation.title_updated".
// EventName 返回 "conversation.title_updated"。
func (ConversationTitleUpdated) EventName() string { return "conversation.title_updated" }

// ── Forge events (Phase 3) ────────────────────────────────────────────────────

// ForgeCodeStreaming fires for every LLM token during code generation inside
// create_forge or edit_forge. MessageID and ToolCallID bind the stream to the
// specific conversation turn that triggered it, so the frontend can associate
// the code panel update with the right message.
// ForgeID is empty during create_forge (the forge does not exist yet).
//
// ForgeCodeStreaming 在 create_forge / edit_forge 内部 LLM 代码生成阶段
// 逐 token 触发。MessageID 和 ToolCallID 把流绑定到触发它的对话轮次，
// 前端据此将代码面板更新关联到正确的消息。
// create_forge 期间 ForgeID 为空（工具尚未创建）。
type ForgeCodeStreaming struct {
	ConversationID string `json:"conversationId"`
	MessageID      string `json:"messageId"`  // assistant message that triggered the tool call
	ToolCallID     string `json:"toolCallId"` // LLM-assigned tool call id
	ForgeID        string `json:"forgeId"`    // empty for create_forge; existing id for edit_forge
	ActionType     string `json:"actionType"` // "create" | "edit"
	Delta          string `json:"delta"`
}

// EventName returns "forge.code_streaming".
// EventName 返回 "forge.code_streaming"。
func (ForgeCodeStreaming) EventName() string { return "forge.code_streaming" }

// ForgeCreated fires after create_forge successfully saves the new forge.
//
// ForgeCreated 在 create_forge 成功保存新工具后触发。
type ForgeCreated struct {
	ConversationID string `json:"conversationId"`
	MessageID      string `json:"messageId"`
	ToolCallID     string `json:"toolCallId"`
	ForgeID        string `json:"forgeId"`
	ForgeName      string `json:"forgeName"`
}

// EventName returns "forge.created".
// EventName 返回 "forge.created"。
func (ForgeCreated) EventName() string { return "forge.created" }

// ForgePendingCreated fires after edit_forge saves a pending change awaiting
// user review.
//
// ForgePendingCreated 在 edit_forge 保存待用户审核的 pending 变更后触发。
type ForgePendingCreated struct {
	ConversationID string `json:"conversationId"`
	MessageID      string `json:"messageId"`
	ToolCallID     string `json:"toolCallId"`
	ForgeID        string `json:"forgeId"`
	PendingID      string `json:"pendingId"`   // ForgeVersion id with status='pending'
	Instruction    string `json:"instruction"` // the LLM instruction that produced this change
}

// EventName returns "forge.pending_created".
// EventName 返回 "forge.pending_created"。
func (ForgePendingCreated) EventName() string { return "forge.pending_created" }

// ForgeMetadataUpdated fires when edit_forge is called with empty Instruction —
// only name / description / tags are being changed, no code regeneration.
// Lets the UI distinguish "metadata-only edit" from "code-regenerating edit"
// (ForgeCodeStreaming will not fire in the metadata-only path).
//
// ForgeMetadataUpdated 在 edit_forge 仅修改 name/description/tags（不重生代码）时触发。
// 让前端区分"只改元数据" vs "重写代码"——后者会推 ForgeCodeStreaming 流。
type ForgeMetadataUpdated struct {
	ConversationID string `json:"conversationId"`
	MessageID      string `json:"messageId"`
	ToolCallID     string `json:"toolCallId"`
	ForgeID        string `json:"forgeId"`
	PendingID      string `json:"pendingId"` // ForgeVersion id with status='pending'
}

// EventName returns "forge.metadata_updated".
// EventName 返回 "forge.metadata_updated"。
func (ForgeMetadataUpdated) EventName() string { return "forge.metadata_updated" }
