// Package tool defines the Tool interface that every system tool implements
// and the framework-level machinery for LLM tool-call handling.
//
// Architecture:
//
//   - Tool interface: 9 required methods covering identity, static metadata,
//     args-dependent hooks, and main execution.
//   - Standard injected fields: every tool's Parameters schema is augmented
//     with three LLM-facing fields — "summary" (required string),
//     "destructive" (optional bool, default false), and "execution_group"
//     (optional integer ≥ 1; same group = parallel batch). The framework
//     strips all three before passing args to Execute and stores them as
//     first-class fields on ToolCallData.
//   - Sub-packages by tool family: tool/forge/ for user-forged-tool tools,
//     plus future tool/filesystem/, tool/shell/, tool/web/, tool/tasks/,
//     tool/ux/ (Phase 5). §S12 example position; alias `<sub><parent>` per §S13.
//
// Package tool 定义每个 system tool 必须实现的 Tool 接口及框架层 LLM 工具调用处理设施。
//
// 架构：
//   - Tool 接口：9 个必须方法，涵盖 identity / 静态元数据 / args-dependent 钩子 / 主入口
//   - 标准注入字段：每个 tool 的 Parameters schema 自动加上三个 LLM-facing 字段——
//     "summary"（必填 string）、"destructive"（可选 bool 默认 false）、
//     "execution_group"（可选 integer ≥ 1，同 group = 并行 batch）。框架在传给
//     Execute 前剥除三者，并作为 ToolCallData 一等字段独立存储。
//   - 按 tool 家族分子包：tool/forge/、tool/filesystem/、tool/shell/、tool/web/、
//     tool/tasks/、tool/ux/（§S12 例外位置，§S13 别名规则 `<sub><parent>`）
package tool

