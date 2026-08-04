package tool

import (
	"encoding/json"
	"sort"
	"strings"
)

// Toolset partitions system tools into always-present resident tools and lazy
// tools activated on demand. Resident tools' full definitions are in every LLM
// turn. Lazy tools are NOT in context by default — only a one-line overview
// (name + Description) is shown (the host injects it into the system prompt);
// the LLM calls search_tools to activate a lazy tool when it needs it, and its
// large Parameters schema appears in the next request's tools field. This caps
// prompt tokens: N inactive tools cost N compact overview lines, not N schemas.
//
// The overview (so the LLM knows the full lazy inventory and never blind-searches),
// search_tools, and the per-conversation "discovered" set are assembled by chat;
// this struct is the partition plus the overview projection.
//
// Toolset 把系统工具分成常驻 resident 与按需激活的 lazy。Resident 完整定义每回合都在。
// Lazy 默认不在 context——只展示一行概览（name + Description，host 注入 system prompt）；
// LLM 需要时调 search_tools 激活，下一请求 tools 字段才出现其完整 schema。这给 prompt token
// 设上限：N 个未激活工具只花 N 行紧凑概览，而非 N 份完整 schema。
//
// 概览（使 LLM 知道 lazy 全集、永不盲搜）、search_tools、每对话"已发现"集由 chat 组装；
// 本结构是那份划分 + 概览投影。
type Toolset struct {
	// Resident tools' full definitions are present in every LLM turn.
	//
	// Resident 工具完整定义每回合都在。
	Resident []Tool

	// Lazy tools appear only as a one-line overview until search_tools activates them.
	//
	// Lazy 工具只以一行概览出现，直到 search_tools 激活该工具。
	Lazy []Tool
}

// ToolBrief is one line of the lazy-tool overview: name + required/optional arg names + one-line
// description (NOT the full Parameters schema). The host renders these into the system prompt as
// name(required; optional: ...): purpose, so the LLM knows the full lazy inventory AND the usable
// arg keys without activating the full schema first. This prevents a first call with defaults
// followed by a corrective second call when the user explicitly supplied an optional bound.
//
// ToolBrief 是 lazy 工具概览的一行：name + 必填/可选参数名 + 一句话 description（**非**完整 Parameters
// schema）。host 渲成 name(required; optional: ...): purpose，使 LLM 在激活完整 schema 前也知道可用参数键，
// 避免用户已经给出可选边界时先按默认值执行、再补一次调用；大 schema 仍不进 context。
type ToolBrief struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	// Params names the tool's REQUIRED business args (not the full schema) so the overview line
	// reads name(args): purpose — the LLM then calls with the right keys without first search_tools-ing
	// the full schema (a wrong-key guess otherwise costs a failed call + a recovery round-trip).
	//
	// Params 点名工具的**必填**业务参数（非全 schema），使概览行成 name(args): purpose——LLM 不必先
	// search_tools 取全 schema 就能用对参数键（否则猜错键 = 一次失败调用 + 一个恢复回合）。
	Params []string `json:"params,omitempty"`
	// OptionalParams names optional properties as a compact schema hint. Defaults and validation
	// details remain in Parameters; this field only prevents optional user constraints from being
	// invisible in the lazy overview.
	//
	// OptionalParams 点名可选属性作为紧凑 schema 提示。默认值与校验细节仍在 Parameters；这里只防止用户
	// 明确给出的可选约束在 lazy 概览中消失。
	OptionalParams []string `json:"optionalParams,omitempty"`
}

// Overview projects each lazy tool to a ToolBrief (name + required/optional arg names + one-line
// Description) — the catalog card the host injects so the LLM sees what's on the shelf and which
// keys are available, without the full schemas.
//
// Overview 把每个 lazy 工具投影成 ToolBrief（name + 必填/可选参数名 + 一句话 Description）——host 注入的目录卡，
// 使 LLM 看见书架上有什么、有哪些参数，而不含完整 schema。
func (ts Toolset) Overview() []ToolBrief {
	out := make([]ToolBrief, 0, len(ts.Lazy))
	for _, t := range ts.Lazy {
		required, optional := parameterNames(t.Parameters())
		out = append(out, ToolBrief{
			Name:           t.Name(),
			Description:    BriefDescription(t.Description(), 180),
			Params:         required,
			OptionalParams: optional,
		})
	}
	return out
}

