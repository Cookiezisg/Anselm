// Package agentstate carries per-conversation state shared across tool invocations
// within one run. It exists because some safety invariants (e.g. write-before-read,
// pre-approved skill scope) span tools — a single tool's args cannot express them,
// so the host seeds an AgentState into ctx and tools cooperate through it.
//
// Scope = creator chooses. Two slots exist today: SeenFiles (filesystem's
// write-before-read) and discoveredTools (search_tools' lazy-tool discovery). Other
// slots (cwd, activeSkill) will be added by their own first consumers (shell /
// skill) — agentstate grows on demand, no speculative fields.
//
// Package agentstate 持有单次运行内跨 tool 调用的对话级共享状态。它存在是因为某些安全不变式
// （如写前必读、skill 预授权域）跨工具——单个工具的 args 表达不了，所以 host 把 AgentState
// 埋进 ctx，工具间靠它协作。
//
// 作用域 = 创建者决定。当下两个字段：SeenFiles（filesystem 写前必读）与 discoveredTools
// （search_tools 的 lazy 工具发现）。其余字段（cwd、activeSkill）由各自首个消费者（shell /
// skill）自己引入——agentstate 按需生长，不预留。
package agentstate

import "sync"

// AgentState is the per-run shared state for tool invocations. Methods are
// concurrency-safe because tools within a step run in parallel (loop's
// execution-group batches), so multiple goroutines may MarkRead concurrently.
//
// AgentState 是 tool 调用的运行级共享状态。方法并发安全，因为同步内的工具并行跑
// （loop 的 execution-group 批），多 goroutine 可能并发 MarkRead。
type AgentState struct {
	seenFiles       sync.Map // string → int64
	discoveredTools sync.Map // string (tool name) → bool
}

// New returns a fresh AgentState. A host creates one per run and seeds it into ctx
// before invoking the loop.
//
// New 返回一个空 AgentState。host 每次运行新建一个、跑 loop 前埋进 ctx。
func New() *AgentState {
	return &AgentState{}
}

// MarkRead records that path was successfully read (or just written) with the
// given size. Filesystem tools call it after every Read / successful Write / Edit
// so subsequent Write / Edit can verify the file was seen and detect external
// drift via size comparison.
//
// MarkRead 记录 path 已成功读（或刚写）且 size 为给定值。filesystem 工具在每次 Read /
// 成功 Write / Edit 后调用，使后续 Write / Edit 能验证文件已被看过、并通过 size 对比
// 检测外部漂移。
func (s *AgentState) MarkRead(path string, size int64) {
	s.seenFiles.Store(path, size)
}

// WasRead returns the size recorded at last MarkRead. ok=false means the file
// was never read this run (Write / Edit must refuse — fail-closed is the whole
// point of the write-before-read invariant). ok=true with a size mismatch hints
// at external modification since last read.
//
// WasRead 返回最近一次 MarkRead 记下的 size。ok=false 表示本次运行从未读过该文件
// （Write / Edit 必须拒——fail-closed 正是写前必读的本质）。ok=true 但 size 不符
// 暗示自上次读后被外部改过。
func (s *AgentState) WasRead(path string) (int64, bool) {
	v, ok := s.seenFiles.Load(path)
	if !ok {
		return 0, false
	}
	return v.(int64), true
}

// MarkToolDiscovered records that search_tools surfaced a lazy tool's full definition
// this run, so the host includes it in the LLM's tool list on subsequent turns (the
// LLM can keep calling a tool it has discovered without re-searching).
//
// MarkToolDiscovered 记录 search_tools 本次运行浮出了某 lazy 工具的完整定义，使 host 在后续
// 回合把它纳入 LLM 工具列表（LLM 可继续调用已发现的工具，无需重搜）。
func (s *AgentState) MarkToolDiscovered(name string) {
	s.discoveredTools.Store(name, true)
}

// IsToolDiscovered reports whether the named lazy tool was surfaced this run.
//
// IsToolDiscovered 报告某 lazy 工具本次运行是否已被浮出。
func (s *AgentState) IsToolDiscovered(name string) bool {
	_, ok := s.discoveredTools.Load(name)
	return ok
}

// DiscoveredTools returns the names of all lazy tools surfaced this run — the host
// uses it to assemble the active tool list (resident + discovered lazy). Order is
// unspecified (sync.Map range); callers needing stable order sort.
//
// DiscoveredTools 返回本次运行已浮出的所有 lazy 工具名——host 用它组装活动工具列表
// （resident + 已发现 lazy）。顺序未定（sync.Map range）；要稳定顺序的调用方自行排序。
func (s *AgentState) DiscoveredTools() []string {
	var out []string
	s.discoveredTools.Range(func(k, _ any) bool {
		out = append(out, k.(string))
		return true
	})
	return out
}
