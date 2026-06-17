package contextmgr

import (
	"fmt"
	"strings"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
)

// summarySystemPrompt instructs the utility model to maintain a RUNNING summary: extend the
// prior summary with the new span rather than rewrite it (incremental, bounded cost), and
// preserve the high-signal facts a post-compaction agent must not lose — decisions, open items,
// next steps, user preferences, and file/entity references (losing those forces expensive
// re-reads). Must-follow rules are NOT summarized here — they live in the system prompt, re-sent
// every turn — so this stays episodic.
//
// summarySystemPrompt 指示 utility 模型维护一份**滚动** summary：用新 span 扩展旧摘要而非重写（增量、
// 成本有界），保留压缩后 agent 绝不能丢的高信号事实——决策、未决项、下一步、用户偏好、文件/实体引用
// （丢了就被迫昂贵重读）。must-follow 规则**不**在此摘要——它们在 system prompt、每回合重发——故此处
// 只记 episodic。
const summarySystemPrompt = `You maintain a running summary of an ongoing conversation. Older turns are being dropped to free context; your summary is what the assistant will remember of them.

Rules:
1. EXTEND the previous summary with the new content — preserve its existing points; only strike one if the new content directly contradicts it.
2. Organize under these sections (omit any that are empty): User requests & constraints · Files/entities touched (keep exact paths & ids) · Decisions made · Errors & fixes · Open items / next steps · User preferences.
3. Keep concrete references (file paths, ids, names, numbers) verbatim — they are expensive to recover.
4. Be concise: under ~1500 tokens. Output ONLY the full updated summary, no preamble or commentary.`

// buildSummaryPrompt assembles the user-message body for the summary call: the prior summary
// (so the model extends it) followed by the new span's excerpts in chronological order.
//
// buildSummaryPrompt 拼摘要调用的 user 消息体：旧摘要（使模型扩展它）后接新 span 的按时序摘录。
func buildSummaryPrompt(oldSummary string, parts []string) string {
	var b strings.Builder
	if strings.TrimSpace(oldSummary) != "" {
		b.WriteString("PREVIOUS SUMMARY:\n")
		b.WriteString(oldSummary)
		b.WriteString("\n\n")
	}
	b.WriteString("NEW CONTENT to fold in (chronological):\n")
	for _, p := range parts {
		b.WriteString(p)
		b.WriteString("\n")
	}
	return b.String()
}

// excerpt renders one block for the summary prompt: a type/tool label + its content, truncated
// so a single huge block can't blow the summarizer's context. Empty content → "" (skipped).
//
// excerpt 把一个块渲成摘要 prompt 的一行：类型/工具标签 + 内容、截断以防单个巨大块冲爆摘要器上下文。
// 空内容 → ""（跳过）。
func excerpt(b messagesdomain.Block) string {
	c := strings.TrimSpace(b.Content)
	if c == "" {
		return ""
	}
	label := b.Type
	if tool, _ := b.Attrs["tool"].(string); tool != "" {
		label = b.Type + ":" + tool
	}
	if len(c) > maxBlockExcerptBytes {
		c = c[:maxBlockExcerptBytes] + "…[truncated]"
	}
	return "[" + label + "] " + c
}

// cleanSummary trims whitespace and strips a leading ``` fence if the model wrapped its output.
//
// cleanSummary 去空白、剥去模型若用 ``` 包裹的首尾围栏。
func cleanSummary(s string) string {
	s = strings.TrimSpace(s)
	s = strings.TrimPrefix(s, "```")
	s = strings.TrimSuffix(s, "```")
	return strings.TrimSpace(s)
}

// compactionMarker is the anchor block's short body (the full summary lives in
// conversation.summary; the anchor is a UI timeline marker only).
//
// compactionMarker 是锚块的短正文（完整摘要在 conversation.summary；锚只是 UI 时间轴标记）。
func compactionMarker(archivedCount int) string {
	return fmt.Sprintf("Context compacted — %d earlier blocks folded into the running summary.", archivedCount)
}
