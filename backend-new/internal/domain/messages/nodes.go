// Package messages defines the Node vocabulary for the messages SSE stream — the
// chat message tree. Nodes nest via stream.Open.ParentID: a tool_call's children are
// the invoked agent's message subtree, so "what happened inside a tool_call" streams
// as child nodes rather than as a flat request/result pair. See stream-protocol.md.
//
// Package messages 定义 messages SSE 流的 Node 词表——聊天消息树。节点经
// stream.Open.ParentID 嵌套：tool_call 的子节点 = 被调 agent 的 message 子树，所以
// "tool_call 内部发生的事"作为子节点流出，而非扁平的 request/result 二元组。
package messages

import "encoding/json"

// ⚠️ PROVISIONAL — node vocabulary not yet settled.
// The protocol skeleton (stream.Envelope / the 4 Frame verbs / the Node interface) is
// final and stable. The concrete node set below — which node types exist and what fields
// each carries — is a first cut derived from design, NOT a contract. It is re-confirmed
// against real needs when each producer module is wired up (its own wave per order.md).
//
// ⚠️ 暂定——词表未定稿。协议骨架（stream 信封 / 四动词 Frame / Node interface）已定稿
// 稳定；下面具体词表（有哪些 node、各带什么字段）是依设计推演的初版，非契约。到各
// producer 模块接线那一轮（order.md 各自波次）依实际需求重新确定。

// Message roles.
const (
	RoleUser      = "user"
	RoleAssistant = "assistant"
	RoleSystem    = "system"
)

// MessageNode is a top-level conversation turn (a node of type "message"); text /
// tool_call nodes mount under it. A nested message (an invoked agent's turn) opens
// with its ParentID pointing at the triggering tool_call node.
//
// MessageNode 是顶层对话回合（type="message" 节点）；text / tool_call 挂其下。嵌套
// message（被调 agent 的回合）以 ParentID 指向触发它的 tool_call 节点。
type MessageNode struct {
	Role string `json:"role"`
}

func (MessageNode) NodeType() string { return "message" }

// TextNode / ReasoningNode carry streamed assistant output; content arrives via Delta.
//
// TextNode / ReasoningNode 承载流式助手输出；内容经 Delta 到达。
type TextNode struct{}

func (TextNode) NodeType() string { return "text" }

type ReasoningNode struct{}

func (ReasoningNode) NodeType() string { return "reasoning" }

// ToolCallNode opens a tool invocation; its middle process (e.g. an invoked agent's
// turns) streams as child nodes mounted under it via Open.ParentID.
//
// ToolCallNode 开启一次工具调用；其中间过程（如被调 agent 的回合）经 Open.ParentID
// 作为子节点挂其下流出。
type ToolCallNode struct {
	Name string          `json:"name"`
	Args json.RawMessage `json:"args,omitempty"`
}

func (ToolCallNode) NodeType() string { return "tool_call" }

// ToolResultNode carries a tool's result content (streamed via Delta or given on Close.Result).
//
// ToolResultNode 承载工具结果内容（经 Delta 流式或在 Close.Result 给出）。
type ToolResultNode struct{}

func (ToolResultNode) NodeType() string { return "tool_result" }

// ProgressNode is a lightweight progress line under a parent (e.g. inside a tool_call).
//
// ProgressNode 是父节点下的轻量进度行（如 tool_call 内）。
type ProgressNode struct{}

func (ProgressNode) NodeType() string { return "progress" }

// CompactionNode marks a context-compaction event in the message tree.
//
// CompactionNode 标记消息树里的一次上下文压缩。
type CompactionNode struct{}

func (CompactionNode) NodeType() string { return "compaction" }
