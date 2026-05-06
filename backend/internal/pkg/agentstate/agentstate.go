// Package agentstate carries per-conversation state shared across tool
// invocations (must-Read-first SeenFiles, Bash cwd). Lives in pkg/ (not
// app/chat/) so pkg/reqctx can ferry the pointer through ctx without cycles.
//
// Package agentstate 持有跨 tool 调用的对话级状态（must-Read-first 的 SeenFiles、
// Bash cwd）。放在 pkg/ 是为了让 pkg/reqctx 通过 ctx 转运指针不形成循环。
package agentstate

import "sync"

// AgentState is the per-conversation shared state for tool invocations.
// Methods are concurrency-safe.
//
// AgentState 是 tool 调用的对话级共享状态。方法并发安全。
type AgentState struct {
	// SeenFiles maps absolute path → file size at Read time. Edit/Write
	// check membership for must-Read-first; size detects external mods.
	//
	// SeenFiles：绝对路径 → Read 时文件 size。Edit/Write 检查 membership
	// 以强制 must-Read-first；size 用于检测外部修改。
	SeenFiles sync.Map // string → int64

	// cwd: empty = "use process cwd" (Bash resolves lazily, so zero-value AgentState works).
	// cwd: 空 = "用进程 cwd"（Bash 懒解析，零值 AgentState 即可用）。
	cwdMu sync.Mutex
	cwd   string

	// subagentTokens: append-only log of every Subagent spawn's token
	// totals (one entry per sub-run). The conversation-detail UI / cost
	// panel reads it to surface "this turn spent N tokens including 3
	// subagents". Concurrent appends from sibling sub-runs are isolated
	// by RunID; the mutex serializes the slice growth.
	//
	// subagentTokens：只追加日志，记录每次 Subagent spawn 的 token 累计
	// （单 sub-run 一条）。对话详情 / 成本面板读它显示"本轮花 N tokens 含
	// 3 个 subagent"。并发 sibling sub-run 按 RunID 隔离；mutex 串化 slice 增长。
	subTokensMu sync.Mutex
	subTokens   []SubagentTokenEntry

	// activeSkill: pointer to the currently-active skilldomain.Skill, or
	// nil when no skill is active. Set/cleared by app/skill.Service via
	// SetActiveSkill / ClearActiveSkillIfMatches; read on every tool
	// dispatch via IsToolPreApprovedBySkill (defined in skill.go to keep
	// the skill side-channel localized). atomic.Pointer (not mutex) per
	// skill.md §9.5.
	//
	// activeSkill：当前 active 的 skilldomain.Skill 指针，无则 nil。详见
	// skill.go（与方法集中以便审计）。atomic.Pointer 而非 mutex，per
	// skill.md §9.5。
	activeSkill activeSkillSlot
}

// SubagentTokenEntry is one row in AgentState.SubagentTokenLog. Written
// by app/subagent.Service when a sub-run terminates (or per-step if the
// frontend wants live cost feedback — current call site is final-write).
//
// SubagentTokenEntry 是 AgentState.SubagentTokenLog 的一行。app/subagent
// .Service 在 sub-run 终态时写入（前端要实时成本反馈也可改成 per-step；
// 当前调用点是终态写入）。
type SubagentTokenEntry struct {
	RunID     string `json:"runId"`
	TypeName  string `json:"typeName"`
	TokensIn  int    `json:"tokensIn"`
	TokensOut int    `json:"tokensOut"`
}

// AddSubagentTokens appends one entry to the per-conversation subagent
// token log. Sibling concurrent sub-runs in the same turn each call this
// once on terminate; the mutex isolates the append.
//
// AddSubagentTokens 给对话级 subagent token 日志追加一行。同一回合的
// sibling 并发 sub-run 各自终态时调用一次；mutex 隔离 append。
func (s *AgentState) AddSubagentTokens(runID, typeName string, in, out int) {
	s.subTokensMu.Lock()
	defer s.subTokensMu.Unlock()
	s.subTokens = append(s.subTokens, SubagentTokenEntry{
		RunID: runID, TypeName: typeName, TokensIn: in, TokensOut: out,
	})
}

// SubagentTokenLog returns a copy of the accumulated entries. Copy not
// alias so callers can read without holding the mutex.
//
// SubagentTokenLog 返回累积条目的拷贝（非别名），调用方读时无需持锁。
func (s *AgentState) SubagentTokenLog() []SubagentTokenEntry {
	s.subTokensMu.Lock()
	defer s.subTokensMu.Unlock()
	out := make([]SubagentTokenEntry, len(s.subTokens))
	copy(out, s.subTokens)
	return out
}

// MarkRead records path as Read this conversation with its current size.
//
// MarkRead 记录 path 在本对话中已 Read，并存当前 size。
func (s *AgentState) MarkRead(path string, size int64) {
	s.SeenFiles.Store(path, size)
}

// WasRead returns the size recorded at first MarkRead, or false if absent.
// A current-vs-recorded size mismatch can indicate external modification.
//
// WasRead 返回首次 MarkRead 时记录的 size；缺失返 false。
// 当前与记录 size 不一致可能意味着外部修改。
func (s *AgentState) WasRead(path string) (int64, bool) {
	v, ok := s.SeenFiles.Load(path)
	if !ok {
		return 0, false
	}
	return v.(int64), true
}

// Cwd returns the tracked Bash working directory; "" means "use process cwd".
//
// Cwd 返回追踪的 Bash 工作目录；"" 表示"用进程 cwd"。
func (s *AgentState) Cwd() string {
	s.cwdMu.Lock()
	defer s.cwdMu.Unlock()
	return s.cwd
}

// SetCwd updates the tracked working directory (called when Bash detects an
// entire-command `cd <path>`).
//
// SetCwd 更新追踪的工作目录（Bash 识别整条命令为 `cd <path>` 时调用）。
func (s *AgentState) SetCwd(path string) {
	s.cwdMu.Lock()
	defer s.cwdMu.Unlock()
	s.cwd = path
}
