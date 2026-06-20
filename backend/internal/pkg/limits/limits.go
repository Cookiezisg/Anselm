// Package limits is the single source for user-tunable operational ceilings. Every field
// here HAS a real consumer reading it through Current() — fields without a consumer do
// not exist (the schema is a projection of reality, not an aspiration). Startup loads
// <dataDir>/settings.json via app/settings and swaps the source with SetProvider; a
// PATCH /api/v1/limits hot-swaps it again, so consumers see new values on the next read.
//
// Package limits 是用户可调运行上限的唯一来源。这里每个字段都**有真实消费方**经 Current()
// 读取——没有消费方的字段不存在（schema 是现实的投影、不是愿景）。启动时 app/settings 读
// <dataDir>/settings.json 并经 SetProvider 换源；PATCH /api/v1/limits 再热换，消费方下一次
// 读取即见新值。
package limits

// Limits mirrors the settings.json "limits" block. Zero value of any field means
// "use the Default()" — WithDefaults fills zeros.
//
// Limits 镜像 settings.json 的 "limits" 段。任一字段零值 = 用 Default()——WithDefaults 补零。
type Limits struct {
	Agent   AgentLimits   `json:"agent"`
	Context ContextLimits `json:"context"`
	Timeout TimeoutLimits `json:"timeout"`
	Tools   ToolLimits    `json:"tools"`
	Guards  GuardLimits   `json:"guards"`
}

type AgentLimits struct {
	// MaxSteps caps the chat ReAct loop (consumer: chatapp).
	// MaxSteps 限聊天 ReAct 循环（消费方：chatapp）。
	MaxSteps int `json:"maxSteps"`
	// InvokeMaxTurns is the default turn cap for one agent invocation — chat invoke_agent,
	// HTTP :invoke and workflow agent nodes alike; an explicit per-call MaxTurns overrides
	// (consumer: agentapp).
	// InvokeMaxTurns 是一次 agent 调用的默认轮数上限——chat invoke_agent、HTTP :invoke、
	// workflow agent 节点同用；调用级显式 MaxTurns 可覆盖（消费方：agentapp）。
	InvokeMaxTurns int `json:"invokeMaxTurns"`
}

type ContextLimits struct {
	// TriggerRatio: compact when the last turn's input tokens reach this fraction of the
	// input budget (consumer: contextmgr).
	// TriggerRatio：末回合 input token 达 input 预算此比例时压缩（消费方：contextmgr）。
	TriggerRatio float64 `json:"triggerRatio"`
}

type TimeoutLimits struct {
	// LLMIdleSec resets per streamed token; fires only on a dead connection (consumer: infra/llm).
	// LLMIdleSec 每个流式 token 重置；只在死连接时触发（消费方：infra/llm）。
	LLMIdleSec int `json:"llmIdleSec"`
	// MCPCallSec bounds one MCP tool call (consumer: mcpapp).
	// MCPCallSec 限一次 MCP 工具调用（消费方：mcpapp）。
	MCPCallSec int `json:"mcpCallSec"`
	// BashDefaultTimeoutSec is the bash tool's default when the LLM passes none (consumer: shell).
	// BashDefaultTimeoutSec 是 LLM 未传超时时 bash 工具的默认（消费方：shell）。
	BashDefaultTimeoutSec int `json:"bashDefaultTimeoutSec"`
	// FunctionRunSec bounds one function run's wall clock (consumer: functionapp.RunFunction) — a
	// runaway / infinite-loop function otherwise pins a worker (esp. a workflow node, with no client
	// to navigate away and cancel). Deadline-exceeded surfaces as the durable ExecutionStatusTimeout.
	// FunctionRunSec 限一次 function 运行的墙钟（消费方：functionapp.RunFunction）——失控/死循环 function
	// 否则钉死一个 worker（尤其 workflow 节点：无客户端可导航走取消）。超时记为 ExecutionStatusTimeout。
	FunctionRunSec int `json:"functionRunSec"`
	// AgentInvokeSec bounds one agent invocation's wall clock (consumer: agentapp.InvokeAgent) — the
	// ReAct loop is otherwise only turn-capped (InvokeMaxTurns), so a slow agent (turns × idle/tool
	// waits) run synchronously on the single workflow drain goroutine starves draining + approval
	// timeouts for ALL workspaces. Deadline-exceeded surfaces as the durable, :replay-able
	// ExecutionStatusTimeout. Default is generous (a multi-turn agent can legitimately run minutes).
	// AgentInvokeSec 限一次 agent 调用的墙钟（消费方：agentapp.InvokeAgent）——ReAct 循环否则只受轮数封顶
	// （InvokeMaxTurns），慢 agent（轮数 × idle/工具等待）在单条 workflow drain 协程上同步跑会饿死所有
	// workspace 的排空 + 审批超时。超时记为 durable、可 :replay 的 ExecutionStatusTimeout。默认从宽
	// （多轮 agent 合理地可跑数分钟）。
	AgentInvokeSec int `json:"agentInvokeSec"`
}

