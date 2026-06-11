package tool

// Toolset partitions system tools into always-present resident tools and lazy
// tools surfaced on demand. Resident tools' full definitions are in every LLM
// turn. Lazy tools are NOT in context by default — only a one-line overview
// (name + Description) is shown (the host injects it into the system prompt);
// the LLM calls search_tools to pull a lazy tool's full definition (including its
// large Parameters schema) when it needs it. This caps prompt tokens: N lazy
// tools cost N overview lines, not N full schemas.
//
// The overview (so the LLM knows the full lazy inventory and never blind-searches),
// search_tools, and the per-conversation "discovered" set are assembled by chat
// (M5.2); this struct is the partition plus the overview projection.
//
// Toolset 把系统工具分成常驻 resident 与按需浮出的 lazy。Resident 完整定义每回合都在。
// Lazy 默认不在 context——只展示一行概览（name + Description，host 注入 system prompt）；
// LLM 需要时调 search_tools 取某 lazy 工具的完整定义（含它的大 Parameters schema）。这给
// prompt token 设上限：N 个 lazy 工具只花 N 行概览，而非 N 份完整 schema。
//
// 概览（使 LLM 知道 lazy 全集、永不盲搜）、search_tools、每对话"已发现"集由 chat（M5.2）组装；
// 本结构是那份划分 + 概览投影。
type Toolset struct {
	// Resident tools' full definitions are present in every LLM turn.
	//
	// Resident 工具完整定义每回合都在。
	Resident []Tool

	// Lazy tools appear only as a one-line overview until search_tools pulls a tool's full definition.
	//
	// Lazy 工具只以一行概览出现，直到 search_tools 拉取某工具完整定义。
	Lazy []Tool
}

// ToolBrief is one line of the lazy-tool overview: name + one-line description,
// without the Parameters schema. The host renders these into the system prompt so
// the LLM knows the full lazy inventory (avoiding blind search) while the large
// Parameters schemas stay out of context until needed.
//
// ToolBrief 是 lazy 工具概览的一行：name + 一句话 description，不含 Parameters schema。host 把
// 它们渲进 system prompt，使 LLM 知道 lazy 全集（避免盲搜）、而大 Parameters schema 在需要前不进 context。
type ToolBrief struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

// Overview projects each lazy tool to a ToolBrief (name + one-line Description) —
// the catalog card the host injects so the LLM sees what's on the shelf without
// the full schemas.
//
// Overview 把每个 lazy 工具投影成 ToolBrief（name + 一句话 Description）——host 注入的目录卡，
// 使 LLM 看见书架上有什么、而不含完整 schema。
func (ts Toolset) Overview() []ToolBrief {
	out := make([]ToolBrief, 0, len(ts.Lazy))
	for _, t := range ts.Lazy {
		out = append(out, ToolBrief{Name: t.Name(), Description: t.Description()})
	}
	return out
}

// FindLazy returns the lazy tool with the given name, or nil — used by search_tools
// to return a matched tool's full definition.
//
// FindLazy 返回指定名的 lazy 工具，无则 nil——供 search_tools 返回命中工具的完整定义。
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
