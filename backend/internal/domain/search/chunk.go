package search

import (
	"strings"

	tokencountpkg "github.com/sunweilin/forgify/backend/internal/pkg/tokencount"
)

// Chunking targets: ~512 estimated tokens per chunk with ~10% line overlap so a
// phrase straddling a boundary still matches somewhere; 8 KiB runes is the hard
// cap bounding index size against pathological single lines.
//
// 分块目标：每块约 512 估算 token、行级 ~10% 重叠（跨界短语总能在某块命中）；
// 8 KiB rune 硬上限对病态长行兜底、约束索引体积。
const (
	chunkTargetTokens = 512
	chunkHardCapRunes = 8192
)

// CapRunes truncates s to the chunk hard cap.
//
// CapRunes 把 s 截断到分块硬上限。
func CapRunes(s string) string {
	r := []rune(s)
	if len(r) <= chunkHardCapRunes {
		return s
	}
	return string(r[:chunkHardCapRunes])
}

// SplitPlain splits text into ~target-token chunks on line boundaries with one
// line of overlap — for code and long prose without heading structure.
//
// SplitPlain 按行边界把文本切成约 target token 的块、相邻块重叠一行——用于代码与无
// 标题结构的长文。
func SplitPlain(text string) []string {
	text = strings.TrimSpace(text)
	if text == "" {
		return nil
	}
	if tokencountpkg.Estimate(text) <= chunkTargetTokens {
		return []string{CapRunes(text)}
	}
	lines := strings.Split(text, "\n")
	var chunks []string
	var cur []string
	curTokens := 0
	flush := func() {
		if len(cur) == 0 {
			return
		}
		chunks = append(chunks, CapRunes(strings.Join(cur, "\n")))
		// Overlap: carry the last line into the next chunk.
		// 重叠：把末行带进下一块。
		last := cur[len(cur)-1]
		cur = []string{last}
		curTokens = tokencountpkg.Estimate(last)
	}
	for _, ln := range lines {
		lnTokens := tokencountpkg.Estimate(ln)
		if curTokens+lnTokens > chunkTargetTokens && curTokens > 0 {
			flush()
		}
		cur = append(cur, ln)
		curTokens += lnTokens
	}
	if len(cur) > 1 || len(chunks) == 0 {
		chunks = append(chunks, CapRunes(strings.Join(cur, "\n")))
	}
	return chunks
}

// MDChunk is one heading-aware markdown chunk; Anchor is the heading chain
// ("概述 > 安装") used as the jump target.
//
// MDChunk 是一个标题感知的 markdown 块；Anchor 是标题链（「概述 > 安装」）作跳转锚。
type MDChunk struct {
	Anchor string
	Body   string
}

// SplitMarkdown splits on ATX headings and keeps each section under the token
// target (oversized sections re-split via SplitPlain, sharing the anchor).
//
// SplitMarkdown 按 ATX 标题切分，并把每节压在 token 目标内（超大节经 SplitPlain
// 再切、共享同一锚）。
func SplitMarkdown(text string) []MDChunk {
	text = strings.TrimSpace(text)
	if text == "" {
		return nil
	}
	type section struct {
		anchor string
		lines  []string
	}
	var sections []section
	cur := section{}
	chain := []string{}
	for _, ln := range strings.Split(text, "\n") {
		trimmed := strings.TrimSpace(ln)
		if level := headingLevel(trimmed); level > 0 {
			if len(cur.lines) > 0 {
				sections = append(sections, cur)
			}
			title := strings.TrimSpace(strings.TrimLeft(trimmed, "# "))
			if level-1 < len(chain) {
				chain = chain[:level-1]
			}
			chain = append(chain, title)
			cur = section{anchor: strings.Join(chain, " > ")}
			continue
		}
		cur.lines = append(cur.lines, ln)
	}
	if len(cur.lines) > 0 || len(sections) == 0 {
		sections = append(sections, cur)
	}
	var out []MDChunk
	for _, sec := range sections {
		body := strings.TrimSpace(strings.Join(sec.lines, "\n"))
		if body == "" && sec.anchor == "" {
			continue
		}
		for _, part := range SplitPlain(body) {
			out = append(out, MDChunk{Anchor: sec.anchor, Body: part})
		}
		if body == "" && sec.anchor != "" {
			out = append(out, MDChunk{Anchor: sec.anchor, Body: ""})
		}
	}
	return out
}

func headingLevel(line string) int {
	if !strings.HasPrefix(line, "#") {
		return 0
	}
	n := 0
	for n < len(line) && line[n] == '#' {
		n++
	}
	if n > 6 || n >= len(line) || line[n] != ' ' {
		return 0
	}
	return n
}
