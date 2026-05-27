package catalog

import (
	"fmt"
	"sort"
	"strings"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
)

const descMaxRunes = 48

// assemble enumerates items per-source into a Markdown capability "menu": each
// group header names the invoke tool so the LLM knows exactly what to call.
//
// assemble 按 source 把 item 拼成 Markdown 能力菜单；
// header 带 invokeTool 让 LLM 知道该发哪个 tool-call。
func assemble(items []catalogdomain.Item, gMap map[string]catalogdomain.Granularity, invokeMap map[string]string) *catalogdomain.Catalog {
	bySource := groupBySource(items)
	sourceNames := make([]string, 0, len(bySource))
	for name := range bySource {
		sourceNames = append(sourceNames, name)
	}
	sort.Strings(sourceNames)

	var b strings.Builder
	coverage := map[string][]string{}

	// Empty library: skip the section entirely (no awkward header-then-blank
	// when the user has not forged anything yet).
	// 空库:跳整段(用户还没锻造时避免 header 下空白怪态)。
	if len(items) > 0 {
		for _, name := range sourceNames {
			srcItems := bySource[name]
			sort.Slice(srcItems, func(i, j int) bool { return srcItems[i].Name < srcItems[j].Name })

			invoke := invokeMap[name]
			fmt.Fprintf(&b, "\n### %s [%s]\n", name, invoke)
			ids := make([]string, 0, len(srcItems))
			for _, it := range srcItems {
				desc := truncate(it.Description, descMaxRunes)
				if desc == "" {
					desc = "(no description)"
				}
				fmt.Fprintf(&b, "- **%s**: %s\n", it.Name, desc)
				ids = append(ids, it.ID)
			}
			coverage[name] = ids
		}

		b.WriteString("\nIf a task could fit multiple categories, you MAY call multiple search tools in parallel.\n")
	}

	return &catalogdomain.Catalog{
		Summary:     b.String(),
		Coverage:    coverage,
		GeneratedBy: "mechanical",
	}
}

// truncate cuts s to max runes and appends "…" if cut; rune-safe.
//
// truncate 按 rune 截断 s 到 max 个并追加"…"；多字节安全。
func truncate(s string, max int) string {
	runes := []rune(s)
	if len(runes) <= max {
		return s
	}
	return string(runes[:max]) + "…"
}

func groupBySource(items []catalogdomain.Item) map[string][]catalogdomain.Item {
	out := map[string][]catalogdomain.Item{}
	for _, it := range items {
		out[it.Source] = append(out[it.Source], it)
	}
	return out
}
