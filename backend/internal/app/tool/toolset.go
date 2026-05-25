package tool

// Toolset partitions system tools into always-present resident tools and lazily-loaded groups.
// chat host.Tools(ctx) returns resident + the lazy groups the conversation activated via
// activate_tools; All() (full flattened set) is reserved for the §18 inventory handlers.
//
// Toolset 把系统工具分成常驻 resident 和按需加载的 lazy 组。
// chat host.Tools(ctx) 返 resident + 本对话经 activate_tools 激活的 lazy 组；
// All()（全集展平）留给 §18 总览 handler。
type Toolset struct {
	// Resident tools are always present in every LLM turn.
	Resident []Tool
	// Lazy maps category name → tools only loaded after activate_tools calls ActivateGroup.
	Lazy map[string][]Tool
}

// All returns Resident + all Lazy groups flattened; order: resident first, then lazy by insertion
// order of the map (undefined in Go, but stable-enough for tests that check the set not the order).
//
// All 返回 Resident + 所有 Lazy 组展开；resident 优先，lazy 顺序不定（Go map 无序）。
func (ts Toolset) All() []Tool {
	total := len(ts.Resident)
	for _, v := range ts.Lazy {
		total += len(v)
	}
	out := make([]Tool, 0, total)
	out = append(out, ts.Resident...)
	for _, group := range ts.Lazy {
		out = append(out, group...)
	}
	return out
}
