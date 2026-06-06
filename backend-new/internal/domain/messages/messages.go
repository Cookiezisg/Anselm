// Package messages is the content model for one conversation turn: the Block tree
// (reasoning / text / tool_call / tool_result) an assistant turn decomposes into, plus
// the in-memory ToolCallData a streamed tool call parses to. It is deliberately separate
// from domain/stream — stream is the TRANSPORT (how a frame reaches the front end),
// messages is the CONTENT (what a turn is made of). The shared ReAct engine (app/loop)
// produces Blocks and depends on THIS package, not on any single consumer like chat, so
// agent / subagent / chat all share one neutral content model.
//
// Package messages 是对话单回合的内容模型：一个 assistant 回合分解成的 Block 树
// （reasoning / text / tool_call / tool_result），加上流式 tool call 解析出的内存
// ToolCallData。它刻意与 domain/stream 分离——stream 是传输（帧怎么到前端），messages
// 是内容（回合由什么组成）。共享 ReAct 引擎（app/loop）产 Block 并依赖**本包**、而非
// 依赖 chat 这种具体消费者，故 agent / subagent / chat 共享一个中立内容模型。
package messages

import "time"

// Block is one node of an assistant turn's content tree, persisted to message_blocks.
// loop produces Blocks in memory; the host persists them (the store lives in chat M5.2).
// Seq is assigned at persist time, not by loop. ContextRole is set later by the compactor
// (contextmgr M5.3) and only projects how the block reaches LLM history — stored Content
// is never rewritten.
//
// Block 是 assistant 回合内容树的一个节点，持久化到 message_blocks。loop 内存产 Block；
// host 落盘（store 在 chat M5.2）。Seq 在落盘时分配、非 loop 设。ContextRole 后由压缩器
// （contextmgr M5.3）设置，只投影 block 如何进入 LLM 历史——落库 Content 永不改写。
type Block struct {
	ID             string         `db:"id,pk" json:"id"`
	ConversationID string         `db:"conversation_id" json:"conversationId"`
	MessageID      string         `db:"message_id" json:"messageId"`
	ParentBlockID  string         `db:"parent_block_id" json:"parentBlockId,omitempty"`
	Seq            int64          `db:"seq" json:"seq"`
	Type           string         `db:"type" json:"type"`
	Attrs          map[string]any `db:"attrs,json" json:"attrs,omitempty"`
	Content        string         `db:"content" json:"content"`
	Status         string         `db:"status" json:"status"`
	Error          string         `db:"error" json:"error,omitempty"`
	ContextRole    string         `db:"context_role" json:"contextRole,omitempty"`
	CreatedAt      time.Time      `db:"created_at,created" json:"createdAt"`
	UpdatedAt      time.Time      `db:"updated_at,updated" json:"updatedAt"`
}

// Block types — the content-tree node kinds loop emits. Deeper hierarchy (a subagent's
// message subtree under a tool_call) is expressed via stream Open.ParentID, NOT via new
// block types, so this set stays minimal.
//
// Block 类型——loop 发的内容树节点种类。更深层级（subagent 消息子树挂在 tool_call 下）
// 经 stream Open.ParentID 表达、**不**靠新增块型，故此集合保持精简。
const (
	BlockTypeText       = "text"
	BlockTypeReasoning  = "reasoning"
	BlockTypeToolCall   = "tool_call"
	BlockTypeToolResult = "tool_result"
	// BlockTypeCompaction marks a context-compaction summary (contextmgr M5.3); loop drops
	// it from LLM history because the content already lives in conversation.summary.
	//
	// BlockTypeCompaction 标记上下文压缩摘要（contextmgr M5.3）；loop 从 LLM 历史丢弃它，
	// 内容已在 conversation.summary。
	BlockTypeCompaction = "compaction"
)

// IsValidBlockType reports whether t is a known block type (store CHECK / contract对账).
//
// IsValidBlockType 报告 t 是否已知块型（供 store CHECK / 契约对账）。
func IsValidBlockType(t string) bool {
	switch t {
	case BlockTypeText, BlockTypeReasoning, BlockTypeToolCall, BlockTypeToolResult, BlockTypeCompaction:
		return true
	}
	return false
}