type ToolLimits struct {
	// ReadDefaultLines is the Read tool's default page (consumer: filesystem read).
	// ReadDefaultLines 是 Read 工具默认页大小（消费方：filesystem read）。
	ReadDefaultLines int `json:"readDefaultLines"`
	// BashOutputCapKB caps captured bash output (consumer: shell).
	// BashOutputCapKB 限 bash 捕获输出（消费方：shell）。
	BashOutputCapKB int `json:"bashOutputCapKB"`
	// ToolResultCapKB caps any tool_result fed back to the LLM (consumer: loop).
	// ToolResultCapKB 限回喂 LLM 的任何 tool_result（消费方：loop）。
	ToolResultCapKB int `json:"toolResultCapKB"`
}

type GuardLimits struct {
	// AttachmentMaxMB caps one uploaded file (consumers: attachmentapp + upload handler).
	// AttachmentMaxMB 限单个上传文件（消费方：attachmentapp + 上传 handler）。
	AttachmentMaxMB int `json:"attachmentMaxMB"`
	// WebhookBodyMaxMB caps an inbound webhook body (consumer: infra/trigger/webhook).
	// WebhookBodyMaxMB 限入站 webhook body（消费方：infra/trigger/webhook）。
	WebhookBodyMaxMB int `json:"webhookBodyMaxMB"`
}

// Default returns the operative defaults — the constants enforced when settings.json
// names no override.
//
// Default 返默认值——settings.json 未点名覆盖时执行的常量。
func Default() Limits {
	return Limits{
		Agent:   AgentLimits{MaxSteps: 25, InvokeMaxTurns: 10},
		Context: ContextLimits{TriggerRatio: 0.80},
		Timeout: TimeoutLimits{
			LLMIdleSec:            150,
			MCPCallSec:            180,
			BashDefaultTimeoutSec: 120,
			FunctionRunSec:        300,
			AgentInvokeSec:        900,
		},
		Tools: ToolLimits{
			ReadDefaultLines: 2000,
			BashOutputCapKB:  256,
			ToolResultCapKB:  256,
		},
		Guards: GuardLimits{AttachmentMaxMB: 50, WebhookBodyMaxMB: 10},
	}
}

// FieldSpec is one tunable limit's machine-readable metadata: its dotted json key, group,
// default, the bounds validate() enforces, unit and a one-line description. The settings UI
// renders ranges/defaults from this instead of re-hardcoding the Go constants (which would
// drift). Keep the Schema() list 1:1 with the Limits struct — TestSchema_MatchesStruct guards it.
//
// FieldSpec 是一个可调上限的机器可读元数据:点分 json key、组、默认、validate() 强制的 bounds、
// 单位、一行描述。设置 UI 据此渲染范围/默认,免复刻 Go 常量(会漂)。Schema() 与 Limits 结构 1:1
// ——TestSchema_MatchesStruct 守。
type FieldSpec struct {
	Key       string  `json:"key"`
	Group     string  `json:"group"`
	Default   float64 `json:"default"`
	Min       float64 `json:"min"`
	Max       float64 `json:"max,omitempty"`       // 0 = unbounded above
	Exclusive bool    `json:"exclusive,omitempty"` // bounds open, not closed (TriggerRatio ∈ (0,1))
	Unit      string  `json:"unit"`
	Desc      string  `json:"desc"`
}

