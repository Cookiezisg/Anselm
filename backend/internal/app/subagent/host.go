// host.go — subagentHost implements loop.Host for a sub-run. Persists to
// subagent_messages, emits chat.message events with the SubagentRun
// snapshot embedded so the frontend's per-run small-window UI updates
// from the same event stream as main chat (subagent.md §10).
//
// Lifecycle inside loop.Run:
//
//	loop.Run → host.LoadHistory          → seed: [system + user prompt]
//	         → host.OnInitialPublish     → (no-op; first WriteCheckpoint
//	                                       happens after step 1, and our
//	                                       Publish on stream events covers
//	                                       any earlier visibility need)
//	         per-step:
//	           ↓
//	           streamLLM → host.Publish(blocks, in, out)  (snapshot only)
//	           ↓
//	           runTools  → host.Publish(blocks, in, out)  (snapshot only)
//	           ↓
//	           host.WriteCheckpoint(blocks, in, out)      (DB + snapshot,
//	                                                       status=streaming)
//	         end:
//	           ↓
//	           host.WriteFinalize(blocks, status, ...)   (DB + snapshot,
//	                                                       terminal status)
//
// Streaming refinement strategy: a sub-run grows ONE assistant
// SubagentMessage row across all LLM events. The row is created lazily
// on the first Publish (we don't know the messageID until then) and
// refined via UpdateMessage on each Publish + each WriteCheckpoint +
// finalized in WriteFinalize. The row survives the run for replay.
//
// host.go ——subagentHost 实现 sub-run 的 loop.Host。落 subagent_messages，
// 发带 SubagentRun 快照的 chat.message 事件，让前端 per-run 小窗 UI 与
// 主对话共用一条事件流（subagent.md §10）。
//
// 流式精化：一次 sub-run 把 ONE assistant SubagentMessage 行跨所有 LLM
// 事件累加。行在首次 Publish 时懒建（在此之前 messageID 未知），随后每次
// Publish + 每次 WriteCheckpoint 通过 UpdateMessage 精化，WriteFinalize 终态。
package subagent