// parameterNames extracts required parameters in schema order and optional properties in stable
// lexical order. The distinction is intentional: required names belong in the call signature,
// while optional names are a compact hint that preserves default semantics.
//
// parameterNames 从工具 Parameters schema 提取必填（保 schema 顺序）与可选（稳定字典序）参数名。
func parameterNames(params json.RawMessage) (required, optional []string) {
	var p struct {
		Required   []string                   `json:"required"`
		Properties map[string]json.RawMessage `json:"properties"`
	}
	if json.Unmarshal(params, &p) != nil {
		return nil, nil
	}
	requiredSet := make(map[string]struct{}, len(p.Required))
	for _, name := range p.Required {
		requiredSet[name] = struct{}{}
	}
	optional = make([]string, 0, len(p.Properties))
	for name := range p.Properties {
		if _, ok := requiredSet[name]; !ok {
			optional = append(optional, name)
		}
	}
	sort.Strings(optional)
	return p.Required, optional
}

// FindLazy returns the lazy tool with the given name, or nil — used by host
// auto-activation and discovery.
//
// FindLazy 返回指定名的 lazy 工具，无则 nil——供 host 自动激活与发现。
func (ts Toolset) FindLazy(name string) Tool {
	for _, t := range ts.Lazy {
		if t.Name() == name {
			return t
		}
	}
	return nil
}

// All returns Resident followed by Lazy flattened — the full inventory, for a
// tools-overview handler.
//
// All 返回 Resident 后接 Lazy 展平——全量清单，给工具总览 handler。
func (ts Toolset) All() []Tool {
	out := make([]Tool, 0, len(ts.Resident)+len(ts.Lazy))
	out = append(out, ts.Resident...)
	out = append(out, ts.Lazy...)
	return out
}

// Descriptor is one authorizable tool's catalog entry: its call [Name] plus a short one-line
// [Summary] for a picker. danger / execution_group are per-call LLM self-declarations (§S18),
// NOT static tool properties, so they are intentionally absent — the catalog answers "which
// tools exist to pre-authorize (a skill's allowed-tools)", not "how risky each is".
//
// Descriptor 是一个可授权工具的目录条目：调用名 [Name] + 一行简述 [Summary](供选择器)。
// danger / execution_group 是 LLM 逐次自报(S18)、非静态工具属性，故刻意不含——目录回答
// 「有哪些工具可预授权(skill 的 allowed-tools)」，非「各自多危险」。
type Descriptor struct {
	Name    string `json:"name"`
	Summary string `json:"summary"`
}

// Catalog projects the whole toolset (resident + lazy) into authorizable-tool descriptors, sorted
// by name for a stable picker — the full builtin inventory a skill's allowed-tools can pre-authorize
// (entity ids and MCP tools are picked from their own live sources, not this static set).
//
// Catalog 把整个工具集(resident + lazy)投影成可授权工具目录、按名排序(选择器稳定)——skill 的
// allowed-tools 可预授权的内置全集(实体 id 与 MCP 工具从各自的活来源挑，不在这份静态集里)。
func (ts Toolset) Catalog() []Descriptor {
	all := ts.All()
	out := make([]Descriptor, 0, len(all))
	for _, t := range all {
		out = append(out, Descriptor{Name: t.Name(), Summary: BriefDescription(t.Description(), 200)})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out
}

// BriefDescription takes a tool Description's first line, trimmed and rune-capped to n (with an
// ellipsis) — a lazy tool's Description "may be large" (kept out of context on purpose), and a
// human picking a tool needs a hint, not the full usage doc. 取 Description 首行、截断 n 符：
// lazy 工具描述可能很大(刻意不进 context)，选工具的人要提示、非完整用法文档。
func BriefDescription(s string, n int) string {
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		s = s[:i]
	}
	s = strings.TrimSpace(s)
	if r := []rune(s); len(r) > n {
		return strings.TrimSpace(string(r[:n])) + "…"
	}
	return s
}
