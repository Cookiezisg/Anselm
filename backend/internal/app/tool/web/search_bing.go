// search_bing.go — Bing HTML parser used by both Tier-2 (www.bing.com)
// and Tier-3 (cn.bing.com) backends. Both share the same DOM shape:
//
//	<li class="b_algo">
//	  <h2><a href="URL">TITLE</a></h2>
//	  <div class="b_caption"><p>SNIPPET</p></div>
//	</li>
//
// We walk the parsed tree with a small visitor instead of regex so that
// future Bing tweaks (extra wrapper divs, attribute reorderings) don't
// silently break extraction.
//
// search_bing.go — Bing HTML 解析器，Tier-2（www.bing.com）与 Tier-3
// （cn.bing.com）共用。两者 DOM 形状相同，用 visitor 走解析树而非 regex，
// 避免 Bing 加包装 div / 改属性顺序时静默失效。
package web

import (
	"strings"

	"golang.org/x/net/html"
)

// parseBingHTML extracts (title, url, snippet) tuples from a Bing search
// result page. Best-effort: malformed entries are skipped silently so a
// single bad block does not lose the whole result list.
//
// parseBingHTML 从 Bing 搜索结果页提取 (title, url, snippet) 三元组。
// 尽力而为；坏的条目静默跳过，免得一坏全失。
func parseBingHTML(body string) ([]searchResult, error) {
	doc, err := html.Parse(strings.NewReader(body))
	if err != nil {
		return nil, err
	}
	var out []searchResult
	walkBing(doc, &out)
	return out, nil
}

// walkBing descends the document, collecting one searchResult per
// `<li class="b_algo">` block.
//
// walkBing 下降文档，每个 `<li class="b_algo">` 块产出一条 searchResult。
func walkBing(n *html.Node, out *[]searchResult) {
	if n.Type == html.ElementNode && n.Data == "li" && hasClass(n, "b_algo") {
		if r, ok := extractBingBlock(n); ok {
			*out = append(*out, r)
		}
		// Don't descend into a result block — its anchors would
		// otherwise be re-collected by subsequent passes.
		// 不下钻结果块——内部 anchor 否则会被重复收集。
		return
	}
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		walkBing(c, out)
	}
}

// extractBingBlock pulls the title/url/snippet out of one b_algo subtree.
// Returns ok=false when no usable URL was found.
//
// extractBingBlock 从一个 b_algo 子树取 title/url/snippet。
// 找不到可用 URL 即返 ok=false。
func extractBingBlock(li *html.Node) (searchResult, bool) {
	var r searchResult

	// Title + URL: first <h2><a href> we find inside the li.
	// title + url：li 内首个 <h2><a href>。
	h2 := findFirstByTag(li, "h2")
	if h2 != nil {
		if a := findFirstByTag(h2, "a"); a != nil {
			r.URL = strings.TrimSpace(getAttr(a, "href"))
			r.Title = collapseSpaces(textOf(a))
		}
	}
	// Snippet: first <p> inside any "b_caption" descendant; falls back to
	// the first <p> if Bing dropped that wrapper class.
	// snippet：先 b_caption 后代里的首个 <p>；Bing 去掉该包装类时 fallback
	// 到任意首个 <p>。
	if caption := findFirstByClass(li, "b_caption"); caption != nil {
		if p := findFirstByTag(caption, "p"); p != nil {
			r.Snippet = collapseSpaces(textOf(p))
		}
	}
	if r.Snippet == "" {
		if p := findFirstByTag(li, "p"); p != nil {
			r.Snippet = collapseSpaces(textOf(p))
		}
	}
	if r.URL == "" {
		return searchResult{}, false
	}
	return r, true
}

// ── Tiny HTML walking helpers (kept local — no x/net/html/atom needed) ────────

func hasClass(n *html.Node, want string) bool {
	for _, attr := range n.Attr {
		if attr.Key != "class" {
			continue
		}
		for _, c := range strings.Fields(attr.Val) {
			if c == want {
				return true
			}
		}
	}
	return false
}

func getAttr(n *html.Node, key string) string {
	for _, a := range n.Attr {
		if a.Key == key {
			return a.Val
		}
	}
	return ""
}

func findFirstByTag(n *html.Node, tag string) *html.Node {
	if n == nil {
		return nil
	}
	if n.Type == html.ElementNode && n.Data == tag {
		return n
	}
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		if got := findFirstByTag(c, tag); got != nil {
			return got
		}
	}
	return nil
}

func findFirstByClass(n *html.Node, class string) *html.Node {
	if n == nil {
		return nil
	}
	if n.Type == html.ElementNode && hasClass(n, class) {
		return n
	}
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		if got := findFirstByClass(c, class); got != nil {
			return got
		}
	}
	return nil
}

// textOf concatenates all descendant text nodes.
//
// textOf 拼接所有后代文本节点。
func textOf(n *html.Node) string {
	if n == nil {
		return ""
	}
	if n.Type == html.TextNode {
		return n.Data
	}
	var sb strings.Builder
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		sb.WriteString(textOf(c))
	}
	return sb.String()
}

// collapseSpaces trims and collapses inner runs of whitespace to single
// spaces — Bing's snippets often arrive with embedded `\n` and tabs.
//
// collapseSpaces trim + 把内部连续空白压成单空格——Bing snippet 常含 `\n` / tab。
func collapseSpaces(s string) string {
	return strings.Join(strings.Fields(s), " ")
}