// Schema returns the metadata for every tunable limit. Defaults come from Default(); the
// bounds MIRROR app/settings.validate() — all ints must be > 0 (min 1, unbounded above) and
// TriggerRatio ∈ (0,1) exclusive. If validate() changes a bound, change it here too (the
// 1:1 guard test catches a missing/extra field but not a loosened bound).
//
// Schema 返回每个可调上限的元数据。默认取自 Default();bounds 镜像 app/settings.validate()——
// 所有 int 须 >0(min 1、上不封顶)、TriggerRatio ∈ (0,1) 开区间。validate() 改了 bound 这里要跟
// (1:1 守护测试只抓字段缺/多,抓不到 bound 放宽)。
func Schema() []FieldSpec {
	d := Default()
	return []FieldSpec{
		{"agent.maxSteps", "agent", float64(d.Agent.MaxSteps), 1, 0, false, "steps", "Max steps in the chat ReAct loop."},
		{"agent.invokeMaxTurns", "agent", float64(d.Agent.InvokeMaxTurns), 1, 0, false, "turns", "Default turn cap for one agent invocation (a per-call MaxTurns overrides)."},
		{"context.triggerRatio", "context", d.Context.TriggerRatio, 0, 1, true, "ratio", "Compact when the last turn's input tokens reach this fraction of the input budget."},
		{"timeout.llmIdleSec", "timeout", float64(d.Timeout.LLMIdleSec), 1, 0, false, "seconds", "LLM idle timeout, reset per streamed token (fires only on a dead connection)."},
		{"timeout.mcpCallSec", "timeout", float64(d.Timeout.MCPCallSec), 1, 0, false, "seconds", "Wall-clock bound on one MCP tool call."},
		{"timeout.bashDefaultTimeoutSec", "timeout", float64(d.Timeout.BashDefaultTimeoutSec), 1, 0, false, "seconds", "Bash tool default timeout when the LLM passes none."},
		{"timeout.functionRunSec", "timeout", float64(d.Timeout.FunctionRunSec), 1, 0, false, "seconds", "Wall-clock bound on one function run."},
		{"timeout.agentInvokeSec", "timeout", float64(d.Timeout.AgentInvokeSec), 1, 0, false, "seconds", "Wall-clock bound on one agent invocation."},
		{"tools.readDefaultLines", "tools", float64(d.Tools.ReadDefaultLines), 1, 0, false, "lines", "Read tool's default page size."},
		{"tools.bashOutputCapKB", "tools", float64(d.Tools.BashOutputCapKB), 1, 0, false, "KB", "Cap on captured bash output."},
		{"tools.toolResultCapKB", "tools", float64(d.Tools.ToolResultCapKB), 1, 0, false, "KB", "Cap on any tool_result fed back to the LLM."},
		{"guards.attachmentMaxMB", "guards", float64(d.Guards.AttachmentMaxMB), 1, 0, false, "MB", "Cap on one uploaded file."},
		{"guards.webhookBodyMaxMB", "guards", float64(d.Guards.WebhookBodyMaxMB), 1, 0, false, "MB", "Cap on an inbound webhook body."},
	}
}

// WithDefaults fills every zero field from Default() — settings parsing tolerance:
// a partial settings.json tunes only what it names.
//
// WithDefaults 用 Default() 补全零值字段——settings 解析容差：部分 settings.json 只调它点名的。
func WithDefaults(l Limits) Limits {
	d := Default()
	if l.Agent.MaxSteps == 0 {
		l.Agent.MaxSteps = d.Agent.MaxSteps
	}
	if l.Agent.InvokeMaxTurns == 0 {
		l.Agent.InvokeMaxTurns = d.Agent.InvokeMaxTurns
	}
	if l.Context.TriggerRatio == 0 {
		l.Context.TriggerRatio = d.Context.TriggerRatio
	}
	if l.Timeout.LLMIdleSec == 0 {
		l.Timeout.LLMIdleSec = d.Timeout.LLMIdleSec
	}
	if l.Timeout.MCPCallSec == 0 {
		l.Timeout.MCPCallSec = d.Timeout.MCPCallSec
	}
	if l.Timeout.BashDefaultTimeoutSec == 0 {
		l.Timeout.BashDefaultTimeoutSec = d.Timeout.BashDefaultTimeoutSec
	}
	if l.Timeout.FunctionRunSec == 0 {
		l.Timeout.FunctionRunSec = d.Timeout.FunctionRunSec
	}
	if l.Timeout.AgentInvokeSec == 0 {
		l.Timeout.AgentInvokeSec = d.Timeout.AgentInvokeSec
	}
	if l.Tools.ReadDefaultLines == 0 {
		l.Tools.ReadDefaultLines = d.Tools.ReadDefaultLines
	}
	if l.Tools.BashOutputCapKB == 0 {
		l.Tools.BashOutputCapKB = d.Tools.BashOutputCapKB
	}
	if l.Tools.ToolResultCapKB == 0 {
		l.Tools.ToolResultCapKB = d.Tools.ToolResultCapKB
	}
	if l.Guards.AttachmentMaxMB == 0 {
		l.Guards.AttachmentMaxMB = d.Guards.AttachmentMaxMB
	}
	if l.Guards.WebhookBodyMaxMB == 0 {
		l.Guards.WebhookBodyMaxMB = d.Guards.WebhookBodyMaxMB
	}
	return l
}

// current is the live limits source. Defaults to Default; app/settings swaps it at
// startup (and again on PATCH) via SetProvider. Provider swaps use a plain assignment
// guarded by the call sites' ordering (startup before serve; PATCH handler serialized) —
// consumers read a func value, which is safe to replace.
//
// current 是 limits 的活动来源。默认 Default；app/settings 启动时（与 PATCH 时）经
// SetProvider 换源。消费方读的是 func 值，替换安全。
var current = Default

// Current returns the live limits.
//
// Current 返活动 limits。
func Current() Limits { return current() }

// SetProvider swaps the live source (nil ignored).
//
// SetProvider 换活动来源（nil 忽略）。
func SetProvider(p func() Limits) {
	if p != nil {
		current = p
	}
}
