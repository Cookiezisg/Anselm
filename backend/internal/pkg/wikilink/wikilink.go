// Package wikilink parses [[<prefix>_<16hex>]] wikilinks from markdown bodies.
//
// Package wikilink 从 markdown body 抽取 [[<prefix>_<16hex>]] 形式 wikilink。
package wikilink

import (
	"regexp"

	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
)

// ParsedRef is one resolved wikilink with how many times it appears in the body.
//
// ParsedRef 是一条解析出来的 wikilink，附带在 body 中出现次数。
type ParsedRef struct {
	Kind  string
	ID    string
	Count int
}

// wikiRe matches [[<prefix>_<16 hex chars>]] — strict to project ID format.
//
// wikiRe 匹配 [[<prefix>_<16 位 hex>]]——严格匹配项目 ID 格式。
var wikiRe = regexp.MustCompile(`\[\[([a-z]+_[0-9a-f]{16})\]\]`)

// Parse scans body for wikilink references and returns dedup'd [{kind, id, count}].
// Unknown ID prefixes (not in idgenpkg.KindByPrefix) are silently dropped.
//
// Parse 扫描 body 中的 wikilink 引用并返 dedup 后 [{kind, id, count}]。
// 未在 idgenpkg.KindByPrefix 注册的前缀会被静默丢弃。
func Parse(body string) []ParsedRef {
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
	out := make([]ParsedRef, 0, len(counts))
	for id, count := range counts {
		kind, ok := idgenpkg.KindForID(id)
		if !ok {
			continue
		}
		out = append(out, ParsedRef{Kind: kind, ID: id, Count: count})
	}
	return out
}
