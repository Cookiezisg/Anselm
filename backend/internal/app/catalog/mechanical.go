// mechanical.go — mechanicalFallback. The deterministic, no-LLM
// Catalog builder used when (a) Generator is nil (D8-2 default) or
// (b) Generator returned an error (LLM transport failed, coverage
// validation failed, etc.). Per catalog.md §7.5: sacrifices the
// LLM-inferred routing observations but guarantees full coverage —
// the demo never lands on "AI doesn't know forge X exists".
//
// mechanical.go ——mechanicalFallback。Generator nil（D8-2 默认）或返
// 错（LLM 传输失败 / coverage 校验失败等）时用的确定性无 LLM Catalog
// 构造。catalog.md §7.5：牺牲 LLM 推断的路由观察但保证全覆盖——demo
// 不会落到 "AI 不知道 forge X 存在"。
package catalog

import (
	"fmt"
	"sort"
	"strings"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
)

// mechanicalFallback enumerates per-source. Items grouped by Source,
// each source rendered as a Markdown subsection. Coverage map populated
// with every item ID (this is what the LLM Generator must produce
// validated; mechanical doesn't need validation since it literally
// lists every item).
//
// mechanicalFallback per-source 枚举。Item 按 Source 分组，每 source 一
// 个 Markdown 子段。Coverage map 含每个 item ID（LLM Generator 必须校
// 验产；mechanical 不需校验，因字面列出每个 item）。
func mechanicalFallback(items []catalogdomain.Item, gMap map[string]catalogdomain.Granularity) *catalogdomain.Catalog {
	bySource := groupBySource(items)
	sourceNames := make([]string, 0, len(bySource))
	for name := range bySource {
		sourceNames = append(sourceNames, name)
	}
	sort.Strings(sourceNames)

	var b strings.Builder
	coverage := map[string][]string{}

	b.WriteString("## Available capabilities\n")

	for _, name := range sourceNames {
		srcItems := bySource[name]
		// Sort items inside each source by Name for deterministic output —
		// callers diffing two consecutive catalogs (cold-start vs first
		// LLM gen) shouldn't see noise from map iteration order.
		// 每 source 内按 Name 排——调用方比对两版连续 catalog（cold-start
		// vs 首次 LLM 生成）不该见 map 迭代序噪音。
		sort.Slice(srcItems, func(i, j int) bool { return srcItems[i].Name < srcItems[j].Name })

		gran := gMap[name]
		fmt.Fprintf(&b, "\n### %s (%d, %s)\n", name, len(srcItems), gran.String())
		ids := make([]string, 0, len(srcItems))
		for _, it := range srcItems {
			desc := it.Description
			if desc == "" {
				desc = "(no description)"
			}
			fmt.Fprintf(&b, "- **%s**: %s\n", it.Name, desc)
			ids = append(ids, it.ID)
		}
		coverage[name] = ids
	}

	b.WriteString("\nIf a task could fit multiple categories, you MAY call multiple search tools in parallel.\n")

	return &catalogdomain.Catalog{
		Summary:     b.String(),
		Coverage:    coverage,
		GeneratedBy: "mechanical-fallback",
	}
}

// groupBySource buckets items by Source field. Empty result for empty
// input is fine — mechanicalFallback handles it as "header only" output.
//
// groupBySource 按 Source 字段分桶。空输入返空 ok——mechanicalFallback
// 当 "仅头部" 输出处理。
func groupBySource(items []catalogdomain.Item) map[string][]catalogdomain.Item {
	out := map[string][]catalogdomain.Item{}
	for _, it := range items {
		out[it.Source] = append(out[it.Source], it)
	}
	return out
}
