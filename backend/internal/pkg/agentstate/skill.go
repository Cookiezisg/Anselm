// skill.go — ActiveSkill side-channel on AgentState. Set by
// app/skill.Service.Activate, read by the framework dispatch
// (app/loop/tools.go) to short-circuit permission prompts when the
// LLM-invoked tool is in the active skill's allowed-tools list.
//
// Design (skill.md §9 + §9.5):
//   - atomic.Pointer[skilldomain.Skill] — last-write-wins; no stack;
//     no RWMutex. Single user + serial tool dispatch make over-engineering
//     pointless.
//   - matchAllowedTool implements three pattern forms per spec:
//     "Read" (bare tool name), "Bash" (any args), "Bash(git *)" (wildcard
//     on the primary arg). V1 supports `*` wildcard only — full regex
//     deferred to V2.
//   - Bash-paren pattern parses the args JSON for a "command" key (the
//     Bash tool's primary arg). Other tools fall back to bare-name
//     matching since their args schemas vary; refining per-tool is V2.
//
// skill.go ——AgentState 上的 ActiveSkill 旁路。app/skill.Service.Activate
// 写、framework dispatch（app/loop/tools.go）读，用于 LLM 调的 tool 在
// active skill 的 allowed-tools 里时短路 permission prompt。设计：
// atomic.Pointer 单用户 + 串行 tool dispatch，加栈/RWMutex 是过度防御。
// 三种 pattern：bare name / "Bash" 任意 args / "Bash(git *)" wildcard
// （V1 仅 `*`，regex 待 V2）；paren 形式仅对 Bash 解析 "command" arg，
// 其他 tool 退化 bare name。
package agentstate

import (
	"encoding/json"
	"strings"
	"sync/atomic"

	skilldomain "github.com/sunweilin/forgify/backend/internal/domain/skill"
)

// SetActiveSkill records the skill as active for the current AgentState.
// Last-write-wins: any prior active skill is overwritten without ceremony
// (per skill.md §9.5: concurrent activate races are benign — at worst the
// later skill's allowed-tools win).
//
// SetActiveSkill 把 skill 记为当前 AgentState 的 active。Last-write-wins：
// 之前的 active skill 直接覆盖（skill.md §9.5：并发 activate 竞态良性
// ——最差是后到的 skill 的 allowed-tools 生效）。
func (s *AgentState) SetActiveSkill(skill *skilldomain.Skill) {
	s.activeSkill.Store(skill)
}

// ActiveSkill returns the currently-active skill, or nil if none. Caller
// must treat the returned pointer as read-only — concurrent SetActiveSkill
// can swap underneath but won't mutate the existing skill struct.
//
// ActiveSkill 返回当前 active 的 skill，无则 nil。调用方视返回指针为只读
// ——并发 SetActiveSkill 会替换但不改原 skill 结构。
func (s *AgentState) ActiveSkill() *skilldomain.Skill {
	return s.activeSkill.Load()
}

// ClearActiveSkillIfMatches removes the active skill ONLY if its name
// matches. Used in defer cleanup so a skill that already got replaced by
// another concurrent activate doesn't get stomped on the way out.
//
// ClearActiveSkillIfMatches 仅当 name 匹配时清除 active skill。在 defer
// 清理用，让已被并发 activate 替换的 skill 不会被退出时误清。
func (s *AgentState) ClearActiveSkillIfMatches(name string) {
	cur := s.activeSkill.Load()
	if cur != nil && cur.Name == name {
		s.activeSkill.CompareAndSwap(cur, nil)
	}
}

// IsToolPreApprovedBySkill returns true if the active skill's allowed-tools
// list grants toolName for the given args. argsJSON is needed to evaluate
// paren-form patterns like "Bash(git *)" against the actual command. A nil
// active skill or empty allowed-tools list returns false.
//
// IsToolPreApprovedBySkill 当 active skill 的 allowed-tools 授予 toolName
// （在给定 args 下）返 true。argsJSON 用于评估 "Bash(git *)" 这类 paren
// 形式 pattern 对真实 command 的匹配。active 为 nil 或 allowed 空 → false。
func (s *AgentState) IsToolPreApprovedBySkill(toolName string, argsJSON []byte) bool {
	skill := s.activeSkill.Load()
	if skill == nil {
		return false
	}
	for _, pattern := range skill.Frontmatter.AllowedTools {
		if matchAllowedTool(pattern, toolName, argsJSON) {
			return true
		}
	}
	return false
}

