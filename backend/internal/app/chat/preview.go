package chat

import (
	"strings"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
)

// previewMaxRunes caps the conversation-list rail snippet length, counted in RUNES not bytes so a
// CJK message is never cut mid-character. 预览最大 rune 数(按 rune 非 byte 计,CJK 不切半字)。
const previewMaxRunes = 120

// previewFrom builds a one-line rail snippet from raw message text: collapse every run of whitespace
// (including newlines) to a single space and trim, then rune-truncate to previewMaxRunes with an
// ellipsis. Empty in → empty out — the caller (TouchLastMessage) treats an empty preview as "keep the
// existing one" (an attachment-only / tool-only turn leaves the last meaningful snippet in place).
//
// previewFrom 从原始消息文本构一行 rail 摘要:把所有连续空白(含换行)折成单空格并 trim,再按 rune 截到
// previewMaxRunes 加省略号。空入 → 空出——调用方(TouchLastMessage)视空为「保留原预览」(附件-only / 纯工具回合
// 保留上一条有意义摘要)。
func previewFrom(text string) string {
	s := strings.Join(strings.Fields(text), " ") // Fields splits on + collapses all whitespace, and trims
	if s == "" {
		return ""
	}
	r := []rune(s)
	if len(r) > previewMaxRunes {
		return string(r[:previewMaxRunes]) + "…"
	}
	return s
}

// previewFromBlocks builds the rail snippet from an assistant message's blocks — ONLY BlockTypeText
// content is used. reasoning / tool_call / tool_result blocks are deliberately excluded so the
// preview never leaks chain-of-thought or tool arguments. Empty when the message carries no text (a
// pure tool turn) → the caller keeps the prior (user-side) preview.
//
// previewFromBlocks 从 assistant 消息的 blocks 构 rail 摘要——只用 BlockTypeText 内容。reasoning / tool_call /
// tool_result 块刻意排除,使预览绝不泄露思维链或工具参数。无文本(纯工具回合)时为空 → 调用方保留上一条(用户侧)预览。
func previewFromBlocks(blocks []messagesdomain.Block) string {
	var sb strings.Builder
	for _, b := range blocks {
		if b.Type != messagesdomain.BlockTypeText {
			continue
		}
		if sb.Len() > 0 {
			sb.WriteByte(' ')
		}
		sb.WriteString(b.Content)
	}
	return previewFrom(sb.String())
}