import (
	"context"
	"encoding/json"
	"fmt"

	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// ── Permission types ──────────────────────────────────────────────────────────

// PermissionMode is the agent's current permission mode for a turn.
// Phase 3 (current): only PermissionModeDefault is wired; runTools always
// passes Default. Reserved for Phase 4+ workflow scheduler / acceptEdits UI.
//
// PermissionMode 是 agent 当前回合的权限模式。
// Phase 3（当下）只串通 PermissionModeDefault；runTools 一律传 Default。
// 保留接口位给 Phase 4+ workflow scheduler / acceptEdits UI 用。
type PermissionMode string

const (
	PermissionModeDefault     PermissionMode = "default"
	PermissionModeAcceptEdits PermissionMode = "acceptEdits"
	PermissionModePlan        PermissionMode = "plan"
	PermissionModeBypass      PermissionMode = "bypass"
)

// PermissionResult is what CheckPermissions returns.
//
// PermissionResult 是 CheckPermissions 的返回值。
type PermissionResult int

const (
	PermissionAllow PermissionResult = iota // 允许执行
	PermissionDeny                          // 拒绝执行（返错给 LLM）
	PermissionAsk                           // 问用户（Phase 4+，当前等价 Allow）
)

// ── Tool interface ────────────────────────────────────────────────────────────

// Tool is the contract every system tool must implement.
// All 9 methods are required — there is no BaseTool to inherit defaults from.
// This is intentional: each tool's metadata is explicit and greppable.
//
// Concurrency note: there is no IsConcurrencySafe method anymore. Parallel
// scheduling is driven by the LLM-supplied "execution_group" standard field
// (extracted by StripStandardFields). Same group = parallel batch; different
// groups = sequential in ascending order. See chat/tools.go for the
// partitioning logic.
//
// Tool 是每个 system tool 必须实现的契约。
// 9 个方法全部必须实现——不通过 BaseTool 提供默认。这是有意为之：
// 每个 tool 的元数据都显式且可 grep。
//
// 并发说明：不再有 IsConcurrencySafe 方法。并行调度由 LLM 自报的
// "execution_group" 标准字段（StripStandardFields 提取）驱动。同 group =
// 并行 batch；不同 group = 升序串行。分批逻辑见 chat/tools.go。
type Tool interface {
	// ── Identity ──────────────────────────────────────────────────────────

	// Name returns the LLM-facing tool name (e.g. "search_forges").
	// Name 返回 LLM 看到的工具名（如 "search_forges"）。
	Name() string

	// Description tells the LLM what the tool does and when to use it.
	// Description 告诉 LLM 工具的作用和何时使用。
	Description() string

	// Parameters returns the JSON Schema describing the tool's input shape.
	// MUST NOT include "summary" or "destructive" — the framework injects them.
	//
	// Parameters 返回描述工具输入的 JSON Schema。
	// 不得包含 "summary" 或 "destructive"——框架自动注入。
	Parameters() json.RawMessage

	// ── Static metadata: properties of the tool itself ────────────────────

	// IsReadOnly reports whether this tool only reads state (no side effects).
	// True → safe to run concurrently with other read-only tools.
	//
	// IsReadOnly 报告本 tool 是否纯读（无副作用）。
	// true → 可与其他 read-only tool 并发。
	IsReadOnly() bool

	// NeedsReadFirst reports whether the file this tool operates on must have
	// been Read in this session before the tool can be invoked. Phase 5 Edit/Write.
	//
	// NeedsReadFirst 报告本 tool 操作的文件是否必须在 session 内被 Read 过。
	// Phase 5 Edit/Write 用。
	NeedsReadFirst() bool

	// RequiresWorkspace reports whether the tool's cwd must be inside the
	// user-configured workspace whitelist. Phase 5 Bash/Edit/Write.
	//
	// RequiresWorkspace 报告本 tool 的 cwd 是否必须在用户 workspace 白名单内。
	// Phase 5 Bash/Edit/Write 用。
	RequiresWorkspace() bool

	// ── Args-dependent hooks ──────────────────────────────────────────────

	// ValidateInput performs pre-Execute parameter validation. Return nil if
	// input is valid; an error halts the call before Execute (the error text
	// becomes the tool_result, fed back to the LLM).
	//
	// ValidateInput 在 Execute 前做参数级校验。返回 nil 表示通过；
	// 返错则不进 Execute，错误文本作为 tool_result 喂回 LLM。
	ValidateInput(args json.RawMessage) error

	// CheckPermissions decides if a call is allowed under the current mode.
	// Returns Allow / Deny / Ask. Forgify Phase 3 always passes mode=Default
	// and most tools return Allow; reserved for Phase 4+ workflow scheduler.
	//
	// CheckPermissions 决定当前 mode 下是否允许调用。返回 Allow / Deny / Ask。
	// Forgify Phase 3 一律传 mode=Default，多数 tool 返 Allow；
	// 保留位给 Phase 4+ workflow scheduler。
	CheckPermissions(args json.RawMessage, mode PermissionMode) PermissionResult

	// ── Main entry ────────────────────────────────────────────────────────

	// Execute runs the tool with stripped args (the three standard fields
	// "summary" / "destructive" / "execution_group" have been removed).
	// Returns the result string (fed back to LLM as tool_result) and an error.
	// If err != nil, the framework converts it to a failure tool_result.
	//
	// Execute 用剥除三个标准字段（"summary" / "destructive" / "execution_group"）
	// 的 args 执行。返回结果字符串（作为 tool_result 喂回 LLM）和 error。
	// err != nil 时框架转成失败 tool_result。
	Execute(ctx context.Context, argsJSON string) (string, error)
}

// ── LLM def conversion ────────────────────────────────────────────────────────

// ToLLMDef converts a Tool to the ToolDef sent to the LLM, automatically
// injecting "summary" and "destructive" fields into the Parameters schema.
//
// ToLLMDef 把 Tool 转成发给 LLM 的 ToolDef，自动注入 "summary" 和 "destructive" 字段。
func ToLLMDef(t Tool) llminfra.ToolDef {
	return llminfra.ToolDef{
		Name:        t.Name(),
		Description: t.Description(),
		Parameters:  injectStandardFields(t.Parameters()),
	}
}

// ToLLMDefs batch-converts a slice of Tools to ToolDefs.
//
// ToLLMDefs 批量转换 Tool 为 ToolDef。
func ToLLMDefs(tools []Tool) []llminfra.ToolDef {
	defs := make([]llminfra.ToolDef, len(tools))
	for i, t := range tools {
		defs[i] = ToLLMDef(t)
	}
	return defs
}

// ── injectStandardFields ──────────────────────────────────────────────────────

// injectStandardFields adds the three standard LLM-facing fields to the
// tool's Parameters schema:
//
//   - "summary"          required string — one-sentence description of this call
//   - "destructive"      optional bool   — flag for irreversible operations (UI badge)
//   - "execution_group"  optional int ≥1 — same group = parallel batch; missing
//     = framework auto-assigns a unique sequential group (run alone, after any
//     explicit groups). See chat/tools.go partition logic.
//
// If any field name is already present (implementation bug), it panics
// to fail fast at development time.
//
// injectStandardFields 向 tool 参数 schema 注入三个标准 LLM-facing 字段：
//
//   - "summary"          必填 string  —— 一句话描述本次调用
//   - "destructive"      可选 bool    —— 不可逆操作标记（UI 徽章）
//   - "execution_group"  可选 int ≥1  —— 同 group = 并行 batch；缺失 =
//     框架自动分配唯一串行 group（独自运行，且排在所有显式 group 之后）。
//     分批逻辑见 chat/tools.go。
//
// 任一字段名已被占用（实现 bug）直接 panic——开发期快速失败。
func injectStandardFields(params json.RawMessage) json.RawMessage {
	var schema map[string]json.RawMessage
	if err := json.Unmarshal(params, &schema); err != nil {
		panic(fmt.Sprintf("tool: parameters are not a valid JSON object: %v", err))
	}

	var props map[string]json.RawMessage
	if raw, ok := schema["properties"]; ok {
		if err := json.Unmarshal(raw, &props); err != nil {
			panic(fmt.Sprintf("tool: parameters.properties is not a valid JSON object: %v", err))
		}
		if _, conflict := props["summary"]; conflict {
			panic("tool: parameters already contain 'summary' field; rename to avoid conflict")
		}
		if _, conflict := props["destructive"]; conflict {
			panic("tool: parameters already contain 'destructive' field; rename to avoid conflict")
		}
		if _, conflict := props["execution_group"]; conflict {
			panic("tool: parameters already contain 'execution_group' field; rename to avoid conflict")
		}
	} else {
		props = map[string]json.RawMessage{}
	}

	props["summary"] = json.RawMessage(`{
		"type": "string",
		"description": "One sentence describing what you are doing and why. Required."
	}`)
	props["destructive"] = json.RawMessage(`{
		"type": "boolean",
		"description": "Set to true if this call may cause irreversible damage (rm -rf, DELETE FROM, git push --force, deleting forges, running forges that modify external state, etc.). The user will see a warning when true. Default false.",
		"default": false
	}`)
	props["execution_group"] = json.RawMessage(`{
		"type": "integer",
		"minimum": 1,
		"description": "Optional execution batch identifier. Tool calls with the same execution_group run in parallel; different groups run sequentially in ascending order. Set the same number on calls that have NO interdependence and NO shared mutable state (typical example: parallel git status + git diff + git log). If omitted, this call gets a unique sequential group — runs alone, after any explicit groups. When unsure, omit the field (sequential is always safe)."
	}`)

	propsRaw, err := json.Marshal(props)
	if err != nil {
		return params
	}
	schema["properties"] = propsRaw

	// Prepend "summary" to required so most LLMs output it first.
	// "destructive" stays optional (default false handles it).
	// Silent-parse of an existing malformed `required` would drop the tool
	// author's required field list and let the LLM skip required args —
	// match the surrounding panic-on-bad-schema policy at line 191/196/200.
	//
	// "summary" 排在 required 首位引导 LLM 优先输出；"destructive" 不必填，
	// 缺省 false。静默解析坏掉的现有 `required` 会丢失工具作者的必填字段表，
	// 让 LLM 跳过必填项——与 191/196/200 行的 panic-on-bad-schema 策略保持一致。
	var required []string
	if raw, ok := schema["required"]; ok {
		if err := json.Unmarshal(raw, &required); err != nil {
			panic(fmt.Sprintf("tool: parameters.required is not a valid JSON array of strings: %v", err))
		}
	}
	required = append([]string{"summary"}, required...)
	reqRaw, err := json.Marshal(required)
	if err != nil {
		return params
	}
	schema["required"] = reqRaw

	result, err := json.Marshal(schema)
	if err != nil {
		return params
	}
	return result
}

// ── StandardFields + StripStandardFields ──────────────────────────────────────

// StandardFields is the parsed form of the three framework-injected fields
// extracted by StripStandardFields. Fields stay zero-valued when absent or
// type-mismatched in the LLM's args (the tool's ValidateInput surfaces real
// problems back to the LLM).
//
// StandardFields 是 StripStandardFields 提取出的三个框架注入字段的解析结果。
// 字段在 LLM args 中缺失或类型不对时保持零值（真正的问题由 tool 的
// ValidateInput 反馈给 LLM）。
type StandardFields struct {
	// Summary is the LLM's one-sentence description of this call.
	// Empty when the LLM omitted it (a schema-required-field violation
	// the LLM should rarely commit).
	//
	// Summary 是 LLM 对本次调用的一句话描述。LLM 漏填时为空（schema 必填
	// 字段被违反，LLM 应该很少这么干）。
	Summary string

	// Destructive is the LLM's self-report that this call may cause
	// irreversible damage. Used by the UI to show a warning badge; not
	// enforced by the framework.
	//
	// Destructive 是 LLM 自报"本次调用可能不可逆破坏"。UI 据此显示警示
	// 徽章；框架不强制。
	Destructive bool

	// ExecutionGroup is the LLM's parallel-batch hint (≥1) for this call.
	// 0 means "missing/auto" — chat/tools.go's partition logic assigns a
	// unique sequential group to each 0-valued call (run alone, after any
	// explicit groups). Negative values are treated as 0.
	//
	// ExecutionGroup 是 LLM 自报的并行 batch 提示（≥1）。0 表示"缺失/自动"
	// ——chat/tools.go 的分批逻辑给每个 0 值调用分配唯一的串行 group
	// （独自运行，且排在所有显式 group 之后）。负值视同 0。
	ExecutionGroup int
}

// StripStandardFields extracts the three injected fields from argsJSON and
// returns them along with the JSON with all three fields removed.
// Missing fields default to zero values (empty Summary, false Destructive,
// zero ExecutionGroup which the partition layer treats as "auto"). Invalid
// JSON returns a zero StandardFields and the original argsJSON unchanged.
//
// StripStandardFields 从 argsJSON 中提取三个注入字段，返回它们和剥除三者
// 后的 JSON。字段缺失则取零值（Summary 空 / Destructive false /
// ExecutionGroup 0——分层逻辑会将其视为"auto"）。JSON 不合法时返回零值
// StandardFields 和原始 argsJSON。
func StripStandardFields(argsJSON string) (StandardFields, string) {
	var fields StandardFields
	var m map[string]json.RawMessage
	if err := json.Unmarshal([]byte(argsJSON), &m); err != nil {
		return fields, argsJSON
	}
	// LLM-produced args: if the LLM emits the wrong type (e.g. summary as
	// an int) the field stays zero. We deliberately don't return / log
	// here — the tool's ValidateInput will reject the malformed call with
	// a retry signal that propagates back to the LLM, which IS the surface.
	//
	// LLM 产出的 args：类型不对（如 summary 给成 int）字段保持零值。
	// 此处刻意不返错 / 不打日志——下游 tool 的 ValidateInput 会拒绝并以
	// 重试信号回到 LLM，那才是真正的暴露面。
	if raw, ok := m["summary"]; ok {
		_ = json.Unmarshal(raw, &fields.Summary)
		delete(m, "summary")
	}
	if raw, ok := m["destructive"]; ok {
		_ = json.Unmarshal(raw, &fields.Destructive)
		delete(m, "destructive")
	}
	if raw, ok := m["execution_group"]; ok {
		_ = json.Unmarshal(raw, &fields.ExecutionGroup)
		if fields.ExecutionGroup < 0 {
			fields.ExecutionGroup = 0 // negative → treat as missing
		}
		delete(m, "execution_group")
	}
	b, err := json.Marshal(m)
	if err != nil {
		return fields, argsJSON
	}
	return fields, string(b)
}
