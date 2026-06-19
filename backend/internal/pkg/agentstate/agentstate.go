// Package agentstate carries per-conversation state shared across tool invocations. It exists
// because some safety invariants (e.g. write-before-read, pre-approved skill scope) span tools —
// a single tool's args cannot express them, so the host seeds an AgentState into ctx and tools
// cooperate through it. One instance lives for the whole active conversation (the convQueue
// creates it once and re-seeds the SAME instance into every turn), so it spans all turns until
// the conversation's idle teardown — NOT a single run.
//
// Scope = creator chooses. Slots: SeenFiles (filesystem's write-before-read, LRU-bounded so a
// long refactor over thousands of files can't grow it without limit), discoveredTools
// (search_tools' lazy-tool discovery), and activeSkill (skill's pre-approved tool scope). cwd is
// deliberately absent — the desktop agent has no working directory, so shell adds no cwd slot.
// agentstate grows on demand, no speculative fields.
//
// Package agentstate 持有对话级跨 tool 调用的共享状态。它存在是因为某些安全不变式（如写前必读、
// skill 预授权域）跨工具——单个工具的 args 表达不了，所以 host 把 AgentState 埋进 ctx，工具间靠
// 它协作。一个实例活整个活跃对话（convQueue 建一次、把同一实例 re-seed 进每个回合），故它跨所有
// 回合直到对话空闲拆除——**非**单次运行。
//
// 作用域 = 创建者决定。字段：SeenFiles（filesystem 写前必读，LRU 有界，使跨数千文件的长重构不会
// 无界增长）、discoveredTools（search_tools 的 lazy 工具发现）与 activeSkill（skill 的预授权工具域）。
// cwd 刻意不设——桌面 agent 无工作目录，shell 不引入 cwd。agentstate 按需生长，不预留。
package agentstate

import (
	"container/list"
	"sync"
)

// seenFilesCap bounds the write-before-read LRU. A conversation rarely touches more than a few
// hundred distinct files in its recent working set; a few thousand keeps the invariant intact for
// every recently-touched path while making total memory O(cap) instead of O(distinct paths ever).
//
// seenFilesCap 是写前必读 LRU 的上限。一个对话的近期工作集很少超过几百个不同文件；几千足以为
// 每个近期触过的路径保住不变式，同时把内存压成 O(cap) 而非 O(历史触过的全部路径)。
const seenFilesCap = 4096

// AgentState is the per-conversation shared state for tool invocations. Methods are
// concurrency-safe because tools within a step run in parallel (loop's execution-group
// batches), so multiple goroutines may MarkRead concurrently.
//
// AgentState 是 tool 调用的对话级共享状态。方法并发安全，因为同步内的工具并行跑
// （loop 的 execution-group 批），多 goroutine 可能并发 MarkRead。
type AgentState struct {
	// seenFiles is an LRU-bounded write-before-read record. Because the SAME AgentState is reused
	// across every turn of an active conversation, an unbounded map would grow one entry per distinct
	// path forever; a bounded LRU keeps the invariant for the recent working set and caps memory.
	// Guarded by seenMu (sync.Map gives no eviction).
	//
	// seenFiles 是 LRU 有界的写前必读记录。因同一 AgentState 在活跃对话每个回合复用，无界 map 会
	// 永久每路径一项；有界 LRU 为近期工作集保住不变式、封顶内存。由 seenMu 守护（sync.Map 无法淘汰）。
	seenMu    sync.Mutex
	seenLRU   *list.List               // front = most-recently-marked; element value = *seenEntry
	seenIndex map[string]*list.Element // path → its list element

	discoveredTools sync.Map // string (tool name) → bool

	// activeSkill is a single compound value (name + allowed-tools set), so it uses an explicit
	// RWMutex rather than sync.Map — the latter can't atomically read a name+slice pair together.
	//
	// activeSkill 是单个复合值（name + allowed-tools 集），故用显式 RWMutex 而非 sync.Map
	// （后者无法原子读到一致的 name+slice 对）。
	mu               sync.RWMutex
	activeSkillName  string
	activeSkillAllow map[string]struct{}
}

type seenEntry struct {
	path string
	size int64
}

