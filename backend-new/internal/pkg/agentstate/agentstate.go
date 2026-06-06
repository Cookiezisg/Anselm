// Package agentstate carries per-conversation state shared across tool invocations
// within one run. It exists because some safety invariants (e.g. write-before-read,
// pre-approved skill scope) span tools — a single tool's args cannot express them,
// so the host seeds an AgentState into ctx and tools cooperate through it.
//
// Scope = creator chooses; today's only consumer is filesystem (Read/Write/Edit) so
// only the SeenFiles slot exists. Other slots (cwd, activeSkill, activatedGroups)
// will be added by their own first consumers (shell / skill / toolset) — agentstate
// grows on demand, no speculative fields.
//
// Package agentstate 持有单次运行内跨 tool 调用的对话级共享状态。它存在是因为某些安全不变式
// （如写前必读、skill 预授权域）跨工具——单个工具的 args 表达不了，所以 host 把 AgentState
// 埋进 ctx，工具间靠它协作。
//
// 作用域 = 创建者决定；当下唯一消费者是 filesystem（Read/Write/Edit），故只有 SeenFiles 字段。
// 其余字段（cwd、activeSkill、activatedGroups）由各自首个消费者（shell / skill / toolset）
// 自己引入——agentstate 按需生长，不预留。
package agentstate

import "sync"

// AgentState is the per-run shared state for tool invocations. Methods are
// concurrency-safe because tools within a step run in parallel (loop's
// execution-group batches), so multiple goroutines may MarkRead concurrently.
//
// AgentState 是 tool 调用的运行级共享状态。方法并发安全，因为同步内的工具并行跑
// （loop 的 execution-group 批），多 goroutine 可能并发 MarkRead。
type AgentState struct {
	seenFiles sync.Map // string → int64
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
