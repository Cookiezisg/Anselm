// registry.go — built-in SubagentType catalog.
//
// V1 ships three types modeled on Claude Code's analogous subagents:
//
//   - Explore         — read-only code reconnaissance (whitelisted to
//                       file/text-search tools); use to find code,
//                       grep symbols, locate definitions
//   - Plan            — design-time architectural advisor (whitelisted
//                       to read + web tools); use to plan strategy,
//                       identify critical files, weigh trade-offs
//   - general-purpose — full registry minus Subagent itself; use when
//                       you can't pick a specific type
//
// "Full registry minus Subagent" is encoded as AllowedTools = nil; the
// service interprets that as "inherit parent registry, drop Subagent".
//
// Future evolution (per subagent.md §15): file-loaded definitions
// analogous to Skill (~/.forgify/subagents/<name>.md). V1 keeps it
// in-code so the LLM-facing list is deterministic and reviewable.
//
// registry.go ——内置 SubagentType 目录。V1 三类（参考 Claude Code）：
// Explore（只读 code 侦察）/ Plan（设计期架构师）/ general-purpose（全
// 注册表去掉 Subagent 自身——AllowedTools=nil 表示"继承父，删 Subagent"）。
// 未来可加文件加载（subagent.md §15）；V1 内置让 LLM 可见列表确定可审。
package subagent

import (
	"sort"
	"sync"

	subagentdomain "github.com/sunweilin/forgify/backend/internal/domain/subagent"
)

// defaultMaxTurns is the per-type fallback when SubagentType.DefaultMaxTurns
// is zero. Lined up with Claude Code's published agents (25-30).
//
// defaultMaxTurns 是 SubagentType.DefaultMaxTurns 为 0 时的兜底。与
// Claude Code 公开的 agents 对齐（25-30）。
const defaultMaxTurns = 25

// builtInTypes is the V1 catalog. Tool names match the strings each
// tool returns from Tool.Name() (filesystem.Read → "Read", etc.).
//
// builtInTypes 是 V1 目录。工具名匹配各 Tool.Name() 返回值。
var builtInTypes = []subagentdomain.SubagentType{
	{
		Name:            "Explore",
		Description:     "Fast read-only search agent for locating code/files. Use to find files, grep symbols, answer 'where is X defined'. Tool list excludes mutation — don't use for analysis or design.",
		SystemPrompt:    "You are Explore, a code reconnaissance agent. Your job is to locate files, definitions, and references quickly. Use Read / Glob / Grep / LS to navigate. Return a concise summary of what you found (paths, line numbers, brief snippets). Do NOT propose changes or analysis — your role is purely to locate.",
		AllowedTools:    []string{"Read", "Glob", "Grep", "LS", "search_forges"},
		DefaultMaxTurns: 30,
	},
	{
		Name:            "Plan",
		Description:     "Software architect agent for designing implementation plans. Use when you need to plan strategy for a task, identify critical files, weigh trade-offs.",
		SystemPrompt:    "You are Plan, an architectural advisor. Your job is to produce a concrete implementation plan. Use Read / Glob / Grep / LS to inspect the existing code; use WebFetch / WebSearch when external context helps. Return a step-by-step plan, the critical files involved, and the main trade-offs. Do NOT modify any files — your role is strategy only.",
		AllowedTools:    []string{"Read", "Glob", "Grep", "LS", "WebFetch", "WebSearch"},
		DefaultMaxTurns: 25,
	},
	{
		Name:            "general-purpose",
		Description:     "General-purpose agent for researching complex questions, searching for code, executing multi-step tasks. Use when you're not confident a single search will succeed.",
		SystemPrompt:    "You are a general-purpose subagent. You inherit the parent agent's full tool registry minus Subagent itself, so you can read, search, edit, run shells, and more. Focus on completing the focused subtask the parent delegated to you, then return a concise summary.",
		AllowedTools:    nil, // nil = inherit parent registry minus Subagent
		DefaultMaxTurns: 25,
	},
}

// Registry indexes SubagentType by Name. Read-only after construction —
// V1 has no add/remove API; future file-loaded extensions will mutate
// behind the same Get/List facade.
//
// Registry 按 Name 索引 SubagentType。构造后只读——V1 无 add/remove API；
// 未来文件加载扩展通过同样的 Get/List 门面变更。
type Registry struct {
	once sync.Once
	idx  map[string]subagentdomain.SubagentType
}

// NewRegistry builds the V1 registry from the in-code builtInTypes slice.
//
// NewRegistry 用内置 builtInTypes slice 建 V1 注册表。
func NewRegistry() *Registry {
	return &Registry{}
}

func (r *Registry) ensureIndexed() {
	r.once.Do(func() {
		r.idx = make(map[string]subagentdomain.SubagentType, len(builtInTypes))
		for _, t := range builtInTypes {
			if t.DefaultMaxTurns <= 0 {
				t.DefaultMaxTurns = defaultMaxTurns
			}
			r.idx[t.Name] = t
		}
	})
}

// Get returns the SubagentType matching name; ok=false when absent.
//
// Get 按 name 取 SubagentType；不存在时 ok=false。
func (r *Registry) Get(name string) (subagentdomain.SubagentType, bool) {
	r.ensureIndexed()
	t, ok := r.idx[name]
	return t, ok
}

// List returns all registered types in stable Name order so the LLM
// description and any HTTP listing are deterministic across calls.
//
// List 返所有注册类型，按 Name 字母序稳定输出，让 LLM 描述和 HTTP 列表
// 跨调用保持确定。
func (r *Registry) List() []subagentdomain.SubagentType {
	r.ensureIndexed()
	out := make([]subagentdomain.SubagentType, 0, len(r.idx))
	for _, t := range r.idx {
		out = append(out, t)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out
}
