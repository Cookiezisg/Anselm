package catalog

import (
	"fmt"
	"sort"
	"strings"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
)

// descMaxRunes caps each description so one verbose entry can't blow up the prompt.
//
// descMaxRunes 限每条描述长度，防某条啰嗦描述撑大 prompt。
const descMaxRunes = 48

// assemble groups items by kind into a Markdown overview: a header per kind, a
// "- name: desc" line per entity. No ids, no invoke tools — to actually use a
// capability the LLM searches for it. Coverage records source→ids for the
// structured HTTP view (not rendered into Summary).
//
// assemble 按类型把 item 分组成 Markdown 概览：每类型一个 header，每实体一行
// "- name: desc"。无 id、无调用工具——真要用某能力，LLM 去搜。Coverage 记 source→ids
// 供结构化 HTTP 视图（不渲染进 Summary）。
func assemble(items []catalogdomain.Item) *catalogdomain.Catalog {
	bySource := map[string][]catalogdomain.Item{}
	for _, it := range items {
		bySource[it.Source] = append(bySource[it.Source], it)
	}
	kinds := make([]string, 0, len(bySource))
	for k := range bySource {
		kinds = append(kinds, k)
	}
	sort.Strings(kinds)

	var b strings.Builder
	coverage := map[string][]string{}

	// Empty library: emit nothing, so a brand-new workspace gets no awkward header
	// over a blank section.
	// 空库:不输出，使全新 workspace 不出现 header 下空白怪态。
	if len(items) > 0 {
		b.WriteString("You currently have these capabilities (to use one, search with the matching tool):\n")
		for _, kind := range kinds {
			group := bySource[kind]
			sort.Slice(group, func(i, j int) bool { return group[i].Name < group[j].Name })
			fmt.Fprintf(&b, "\n### %s\n", kind)
			ids := make([]string, 0, len(group))
			for _, it := range group {
				desc := truncate(strings.TrimSpace(it.Description), descMaxRunes)
				fmt.Fprintf(&b, "- **%s**: %s\n", it.Name, desc)
				ids = append(ids, it.ID)
			}
			coverage[kind] = ids
		}
	}
	return &catalogdomain.Catalog{Summary: b.String(), Coverage: coverage}
}

// truncate caps s to max runes, appending "…" when cut; rune-safe.
//
// truncate 按 rune 截 s 到 max 个，截断时追加"…"；多字节安全。
func truncate(s string, max int) string {
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	return string(r[:max]) + "…"
}
