package chat

import (
	"context"
	"fmt"
	"strings"

	loopapp "github.com/sunweilin/anselm/backend/internal/app/loop"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// LoadHistory composes the LLM message history the loop generates against: the conversation's
// compaction summary (if any) first, then every persisted turn oldest-first. User turns render
// to text (+ multimodal attachment parts gated by the model's capabilities); assistant turns
// project their block tree via loopapp.BlocksToAssistantLLM (hot/warm/cold). The in-flight
// assistant turn (this generation, opened with no blocks yet) is skipped.
//
// LoadHistory 组装 loop 据以生成的 LLM 消息历史：先对话压缩摘要（若有），再每个持久回合最旧在前。
// user 回合渲成文本（+ 按模型能力门控的多模态附件部件）；assistant 回合经 loopapp.BlocksToAssistantLLM
// 投影其 block 树（hot/warm/cold）。在飞的 assistant 回合（本次生成、开时暂无 block）被跳过。
func (h *chatHost) LoadHistory(ctx context.Context) ([]llminfra.LLMMessage, error) {
	// Read-minimized load: the SQL already drops subagent sub-messages (never in the parent's LLM
	// history) and the compaction-folded blocks (seq ≤ watermark, content now in the summary), so a
	// long single-conversation session stops re-reading the whole folded-inclusive block table from
	// disk every turn (R10). The Go filters below (subagent skip, unfolded) stay as a belt-and-braces
	// invariant — they are no-ops on this pre-filtered set, keeping the LLM-visible set byte-identical.
	//
	// 读最小化加载：SQL 已丢 subagent 子消息（从不属父 LLM 历史）+ 压缩已折叠 block（seq ≤ 水位、内容已在
	// 摘要），使长单对话会话不再每轮从盘重读整张含折叠的 block 表（R10）。下方 Go 过滤（subagent 跳过、
	// unfolded）留作双保险——对已过滤集是 no-op，使 LLM 可见集逐字不变。
	thread, err := h.svc.messages.LoadThreadForLLM(ctx, h.conversationID, h.summaryCoversUpToSeq)
	if err != nil {
		return nil, fmt.Errorf("chatapp.LoadHistory: %w", err)
	}

	var out []llminfra.LLMMessage
	if h.summary != "" {
		// The compacted older history rides as a leading user-role context block (the original
		// blocks are archived; their content folded into conversation.summary).
		//
		// 被压缩的旧历史作为一条前置 user 角色上下文块（原 block 已 archived，内容并入 conversation.summary）。
		out = append(out, llminfra.LLMMessage{
			Role:    llminfra.RoleUser,
			Content: "<conversation_summary>\n" + h.summary + "\n</conversation_summary>",
		})
	}

	for _, m := range thread {
		// A subagent's sub-messages live in this conversation (persisted for the reload tree)
		// but are NOT part of the parent's LLM history — the parent only sees the spawning
		// tool_call + its tool_result (the subagent's final answer). Exclude them here.
		//
		// subagent 的 sub-message 落在本对话（为 reload 树持久化），但**不是**父的 LLM 历史——父只见
		// 派它的 tool_call + 其 tool_result（subagent 最终答案）。此处排除。
		if m.SubagentID != "" {
			continue
		}
		switch m.Role {
		case messagesdomain.RoleUser:
			// The watermark governs user turns too: a fully-folded user turn (its text already
			// lives in the summary) must not ride along verbatim — user pastes are the bulk of
			// context growth, and summary + verbatim double-presence would defeat compaction.
			// A folded turn has NO LLM-visible blocks: either the load already SQL-filtered them
			// out (LoadThreadForLLM, seq ≤ watermark → empty Blocks) or unfolded() drops them here —
			// both paths skip it (and so does a turn that loaded with no blocks at all, which would
			// otherwise emit an empty user message).
			// 水位线同样统辖 user 回合：已整体并入摘要的 user 回合不得原文随行——用户粘贴本就是上下文膨胀
			// 的大头，摘要+原文双份在场会让压缩形同虚设。已折叠回合无 LLM 可见 block：要么加载时已 SQL 滤掉
			// （LoadThreadForLLM，seq ≤ 水位 → 空 Blocks），要么此处 unfolded() 丢掉——两路都跳过（无任何
			// block 的回合也跳，否则会发空 user 消息）。
			if len(h.unfolded(m.Blocks)) == 0 {
				continue
			}
			user, err := h.userMessage(ctx, m)
			if err != nil {
				return nil, fmt.Errorf("chatapp.LoadHistory: render user message %s: %w", m.ID, err)
			}
			out = append(out, user)
		case messagesdomain.RoleAssistant:
			if m.ID == h.assistantMsgID {
				continue // the turn being generated right now — no blocks to replay yet
			}
			msgs := loopapp.BlocksToAssistantLLM(h.unfolded(m.Blocks))
			if isEmptyAssistant(msgs) {
				// Every block was archived/compaction (a fully-compacted turn or the compaction
				// anchor message): its content now lives in the summary. Skip it rather than emit
				// an empty assistant message (which some providers reject).
				//
				// 全部 block 被 archived/compaction（整回合已压缩，或 compaction 锚 message）：内容已在
				// summary。跳过、不发空 assistant（部分 provider 拒收）。
				continue
			}
			out = append(out, msgs...)
		}
	}
	return out, nil
}

// unfolded drops the blocks already folded into the conversation summary (seq ≤ watermark) — the
// watermark is the source of truth for "covered by summary", so a crash between writing the
// summary and flipping the archived flag can never double-count. No watermark (0) → unchanged
// (no allocation, the common path).
//
// unfolded 丢弃已并入对话摘要的 block（seq ≤ 水位线）——水位线是「已被摘要覆盖」的真相源，故写完
// 摘要、翻 archived 标记之间崩溃也绝不重复计数。无水位线（0）→ 原样返回（不分配，常路径）。
func (h *chatHost) unfolded(blocks []messagesdomain.Block) []messagesdomain.Block {
	if h.summaryCoversUpToSeq <= 0 {
		return blocks
	}
	out := make([]messagesdomain.Block, 0, len(blocks))
	for _, b := range blocks {
		if b.Seq <= h.summaryCoversUpToSeq {
			continue
		}
		out = append(out, b)
	}
	return out
}

// isEmptyAssistant reports whether a projected turn carries nothing for the LLM — a single
// assistant message with no text, reasoning, or tool calls, and no tool-result messages. That
// happens when every block dropped (archived / compaction). A tool-only turn (ToolCalls > 0) or
// any tool-result message is NOT empty.
//
// isEmptyAssistant 报告投影后的回合对 LLM 是否一无所有——单条 assistant 消息、无文本/推理/工具调用，
// 且无 tool-result 消息。当每个 block 都被丢弃（archived / compaction）时发生。纯工具回合
// （ToolCalls > 0）或任何 tool-result 消息都**不**算空。
func isEmptyAssistant(msgs []llminfra.LLMMessage) bool {
	if len(msgs) != 1 {
		return false
	}
	m := msgs[0]
	return m.Role == llminfra.RoleAssistant && m.Content == "" && m.ReasoningContent == "" && len(m.ToolCalls) == 0
}

// userMessage renders one persisted user turn to an LLM message: plain text when there are no
// attachments, otherwise a text part followed by the attachment renderer's multimodal parts
// (image_url / inline file / extracted text, gated by the model's capabilities). Missing blobs
// already become explicit text notes in attachment.Service; real rendering/transport failures
// must surface rather than silently omitting a user-selected managed media object.
//
// userMessage 把一个持久 user 回合渲成 LLM 消息：无附件时纯文本，否则一个 text 部件后接附件渲染器
// 的多模态部件（image_url / 内联 file / 抽取文本，按模型能力门控）。缺失 blob 已在 attachment 层成为
// 明确文字占位；真实渲染/传输失败必须向用户返回，绝不静默漏掉用户选中的受管媒体。
func (h *chatHost) userMessage(ctx context.Context, m *messagesdomain.Message) (llminfra.LLMMessage, error) {
	text := userText(m)
	// Prepend the frozen @-mention snapshots so the referenced entities' content is inline.
	// 前置冻结的 @ mention 快照，使被引用实体内容内联。
	if mentions := renderMentions(m); mentions != "" {
		if text != "" {
			text = mentions + "\n\n" + text
		} else {
			text = mentions
		}
	}
	ids := attachmentIDsOf(m)
	if len(ids) == 0 || h.svc.deps.Attachments == nil {
		return llminfra.LLMMessage{Role: llminfra.RoleUser, Content: text}, nil
	}

	parts, err := h.svc.deps.Attachments.ToContentParts(ctx, ids, h.caps)
	if err != nil {
		return llminfra.LLMMessage{}, fmt.Errorf("render attachments: %w", err)
	}

	msg := llminfra.LLMMessage{Role: llminfra.RoleUser}
	if text != "" {
		msg.Parts = append(msg.Parts, llminfra.ContentPart{Type: llminfra.PartText, Text: text})
	}
	msg.Parts = append(msg.Parts, parts...)
	return msg, nil
}

// userText concatenates a turn's text blocks (newline-joined). User turns carry only text blocks;
// reasoning / tool_* belong to assistant turns.
//
// userText 拼接一个回合的 text block（换行连接）。user 回合只有 text block；reasoning / tool_* 属
// assistant 回合。
func userText(m *messagesdomain.Message) string {
	var b strings.Builder
	for _, blk := range m.Blocks {
		if blk.Type == messagesdomain.BlockTypeText {
			if b.Len() > 0 {
				b.WriteString("\n")
			}
			b.WriteString(blk.Content)
		}
	}
	return b.String()
}

// attachmentIDsOf reads the attachment ids Send snapshotted into Message.Attrs. A JSON round-trip
// (store persists Attrs as JSON) turns the []string into []any, so both forms are handled.
//
// attachmentIDsOf 读 Send 快照进 Message.Attrs 的附件 id。JSON 往返（store 把 Attrs 存为 JSON）把
// []string 变成 []any，故两种形态都处理。
func attachmentIDsOf(m *messagesdomain.Message) []string {
	raw, ok := m.Attrs[attrAttachments]
	if !ok {
		return nil
	}
	switch v := raw.(type) {
	case []string:
		return v
	case []any:
		out := make([]string, 0, len(v))
		for _, e := range v {
			if s, ok := e.(string); ok {
				out = append(out, s)
			}
		}
		return out
	}
	return nil
}
