package contextmgr

import (
	"context"
	"slices"

	"go.uber.org/zap"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
)

// demote ages old tool_result blocks down the hot→warm→cold gradient (the LLM-free first step:
// tool outputs dominate token usage and are rarely needed verbatim again). It mutates the
// in-memory thread's roles (so the gate estimate sees the new state) and batch-persists the
// changes. Protected (recent recentTurns messages) + pinned + already-archived blocks are left
// alone; only tool_results move.
//
// demote 把旧 tool_result 沿 hot→warm→cold 梯度老化（免 LLM 的第一步：工具输出占 token 大头、很少
// 再需原文）。它原地改内存 thread 的角色（使闸估算看到新态）+ 批量落盘。保护（最近 recentTurns 条
// message）+ pinned + 已 archived 的块不动；只动 tool_result。
func (s *Service) demote(ctx context.Context, thread []*messagesdomain.Message, protectedFrom int) {
	var toWarm, toCold []string
	tr := 0 // tool_result rank, newest-first, over non-protected blocks
	for mi := len(thread) - 1; mi >= 0; mi-- {
		m := thread[mi]
		if m.SubagentID != "" || mi >= protectedFrom {
			continue // subagent trace / protected recent turns
		}
		for bi := len(m.Blocks) - 1; bi >= 0; bi-- {
			b := &m.Blocks[bi]
			if b.Type != messagesdomain.BlockTypeToolResult || b.ContextRole == messagesdomain.ContextRoleArchived || pinnedBlock(*b) {
				continue
			}
			tr++
			var role string
			switch {
			case tr <= recentTRHot:
				continue // stays hot (and only ages older over time — never promote)
			case tr <= recentTRHot+warmZone:
				role = messagesdomain.ContextRoleWarm
			default:
				role = messagesdomain.ContextRoleCold
			}
			if b.ContextRole == role {
				continue
			}
			b.ContextRole = role
			if role == messagesdomain.ContextRoleWarm {
				toWarm = append(toWarm, b.ID)
			} else {
				toCold = append(toCold, b.ID)
			}
		}
	}
	if err := s.deps.Messages.UpdateBlocksContextRole(ctx, toWarm, messagesdomain.ContextRoleWarm); err != nil {
		s.log.Warn("contextmgr.demote: persist warm failed", zap.Error(err))
	}
	if err := s.deps.Messages.UpdateBlocksContextRole(ctx, toCold, messagesdomain.ContextRoleCold); err != nil {
		s.log.Warn("contextmgr.demote: persist cold failed", zap.Error(err))
	}
}

// estimateTokens cheaply approximates what LoadHistory will send next turn (summary + each
// non-dropped block projected per its role), bytes/4. The step-① gate only — the trigger uses
// real tokens. Approximate by design (omits the system prompt) and self-correcting.
//
// estimateTokens 廉价近似 LoadHistory 下回合将发送的量（summary + 每个未丢块按角色投影），bytes/4。
// 仅步①闸——触发用真实 token。设计上近似（略 system prompt）且自校正。
func (s *Service) estimateTokens(thread []*messagesdomain.Message, summary string) int {
	total := len(summary)
	for _, m := range thread {
		if m.SubagentID != "" {
			continue
		}
		for _, b := range m.Blocks {
			total += projectedBytes(b)
		}
	}
	return total / bytesPerToken
}