// Statuses span both message and block lifecycle. A message is pending before its turn
// starts; a block is implicitly streaming between its open and close. The three terminal
// states are shared and map 1:1 onto stream.Close statuses; pending applies only to a
// message, streaming to both.
//
// 状态横跨 message 与 block 生命周期。message 在回合开始前为 pending；block 在 open 与 close
// 之间隐含为 streaming。三个终态共享、与 stream.Close 状态 1:1 映射；pending 仅用于 message，
// streaming 两者皆用。
const (
	StatusPending   = "pending"
	StatusStreaming = "streaming"
	StatusCompleted = "completed"
	StatusError     = "error"
	StatusCancelled = "cancelled"
)

// IsValidStatus reports whether s is a known message/block status.
//
// IsValidStatus 报告 s 是否已知 message/block 状态。
func IsValidStatus(s string) bool {
	switch s {
	case StatusPending, StatusStreaming, StatusCompleted, StatusError, StatusCancelled:
		return true
	}
	return false
}

// StopReason is why an assistant turn ended. MaxSteps is a non-success terminal — the loop
// hit its step ceiling before the model finished, surfaced honestly so the UI can offer
// "continue" (rather than masquerading as a completed end_turn).
//
// StopReason 是 assistant 回合结束原因。MaxSteps 是非成功终态——loop 在模型完成前撞到
// 步数上限，诚实暴露使 UI 能提供「继续」（而非冒充 completed end_turn）。
const (
	StopReasonEndTurn   = "end_turn"
	StopReasonMaxTokens = "max_tokens"
	StopReasonMaxSteps  = "max_steps"
	StopReasonCancelled = "cancelled"
	StopReasonError     = "error"
)

// ContextRole projects how a block reaches LLM history without rewriting stored Content:
// hot = full, warm = truncated preview, cold = omitted-with-marker, archived = dropped
// (content folded into conversation.summary). Set by the compactor (contextmgr M5.3); the
// default at write time is hot.
//
// ContextRole 投影 block 如何进入 LLM 历史而不改写落库 Content：hot 全文、warm 截断预览、
// cold 省略带标记、archived 丢弃（内容并入 conversation.summary）。由压缩器（contextmgr
// M5.3）设置；落盘默认 hot。
const (
	ContextRoleHot      = "hot"
	ContextRoleWarm     = "warm"
	ContextRoleCold     = "cold"
	ContextRoleArchived = "archived"
)

// IsValidContextRole reports whether r is a known context role.
//
// IsValidContextRole 报告 r 是否已知 context role。
func IsValidContextRole(r string) bool {
	switch r {
	case ContextRoleHot, ContextRoleWarm, ContextRoleCold, ContextRoleArchived:
		return true
	}
	return false
}

// ToolCallData is the in-memory parsed form of one LLM tool call (never persisted as-is —
// it becomes a tool_call Block). Summary / Danger / ExecutionGroup are the framework
// standard fields the LLM self-declares on every call (stripped from Arguments by
// tool.StripStandardFields): Summary = one-line intent, Danger = self-reported risk
// (safe/cautious/dangerous, kept as a plain string so domain stays free of app/tool),
// ExecutionGroup = parallel-batch key.
//
// ToolCallData 是单个 LLM tool call 的内存解析形态（不原样落库——它转成 tool_call
// Block）。Summary / Danger / ExecutionGroup 是 LLM 每次调用自报的 framework 标准字段
// （由 tool.StripStandardFields 从 Arguments 剥离）：Summary 一句话意图、Danger 自报风险
// （safe/cautious/dangerous，存为纯字符串使 domain 不沾 app/tool）、ExecutionGroup 并行批键。
type ToolCallData struct {
	ID             string         `json:"id"`
	Name           string         `json:"name"`
	Summary        string         `json:"summary"`
	Danger         string         `json:"danger"`
	ExecutionGroup int            `json:"executionGroup"`
	Arguments      map[string]any `json:"arguments"`
}
