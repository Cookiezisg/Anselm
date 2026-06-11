// Package wikilink extracts [[<prefix>_<16hex>]] wikilink references from markdown bodies.
//
// Package wikilink 从 markdown body 抽取 [[<prefix>_<16hex>]] 形式的 wikilink 引用。
package wikilink

import "regexp"

// Ref is one wikilink reference with how many times it appears in the body.
// Resolving the prefix to an entity kind is the caller's job — relation domain
// owns the prefix → EntityKind table, so wikilink stays a pure text extractor.
//
// Ref 是一条 wikilink 引用，附带在 body 中的出现次数。把前缀解析成实体类型是调用方的事
// ——relation domain 持有「前缀 → EntityKind」表，wikilink 只做纯文本抽取。
type Ref struct {
	ID    string
	Count int
}

// wikiRe matches [[<prefix>_<16 hex chars>]] — strict to the project ID format.
//
// wikiRe 匹配 [[<prefix>_<16 位 hex>]]——严格匹配项目 ID 格式。
var wikiRe = regexp.MustCompile(`\[\[([a-z]+_[0-9a-f]{16})\]\]`)

// Parse scans body for wikilink references and returns dedup'd [{id, count}].
// It does NOT validate the prefix against known entities — any ID-shaped token
// is returned; the caller filters by resolving the prefix to an entity kind.
//
// Parse 扫描 body 中的 wikilink 引用并返 dedup 后 [{id, count}]。
// 不校验前缀是否为已知实体——任何 ID 形态的 token 都返回；由调用方按前缀解析来过滤。
func Parse(body string) []Ref {
	if body == "" {
		return nil
	}
	matches := wikiRe.FindAllStringSubmatch(body, -1)
	if len(matches) == 0 {
		return nil
	}
	counts := make(map[string]int)
	for _, m := range matches {
		counts[m[1]]++
	}
	out := make([]Ref, 0, len(counts))
	for id, count := range counts {
		out = append(out, Ref{ID: id, Count: count})
	}
	return out
}