// New returns a fresh AgentState. A host creates one per conversation and seeds it into ctx
// before invoking the loop on each turn.
//
// New 返回一个空 AgentState。host 每对话建一个、每回合跑 loop 前埋进 ctx。
func New() *AgentState {
	return &AgentState{
		seenLRU:   list.New(),
		seenIndex: make(map[string]*list.Element),
	}
}

// MarkRead records that path was successfully read (or just written) with the
// given size. Filesystem tools call it after every Read / successful Write / Edit
// so subsequent Write / Edit can verify the file was seen and detect external
// drift via size comparison. Re-marking refreshes recency; when the LRU is full the
// least-recently-marked path is evicted (it leaves the recent working set — a stale
// path forcing a re-read is the safe outcome).
//
// MarkRead 记录 path 已成功读（或刚写）且 size 为给定值。filesystem 工具在每次 Read /
// 成功 Write / Edit 后调用，使后续 Write / Edit 能验证文件已被看过、并通过 size 对比
// 检测外部漂移。重标刷新近度；LRU 满时淘汰最久未标的路径（它已离开近期工作集——逼一次
// 重读是安全结果）。
func (s *AgentState) MarkRead(path string, size int64) {
	s.seenMu.Lock()
	defer s.seenMu.Unlock()
	if el, ok := s.seenIndex[path]; ok {
		el.Value.(*seenEntry).size = size
		s.seenLRU.MoveToFront(el)
		return
	}
	s.seenIndex[path] = s.seenLRU.PushFront(&seenEntry{path: path, size: size})
	if s.seenLRU.Len() > seenFilesCap {
		oldest := s.seenLRU.Back()
		if oldest != nil {
			s.seenLRU.Remove(oldest)
			delete(s.seenIndex, oldest.Value.(*seenEntry).path)
		}
	}
}

// WasRead returns the size recorded at last MarkRead. ok=false means the file
// was never read this conversation (Write / Edit must refuse — fail-closed is the
// whole point of the write-before-read invariant), or it aged out of the LRU.
// ok=true with a size mismatch hints at external modification since last read. A
// successful read refreshes recency so a path under active edit stays resident.
//
// WasRead 返回最近一次 MarkRead 记下的 size。ok=false 表示本对话从未读过该文件
// （Write / Edit 必须拒——fail-closed 正是写前必读的本质）、或已被 LRU 淘汰。ok=true
// 但 size 不符暗示自上次读后被外部改过。一次成功读刷新近度，使正被编辑的路径常驻。
func (s *AgentState) WasRead(path string) (int64, bool) {
	s.seenMu.Lock()
	defer s.seenMu.Unlock()
	el, ok := s.seenIndex[path]
	if !ok {
		return 0, false
	}
	s.seenLRU.MoveToFront(el)
	return el.Value.(*seenEntry).size, true
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

// SetActiveSkill records the skill activated this run and pre-approves its allowed-tools. The
// allowed-tools set is a PRE-APPROVAL grant (skip per-call danger confirmation for these
// tools), NOT a restriction whitelist — unlisted tools still run, just with the usual flow.
// Consumed by the danger-confirmation flow. Activating a skill replaces any prior.
//
// SetActiveSkill 记录本次运行激活的 skill 并预授权其 allowed-tools。该集合是预授权（对这些
// 工具免逐次危险确认），不是限制白名单——未列出的工具照常跑。由危险确认流消费。
// 激活新 skill 整体替换旧的。
func (s *AgentState) SetActiveSkill(name string, allowedTools []string) {
	allow := make(map[string]struct{}, len(allowedTools))
	for _, t := range allowedTools {
		allow[t] = struct{}{}
	}
	s.mu.Lock()
	s.activeSkillName = name
	s.activeSkillAllow = allow
	s.mu.Unlock()
}

// ActiveSkill returns the name of the skill activated this run (empty if none).
//
// ActiveSkill 返回本次运行激活的 skill 名（无则空）。
func (s *AgentState) ActiveSkill() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.activeSkillName
}

// IsToolPreApprovedBySkill reports whether the active skill's allowed-tools pre-approve the
// named tool. False when no skill is active or the tool isn't listed.
//
// IsToolPreApprovedBySkill 报告 active skill 的 allowed-tools 是否预授权了该工具。无 active
// skill 或未列出时返 false。
func (s *AgentState) IsToolPreApprovedBySkill(toolName string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	_, ok := s.activeSkillAllow[toolName]
	return ok
}