// matchAllowedTool tests one pattern against (toolName, argsJSON). Three
// forms per skill.md §9:
//
//	"Read"          → bare tool name; matches any invocation of Read
//	"Bash"          → bare with no paren; matches Bash with any args
//	"Bash(git *)"   → paren spec; matches when args["command"] starts
//	                  with "git " (single `*` wildcard, V1 simple matcher)
//	"Bash(npm test)"→ paren spec, no wildcard; exact match required
//
// matchAllowedTool 用一个 pattern 测 (toolName, argsJSON)。3 种 form。
func matchAllowedTool(pattern, toolName string, argsJSON []byte) bool {
	open := strings.IndexByte(pattern, '(')
	if open < 0 {
		// Bare tool name — match by name only.
		// 裸 tool 名——仅按名匹配。
		return pattern == toolName
	}
	close := strings.LastIndexByte(pattern, ')')
	if close <= open {
		// Malformed pattern (open paren without matching close); treat as
		// non-match rather than panic — author bug should not collapse
		// permission gating.
		// 畸形 pattern——视为不匹配，不 panic（author bug 不该击穿权限）。
		return false
	}
	patternTool := pattern[:open]
	if patternTool != toolName {
		return false
	}
	spec := pattern[open+1 : close]

	// V1 only knows how to extract the primary arg for the Bash family;
	// other tools fall through to non-match for paren patterns. Future:
	// per-tool extractor table when more tools acquire paren patterns.
	// V1 仅 Bash 家族知道怎么提主参；其他 tool 的 paren pattern 退化为不
	// 匹配。未来 per-tool extractor 表。
	primary := extractPrimaryArg(toolName, argsJSON)
	if primary == "" {
		return false
	}
	return wildcardMatch(spec, primary)
}

// extractPrimaryArg returns the user-supplied "command" field for Bash and
// its variants; empty for other tools. Centralizes the V1 paren-pattern
// support so adding a new paren-aware tool is one switch arm.
//
// extractPrimaryArg 返 Bash 类的 "command" 字段；其他 tool 返空。集中 V1
// paren-pattern 支持，加新 tool 只改一处。
func extractPrimaryArg(toolName string, argsJSON []byte) string {
	switch toolName {
	case "Bash":
		var args struct {
			Command string `json:"command"`
		}
		if err := json.Unmarshal(argsJSON, &args); err != nil {
			return ""
		}
		return args.Command
	}
	return ""
}

// wildcardMatch tests pattern against subject with `*` glob semantics.
// Supports leading/trailing/embedded `*`; no character classes, no `?`.
// Anchored at both ends (no implicit prefix/suffix wildcard).
//
// Examples:
//
//	"git *"     matches "git status"        ✓
//	"git *"     matches "git push --force"  ✓
//	"git *"     matches "git"               ✗  (trailing space requires content)
//	"npm test"  matches "npm test"          ✓
//	"npm test"  matches "npm tests"         ✗  (anchored)
//	"*foo*"     matches "barfoobar"         ✓
//
// wildcardMatch 用 `*` glob 语义测 pattern 对 subject。支持首/尾/内嵌
// `*`；无字符类、无 `?`。两端 anchor。
func wildcardMatch(pattern, subject string) bool {
	parts := strings.Split(pattern, "*")
	if len(parts) == 1 {
		// No wildcard — exact equality.
		// 无通配——完全相等。
		return pattern == subject
	}
	// First part must prefix subject (unless empty, meaning "*..." — leading wildcard).
	// 第一段必须前缀 subject（除非空——前导 `*`）。
	if !strings.HasPrefix(subject, parts[0]) {
		return false
	}
	subject = subject[len(parts[0]):]
	// Last part must suffix subject (unless empty — trailing wildcard).
	// 最后一段必须后缀 subject（除非空——尾随 `*`）。
	last := parts[len(parts)-1]
	if !strings.HasSuffix(subject, last) {
		return false
	}
	subject = subject[:len(subject)-len(last)]
	// Middle parts must each appear in order.
	// 中间段按顺序出现。
	for _, mid := range parts[1 : len(parts)-1] {
		idx := strings.Index(subject, mid)
		if idx < 0 {
			return false
		}
		subject = subject[idx+len(mid):]
	}
	return true
}

// activeSkillSlot is the type-erased holder for AgentState.activeSkill.
// We use atomic.Pointer rather than mutex because (a) reads vastly outnumber
// writes (every tool dispatch reads; activate writes once), (b) skill
// pointers are immutable post-Activate (no struct mutation), and (c) the
// "race window" between Set and ToolDispatch is benign per §9.5.
//
// activeSkillSlot 是 AgentState.activeSkill 的载体类型。用 atomic.Pointer
// 而非 mutex：(a) 读远多于写 (b) skill 指针 Activate 后不再变 (c) §9.5
// race 窗口良性。
type activeSkillSlot = atomic.Pointer[skilldomain.Skill]