import (
	"context"
	"encoding/json"
	"sync"
	"time"

	"go.uber.org/zap"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	eventsdomain "github.com/sunweilin/forgify/backend/internal/domain/events"
	subagentdomain "github.com/sunweilin/forgify/backend/internal/domain/subagent"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// subagentHost satisfies loop.Host. One instance per Spawn — owns the
// SubagentRun pointer + the streaming SubagentMessage being refined.
//
// subagentHost 满足 loop.Host。每次 Spawn 一份——持 SubagentRun 指针 +
// 正在精化的 streaming SubagentMessage。
type subagentHost struct {
	svc          *Service
	run          *subagentdomain.SubagentRun
	tools        []toolapp.Tool
	userPrompt   string
	systemPrompt string

	// msgMu guards the lazily-created streaming assistant message and
	// the run's transient lastTool* fields (which are mutated from the
	// same Publish/WriteCheckpoint paths Run uses concurrently).
	//
	// msgMu 守护懒建的 streaming assistant 消息 + run 的瞬时 lastTool*
	// 字段（与 Publish/WriteCheckpoint 路径并发竞用）。
	msgMu     sync.Mutex
	streaming *subagentdomain.SubagentMessage // nil until first Publish writes the user prompt + opens the assistant row
}

// LoadHistory returns the seed history: just the user prompt. The
// system prompt is supplied via baseReq.System and not part of Messages.
// We also append a single user-role SubagentMessage row to the store at
// this point so the transcript replay starts with the prompt the LLM saw.
//
// LoadHistory 返种子历史：只有 user prompt。System prompt 走 baseReq.System
// 不进 Messages。同时往 store 追加一条 user-role SubagentMessage 行，让
// transcript 回放从 LLM 看到的 prompt 开始。
func (h *subagentHost) LoadHistory(ctx context.Context) ([]llminfra.LLMMessage, error) {
	userMsg := &subagentdomain.SubagentMessage{
		ID:            idgenpkg.New("smm"),
		SubagentRunID: h.run.ID,
		Role:          subagentdomain.RoleUser,
		Blocks: []chatdomain.Block{
			h.textBlock(h.userPrompt),
		},
		CreatedAt: time.Now().UTC(),
	}
	if err := h.svc.repo.AppendMessage(ctx, userMsg); err != nil {
		// Log + continue — losing the seeded row hurts replay but isn't
		// fatal to the actual sub-run (the LLM gets the prompt regardless
		// because we return it via baseReq.Messages).
		//
		// log + 继续——丢种子行影响回放但不影响实际 sub-run（LLM 仍通过
		// baseReq.Messages 拿到 prompt）。
		h.svc.log.Warn("subagent seed user message persist failed",
			zap.String("run_id", h.run.ID), zap.Error(err))
	}
	return []llminfra.LLMMessage{
		{Role: llminfra.RoleUser, Content: h.userPrompt},
	}, nil
}

// Tools returns the per-spawn filtered tool list.
//
// Tools 返 per-spawn 过滤后的 tool 列表。
func (h *subagentHost) Tools() []toolapp.Tool {
	return h.tools
}

// Publish emits a snapshot-only chat.message with the SubagentRun snapshot
// embedded. The streaming assistant row is created lazily on first call;
// subsequent calls only refine in-memory (no UpdateMessage — that would
// thrash SQLite under per-token streaming).
//
// Publish 推送一次 snapshot-only chat.message，嵌入 SubagentRun 快照。
// streaming assistant 行首次调用时懒建；后续仅 in-memory 精化（不 UpdateMessage
// ——per-token 流式下会把 SQLite 写炸）。
func (h *subagentHost) Publish(ctx context.Context, blocks []chatdomain.Block, status, stopReason, errCode, errMsg string, in, out int) {
	h.msgMu.Lock()
	defer h.msgMu.Unlock()
	if !h.ensureStreamingRow(ctx, blocks, in, out, false /*persistRefine*/, false /*fatal*/) {
		return
	}
	h.refreshRunFromBlocks(in, out, blocks)
	h.publishChatMessage(ctx, h.streaming, status, stopReason, errCode, errMsg)
}

// WriteCheckpoint persists the current streaming row + emits a snapshot
// after each ReAct step's tools complete. Status is always "streaming".
//
// WriteCheckpoint 在每个 ReAct 步骤的 tools 完成后持久化当前 streaming 行 +
// 推快照。status 恒为 "streaming"。
func (h *subagentHost) WriteCheckpoint(ctx context.Context, blocks []chatdomain.Block, in, out int) {
	h.msgMu.Lock()
	defer h.msgMu.Unlock()
	if !h.ensureStreamingRow(ctx, blocks, in, out, true /*persistRefine*/, false /*fatal*/) {
		return
	}
	h.refreshRunFromBlocks(in, out, blocks)
	// Token totals are visible to the parent through SubagentRun snapshot
	// fields surfaced in the published chat.message; also touch the row.
	// 给 parent 看的 token 累计通过快照字段走；同时更新 run 行。
	h.touchRun(ctx, in, out)
	h.publishChatMessage(ctx, h.streaming, chatdomain.StatusStreaming, "", "", "")
}

// WriteFinalize persists the terminal message + emits its snapshot. Uses
// a detached context for the persist so a cancelled parent doesn't lose
// the terminal record. The publish uses the original ctx (cancellation
// is fine for the snapshot — DB row is what matters). The publish fires
// even on persist failure so the UI always sees the terminal frame
// (caller-fatal logging surfaces the lost-row incident).
//
// WriteFinalize 持久化终态消息 + 推快照。持久化用 detached ctx 防 parent
// cancel 丢终态；publish 用原 ctx（snapshot 可丢，行才是关键）。即便持久化
// 失败也照发 publish，让 UI 始终看到终态帧（fatal log 暴露丢行事故）。
func (h *subagentHost) WriteFinalize(ctx context.Context, blocks []chatdomain.Block, status, stopReason, errCode, errMsg string, in, out int) {
	saveCtx := context.Background()
	if uid, err := reqctxpkg.RequireUserID(ctx); err == nil {
		saveCtx = reqctxpkg.SetUserID(saveCtx, uid)
	}

	h.msgMu.Lock()
	defer h.msgMu.Unlock()
	h.ensureStreamingRow(saveCtx, blocks, in, out, true /*persistRefine*/, true /*fatal*/)
	h.refreshRunFromBlocks(in, out, blocks)
	h.publishChatMessage(ctx, h.streaming, status, stopReason, errCode, errMsg)
}

// ensureStreamingRow is the shared body of Publish / WriteCheckpoint /
// WriteFinalize: it lazily creates the streaming SubagentMessage row on
// first call (AppendMessage) or refines its in-memory fields. When
// persistRefine=true an existing row is also flushed via UpdateMessage
// (Checkpoint + Finalize). When fatal=true persist failures log at Error
// and the streaming pointer is preserved so the caller can still publish
// a snapshot (Finalize semantics — UI must see the terminal frame).
//
// Returns true when the caller should proceed with publish; false when
// non-fatal create failed and the streaming row had to be dropped (caller
// returns early to retry on the next event).
//
// ensureStreamingRow 是 Publish/WriteCheckpoint/WriteFinalize 共用躯干：
// 首次调用懒建 streaming SubagentMessage 行（AppendMessage）；之后改 in-memory
// 字段。persistRefine=true 时已存在的行也走 UpdateMessage 落盘（Checkpoint +
// Finalize）。fatal=true 时持久化失败 log Error + 保留 streaming 指针让调用方
// 仍能发快照（Finalize 语义——UI 必须看到终态帧）。
//
// 返 true 表示调用方可继续 publish；返 false 表示非 fatal 时建行失败、streaming
// 已置 nil，调用方早返让下次事件再试。
func (h *subagentHost) ensureStreamingRow(ctx context.Context, blocks []chatdomain.Block, in, out int, persistRefine, fatal bool) bool {
	if h.streaming == nil {
		h.streaming = &subagentdomain.SubagentMessage{
			ID:               idgenpkg.New("smm"),
			SubagentRunID:    h.run.ID,
			Role:             subagentdomain.RoleAssistant,
			Blocks:           h.cloneBlocks(blocks),
			PromptTokens:     in,
			CompletionTokens: out,
			CreatedAt:        time.Now().UTC(),
		}
		// AppendMessage assigns Seq inside the store transaction.
		// AppendMessage 在 store 事务内分配 Seq。
		if err := h.svc.repo.AppendMessage(ctx, h.streaming); err != nil {
			h.logPersistErr("subagent streaming message create failed", err, fatal)
			if !fatal {
				// Non-fatal: drop the row so the next event retries Append.
				// 非 fatal：扔行，下次事件重试 Append。
				h.streaming = nil
				return false
			}
			// Fatal (Finalize): keep streaming so publish carries the data.
			// fatal（Finalize）：保留 streaming 让 publish 仍载有数据。
		}
		return true
	}
	h.streaming.Blocks = h.cloneBlocks(blocks)
	h.streaming.PromptTokens = in
	h.streaming.CompletionTokens = out
	if persistRefine {
		if err := h.svc.repo.UpdateMessage(ctx, h.streaming); err != nil {
			h.logPersistErr("subagent message persist failed", err, fatal)
		}
	}
	return true
}

// logPersistErr selects warn vs error severity for streaming-row persist
// failures. fatal=true is reserved for terminal writes (WriteFinalize) where
// loss is unrecoverable; warn is correct for mid-stream where the next event
// will retry.
//
// logPersistErr 选 streaming 行持久化失败的 warn/error 严重度。fatal=true 仅用于
// 终态写入（WriteFinalize），此时丢行不可恢复；中流走 warn——下次事件会重试。
func (h *subagentHost) logPersistErr(msg string, err error, fatal bool) {
	if fatal {
		h.svc.log.Error("CRITICAL: "+msg,
			zap.String("run_id", h.run.ID), zap.Error(err))
		return
	}
	h.svc.log.Warn(msg,
		zap.String("run_id", h.run.ID), zap.Error(err))
}

// ── helpers ──────────────────────────────────────────────────────────

// publishChatMessage emits the chat.message snapshot with the SubagentRun
// snapshot embedded. Caller holds h.msgMu so streaming + run reads are
// consistent. Bridge filter key is the parent conversation ID — the
// frontend subscribes once per conversation and routes by SubagentRunID.
//
// publishChatMessage 推 chat.message 快照（含 SubagentRun 快照）。调用方持
// h.msgMu 让 streaming + run 一致读。Bridge filter key 是父对话 ID——前端
// 订阅一个对话同时按 SubagentRunID 路由。
func (h *subagentHost) publishChatMessage(ctx context.Context, msg *subagentdomain.SubagentMessage, status, stopReason, errCode, errMsg string) {
	if msg == nil {
		return
	}
	chatMsg := &chatdomain.Message{
		ID:             msg.ID,
		ConversationID: h.run.ParentConversationID,
		Role:           chatdomain.RoleAssistant,
		Status:         status,
		StopReason:     stopReason,
		ErrorCode:      errCode,
		ErrorMessage:   errMsg,
		InputTokens:    msg.PromptTokens,
		OutputTokens:   msg.CompletionTokens,
		Blocks:         msg.Blocks,
		UpdatedAt:      time.Now().UTC(),
	}
	// Snapshot the run so subscribers see token totals + lastTool* without
	// a separate fetch. Defensive copy to avoid concurrent mutation while
	// the bridge encodes.
	// 快照 run 让订阅方一帧拿全（无需额外 fetch）。深拷贝避免 bridge 编码时
	// 被并发改动。
	runSnap := *h.run
	h.svc.bridge.Publish(ctx, h.run.ParentConversationID, eventsdomain.ChatMessage{
		Message:              chatMsg,
		SubagentRunID:        h.run.ID,
		ParentConversationID: h.run.ParentConversationID,
		SubagentRun:          &runSnap,
	})
}

// touchRun updates the persistent token-totals + step counter on the run
// row. Mid-stream cadence — we don't write every Publish (would be too
// chatty for SQLite); instead we write on WriteCheckpoint (per-step) +
// WriteFinalize. Best-effort: warn on failure, don't block.
//
// touchRun 更新 run 行的持久 token 累计 + step 计数。中流节奏——不每次
// Publish 写（SQLite 太吵）；按 WriteCheckpoint（每步）+ WriteFinalize 写。
// best-effort：失败 warn 不挡。
func (h *subagentHost) touchRun(ctx context.Context, in, out int) {
	h.run.TotalTokensIn = in
	h.run.TotalTokensOut = out
	h.run.StepsUsed++
	h.run.UpdatedAt = time.Now().UTC()
	if err := h.svc.repo.UpdateRun(ctx, h.run); err != nil {
		h.svc.log.Warn("subagent run checkpoint persist failed",
			zap.String("run_id", h.run.ID), zap.Error(err))
	}
}

// refreshRunFromBlocks updates the gorm:"-" lastTool* transient fields
// from the latest block slice so the next chat.message snapshot carries
// "what's the run doing right now". Walks the blocks tail-first looking
// for the most recent tool_call (and its matching tool_result, if any).
//
// refreshRunFromBlocks 从最新 block slice 更新 gorm:"-" 瞬时 lastTool*
// 字段，让下次 chat.message 快照携带"当前 run 在干什么"。从 blocks 末尾
// 反向找最新 tool_call（及其匹配 tool_result，如有）。
func (h *subagentHost) refreshRunFromBlocks(in, out int, blocks []chatdomain.Block) {
	h.run.TotalTokensIn = in
	h.run.TotalTokensOut = out
	now := time.Now().UTC()
	h.run.LastStepAt = &now

	var lastCall *chatdomain.ToolCallData
	var lastResult *chatdomain.ToolResultData
	for i := len(blocks) - 1; i >= 0; i-- {
		b := blocks[i]
		if lastCall == nil && b.Type == chatdomain.BlockTypeToolCall {
			var d chatdomain.ToolCallData
			if json.Unmarshal([]byte(b.Data), &d) == nil {
				lastCall = &d
			}
		}
		if lastResult == nil && b.Type == chatdomain.BlockTypeToolResult {
			var d chatdomain.ToolResultData
			if json.Unmarshal([]byte(b.Data), &d) == nil {
				lastResult = &d
			}
		}
		if lastCall != nil && lastResult != nil {
			break
		}
	}
	if lastCall != nil {
		h.run.LastToolCalled = lastCall.Name
		h.run.LastToolArgsBrief = h.briefArgs(lastCall.Arguments)
	}
	if lastResult != nil {
		h.run.LastToolResultBrief = trimBrief(lastResult.Result, 120)
		h.run.LastStepDurationMs = int(lastResult.ElapsedMs)
	}
}

// cloneBlocks deep-copies the slice (header + entry pointers) so the
// store doesn't observe later mid-stream mutation of the same backing
// array. Each Block's string fields are immutable so a shallow copy
// of the elements suffices.
//
// cloneBlocks 深拷贝 slice（header + entry 指针）防 store 看到后续 mid-stream
// 对同一底层数组的改动。每 Block 的 string 字段不可变，元素浅拷贝足够。
func (h *subagentHost) cloneBlocks(in []chatdomain.Block) []chatdomain.Block {
	out := make([]chatdomain.Block, len(in))
	copy(out, in)
	return out
}

// textBlock builds a single text-type Block (used for the seeded user
// prompt SubagentMessage).
//
// textBlock 建一条 text 类型 Block（种子 user prompt SubagentMessage 用）。
func (h *subagentHost) textBlock(text string) chatdomain.Block {
	d, _ := json.Marshal(chatdomain.TextData{Text: text})
	return chatdomain.Block{
		ID:        idgenpkg.New("blk"),
		Type:      chatdomain.BlockTypeText,
		Data:      string(d),
		CreatedAt: time.Now().UTC(),
	}
}

// briefArgs renders a tool's argument map as a compact preview for the
// SubagentRun.LastToolArgsBrief snapshot. Cap at 200 chars so the SSE
// frame stays small.
//
// briefArgs 把 tool argument map 渲染成 SubagentRun.LastToolArgsBrief 的紧凑
// 预览。截 200 字让 SSE 帧不膨胀。
func (h *subagentHost) briefArgs(args map[string]any) string {
	if len(args) == 0 {
		return ""
	}
	b, err := json.Marshal(args)
	if err != nil {
		return ""
	}
	return trimBrief(string(b), 200)
}

func trimBrief(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}
