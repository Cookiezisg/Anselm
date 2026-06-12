package search

import (
	"strings"
	"unicode/utf8"
)

// minTrigramRunes is the trigram tokenizer's window: query tokens shorter than
// this can never match the FTS index (probed: 2-char CJK = 0 hits) and must
// route to LIKE instead.
//
// minTrigramRunes 是 trigram 分词窗口：短于它的 token 永远打不中 FTS 索引
// （探针实证：2 字中文 0 命中），必须改走 LIKE。
const minTrigramRunes = 3

// ParsedQuery is the §6.1 token routing result.
//
// ParsedQuery 是 §6.1 token 路由结果。
type ParsedQuery struct {
	Long  []string
	Short []string
}

// ParseQuery splits q on whitespace and routes each token by rune length.
// FTS5 operator characters survive here — BuildMatch neutralizes them by
// quoting, LIKE escaping happens in the store.
//
// ParseQuery 按空白切分并按 rune 长度路由。FTS5 运算符字符在此保留——BuildMatch
// 用引号中和，LIKE 转义在 store 做。
func ParseQuery(q string) ParsedQuery {
	var p ParsedQuery
	for tok := range strings.FieldsSeq(q) {
		if utf8.RuneCountInString(tok) >= minTrigramRunes {
			p.Long = append(p.Long, tok)
		} else {
			p.Short = append(p.Short, tok)
		}
	}
	return p
}

// BuildMatch renders long tokens as an implicit-AND FTS5 MATCH string. Each
// token is double-quoted (embedded quotes doubled) so user input can never be
// parsed as MATCH syntax — phrase semantics under trigram = substring match.
//
// BuildMatch 把长 token 渲染为隐式 AND 的 FTS5 MATCH 串。每个 token 双引号包裹
// （内嵌引号翻倍），用户输入永远不会被当作 MATCH 语法——trigram 下短语语义即子串匹配。
func BuildMatch(longTokens []string) string {
	quoted := make([]string, 0, len(longTokens))
	for _, t := range longTokens {
		quoted = append(quoted, `"`+strings.ReplaceAll(t, `"`, `""`)+`"`)
	}
	return strings.Join(quoted, " ")
}

// RefHint renders the workflow wiring ref for a block hit; content kinds return
// "" — the search box shows them, the palette never does.
//
// RefHint 渲染积木命中的 workflow 接线 ref；内容类返回 ""——综搜展示它们，积木面板从不。
func RefHint(t EntityType, entityID, anchor string) string {
	switch t {
	case TypeFunction, TypeAgent, TypeControl, TypeApproval:
		return entityID
	case TypeHandler:
		if anchor == "" {
			return entityID
		}
		return entityID + "." + anchor
	case TypeMCP:
		if anchor == "" {
			return ""
		}
		return "mcp:" + entityID + "/" + anchor
	}
	return ""
}
