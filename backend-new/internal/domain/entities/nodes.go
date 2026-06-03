// Package entities defines the Node vocabulary for the entities SSE stream — the
// per-entity streaming output bus (function / handler / agent / workflow / document /
// mcp / skill): AI create/edit content streaming in, and run-time output (terminal,
// agent turns) streaming out. Agent-run turns are dual-output — the same nodes also
// go on the messages stream (different consumer, shared node ID). See stream-protocol.md.
//
// Package entities 定义 entities SSE 流的 Node 词表——按实体的流式输出总线（fn / hd /
// agent / wf / doc / mcp / skill）：AI 创建/编辑内容流式进、运行时输出（终端、agent
// 对话）流式出。agent 运行的对话是双输出——同样的 node 也上 messages 流（消费者不同、
// 共享 node ID）。
package entities

// Forge operations — the kind of edit an AI is streaming onto an entity.
//
// Forge 操作——AI 正在向实体流式写入的编辑类型。
const (
	OperationCreate = "create"
	OperationEdit   = "edit"
	OperationRevert = "revert"
	OperationDelete = "delete"
)

// ForgeNode opens an AI create/edit of an entity; the generated content streams via Delta.
//
// ForgeNode 开启对实体的 AI 创建/编辑；生成内容经 Delta 流入。
type ForgeNode struct {
	Operation string `json:"operation"`
}

func (ForgeNode) NodeType() string { return "forge" }

// RunNode opens a manual run of an entity; output streams via Delta / child nodes
// (a run of an agent mounts the agent's message turns as children).
//
// RunNode 开启实体的手动运行；输出经 Delta / 子节点流出（运行 agent 时把 agent 的
// message 回合作为子节点挂入）。
type RunNode struct{}

func (RunNode) NodeType() string { return "run" }

// Env attempt statuses.
const (
	EnvInstalling = "installing"
	EnvFixing     = "fixing"
	EnvOK         = "ok"
	EnvFailed     = "failed"
)

// EnvAttemptNode reports one environment-install attempt (initial + LLM-fix retries),
// nested under a forge/run node.
//
// EnvAttemptNode 报告一次环境安装尝试（初次 + LLM 修建议重试），挂在 forge/run 节点下。
type EnvAttemptNode struct {
	Attempt int    `json:"attempt"`
	Stage   string `json:"stage,omitempty"`
}

func (EnvAttemptNode) NodeType() string { return "env_attempt" }

// TerminalNode carries raw terminal output from a function/handler run (streamed via Delta).
//
// TerminalNode 承载 function/handler 运行的终端输出（经 Delta 流式）。
type TerminalNode struct{}

func (TerminalNode) NodeType() string { return "terminal" }