// summarize folds the oldest non-protected span into the running summary (one utility-model
// call), advances the watermark, then best-effort flags those blocks archived and drops a
// compaction anchor. Crash-safe ordering: SetSummary (watermark = truth) FIRST, so a crash
// before the archived flag can't double-count (LoadHistory drops by watermark). Archive is
// per-message (whole turns) so a tool_call never loses its tool_result.
//
// summarize 把最旧的非保护 span 并入滚动 summary（一次 utility 模型调用），推进水位，再 best-effort
// 标记这些块 archived + 落一个 compaction 锚。崩溃安全顺序：SetSummary（水位=真相）**先**，故翻
// archived 标记前崩溃也不重复计数（LoadHistory 按水位丢）。archive 按 message 粒度（整回合），故
// tool_call 绝不失去其 tool_result。
func (s *Service) summarize(ctx context.Context, conversationID string, thread []*messagesdomain.Message, protectedFrom int, oldSummary string, watermark int64) error {
	var archiveIDs []string
	var parts []string
	newWatermark := watermark

	for mi := range protectedFrom {
		m := thread[mi]
		if m.SubagentID != "" || messagePinned(m) {
			continue
		}
		var ids []string
		var msgMaxSeq int64
		for i := range m.Blocks {
			b := &m.Blocks[i]
			if b.Type == messagesdomain.BlockTypeCompaction || b.Seq <= watermark {
				continue // never fold the compaction anchor; skip already-covered blocks
			}
			ids = append(ids, b.ID)
			if b.Seq > msgMaxSeq {
				msgMaxSeq = b.Seq
			}
			if exc := excerpt(*b); exc != "" {
				parts = append(parts, exc)
			}
		}
		if len(ids) == 0 {
			continue
		}
		archiveIDs = append(archiveIDs, ids...)
		if msgMaxSeq > newWatermark {
			newWatermark = msgMaxSeq
		}
	}
	if len(archiveIDs) == 0 {
		return nil // nothing past the watermark outside the protected window
	}

	bundle, err := s.deps.Resolver.ResolveUtility(ctx)
	if err != nil {
		return err
	}
	req := bundle.Request
	req.System = summarySystemPrompt
	req.Messages = []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: buildSummaryPrompt(oldSummary, parts)}}
	newSummary, err := llminfra.Generate(ctx, bundle.Client, req)
	if err != nil {
		return err
	}
	if newSummary = cleanSummary(newSummary); newSummary == "" {
		return nil // empty summary — leave demotion in place, don't archive (no data folded)
	}

	// SetSummary first: the watermark is the source of truth for "folded into summary".
	// SetSummary 先：水位是「已并入 summary」的真相源。
	if err := s.deps.Conversations.SetSummary(ctx, conversationID, newSummary, newWatermark); err != nil {
		return err
	}
	// Best-effort UI/backstop marking (a failure here is harmless — watermark already governs).
	// best-effort UI/backstop 标记（此处失败无害——水位已主管）。
	if err := s.deps.Messages.UpdateBlocksContextRole(ctx, archiveIDs, messagesdomain.ContextRoleArchived); err != nil {
		s.log.Warn("contextmgr.summarize: archive flag failed (non-fatal, watermark governs)", zap.Error(err))
	}
	s.writeAnchor(ctx, conversationID, len(archiveIDs))
	return nil
}

// writeAnchor drops a compaction marker block (a synthetic assistant turn) so the UI shows where
// history was compacted. The summary text lives in conversation.summary; the anchor carries only
// a short marker. loop drops compaction blocks from LLM history, and chat.LoadHistory skips the
// resulting empty assistant. Best-effort.
//
// writeAnchor 落一个 compaction 标记块（合成 assistant 回合）使 UI 显示历史在哪压缩。摘要正文在
// conversation.summary；锚只带短标记。loop 从 LLM 历史丢 compaction 块，chat.LoadHistory 跳过随之产生
// 的空 assistant。best-effort。
func (s *Service) writeAnchor(ctx context.Context, conversationID string, archivedCount int) {
	anchor := &messagesdomain.Message{
		ID:             idgenpkg.New("msg"),
		ConversationID: conversationID,
		Role:           messagesdomain.RoleAssistant,
		Status:         messagesdomain.StatusCompleted,
	}
	block := messagesdomain.Block{
		Type:    messagesdomain.BlockTypeCompaction,
		Content: compactionMarker(archivedCount),
	}
	if err := s.deps.Messages.CreateMessage(ctx, anchor, []messagesdomain.Block{block}); err != nil {
		s.log.Warn("contextmgr.writeAnchor: failed (non-fatal)", zap.Error(err))
	}
}

// ----- pure helpers -----

func pinnedBlock(b messagesdomain.Block) bool {
	p, _ := b.Attrs["pinned"].(bool)
	return p
}

func messagePinned(m *messagesdomain.Message) bool {
	return slices.ContainsFunc(m.Blocks, pinnedBlock)
}

// projectedBytes is how many content bytes a block contributes to LLM history under its role —
// mirrors loop's projection so the gate estimate matches reality.
//
// projectedBytes 是一个块按其角色进 LLM 历史的内容字节数——镜像 loop 的投影使闸估算贴合现实。
func projectedBytes(b messagesdomain.Block) int {
	if b.ContextRole == messagesdomain.ContextRoleArchived || b.Type == messagesdomain.BlockTypeCompaction {
		return 0
	}
	if b.Type == messagesdomain.BlockTypeToolResult {
		switch b.ContextRole {
		case messagesdomain.ContextRoleWarm:
			if len(b.Content) > warmPreviewBytes {
				return warmPreviewBytes + 40 // preview + truncation marker
			}
			return len(b.Content)
		case messagesdomain.ContextRoleCold:
			return 50 // "[<tool> output omitted (N bytes)]" placeholder
		}
	}
	return len(b.Content)
}
