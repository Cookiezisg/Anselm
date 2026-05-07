// stream.go — One LLM call: consume stream events, publish snapshots via
// host, assemble Blocks. No DB writes; loop.Run owns the persistence cadence.
//
// stream.go — 单次 LLM 调用：消费流事件、通过 host 推快照、组装 Block。
// 不写 DB——loop.Run 控制持久化节奏。
package loop

import (
	"context"
	"encoding/json"
	"strings"
	"time"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	eventlogpkg "github.com/sunweilin/forgify/backend/internal/pkg/eventlog"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// toolAccum accumulates streaming fragments for one tool call.
// toolAccum 累积单个 tool call 的流式片段。
type toolAccum struct {
	id, name string
	args     strings.Builder
}

// publishMinInterval throttles streaming-snapshot publishes to ~60 fps.
// Without this, every LLM stream event (text token / reasoning token /
// tool-args delta) triggered a host.Publish carrying the whole message-
// so-far. A 7000-token reasoning message could push 7000 ~10KB snapshots
// downstream, melting the SSE consumer (browser DOM-renders 7000 times,
// re-parsing 50+ MB of JSON). 16ms = the vsync budget; matches what the
// front-end can actually render anyway.
//
// publishMinInterval 把 streaming 快照推送节流到 ~60 fps。无节流时每个
// LLM stream event 都触发一次完整 message-so-far 推送，7000-token 的长
// reasoning message 会推 ~7000 次 ~10KB 快照，下游 SSE 消费者（浏览器）
// 必死。16ms = vsync 预算，匹配前端实际渲染能力。
const publishMinInterval = 16 * time.Millisecond

// streamLLM executes one LLM call. parentBlocks are blocks already accumulated
// from earlier ReAct steps — host snapshots prepend them so subscribers always
// see the full message-so-far.
//
// streamLLM 执行一次 LLM 调用。parentBlocks 是之前 ReAct 步骤累积的 blocks
// ——host 快照前置它们让订阅者始终看到 message-so-far。
//
// Event-log dual-write (Phase 2): also emits block_start / block_delta /
// block_stop on the recursive-event-log Bridge alongside the legacy
// snapshot path. text + reasoning blocks mint fresh blk_<id>; tool_call
// blocks reuse the LLM's tool-call ID as the block ID (per design
// event-log-protocol.md §3). On stream end / transition all open blocks
// get closed with appropriate status.
//
// 事件日志 dual-write（Phase 2）：在 legacy snapshot 旁同时给递归事件日志
// Bridge 推 block_start / block_delta / block_stop。text + reasoning 铸新
// blk_<id>；tool_call 复用 LLM 的 tool-call ID 作 block ID（详
// event-log-protocol.md §3）。流结束 / 切换时关闭所有 open block。
func streamLLM(
	ctx context.Context,
	client llminfra.Client,
	req llminfra.Request,
	host Host,
	parentBlocks []chatdomain.Block,
) (blocks []chatdomain.Block, toolCalls []chatdomain.ToolCallData, stopReason string, errMsg string, inputTokens, outputTokens int) {
	var textBuf, reasonBuf strings.Builder
	accums := map[int]*toolAccum{}
	stopReason = chatdomain.StopReasonEndTurn

	// Event-log emit state. Block IDs persist across stream events so
	// successive deltas reference the same block.
	//
	// 事件日志 emit 状态。Block ID 跨流事件持续，让连续 delta 引同一 block。
	em := eventlogpkg.From(ctx)
	msgID, _ := reqctxpkg.GetMessageID(ctx)
	var (
		textBlockID, reasonBlockID string
	)
	toolBlockIDs := make(map[int]string)

	closeText := func(status string) {
		if textBlockID != "" {
			em.StopBlock(ctx, textBlockID, status, nil)
			textBlockID = ""
		}
	}
	closeReason := func(status string) {
		if reasonBlockID != "" {
			em.StopBlock(ctx, reasonBlockID, status, nil)
			reasonBlockID = ""
		}
	}

	publishNow := func() {
		current := assembleBlocks(textBuf.String(), reasonBuf.String(), accums)
		host.Publish(ctx, joinBlocks(parentBlocks, current),
			chatdomain.StatusStreaming, "", "", "",
			inputTokens, outputTokens)
	}

	// Throttle bookkeeping. lastPublish=zero forces the first event to push
	// immediately so subscribers see "streaming started" without delay;
	// pendingPublish marks "skipped a publish, must flush before stream end."
	//
	// 节流簿记。lastPublish=零让首个 event 立即推（订阅者无延迟看到
	// "streaming 启动"）；pendingPublish 标记"跳过一次推送，stream 结束前
	// 必须 flush"。
	var lastPublish time.Time
	pendingPublish := false
	publishThrottled := func() {
		if time.Since(lastPublish) >= publishMinInterval {
			publishNow()
			lastPublish = time.Now()
			pendingPublish = false
		} else {
			pendingPublish = true
		}
	}

	for event := range client.Stream(ctx, req) {
		switch event.Type {
		case llminfra.EventText:
			// Transition out of reasoning if it was open.
			// 转出 reasoning（若开着）。
			closeReason(eventlogdomain.StatusCompleted)
			if textBlockID == "" && msgID != "" {
				textBlockID = idgenpkg.New("blk")
				em.EmitBlockStart(ctx, textBlockID, msgID, msgID, eventlogdomain.BlockTypeText, nil)
			}
			if textBlockID != "" {
				em.DeltaBlock(ctx, textBlockID, event.Delta)
			}
			textBuf.WriteString(event.Delta)
			publishThrottled()

		case llminfra.EventReasoning:
			closeText(eventlogdomain.StatusCompleted)
			if reasonBlockID == "" && msgID != "" {
				reasonBlockID = idgenpkg.New("blk")
				em.EmitBlockStart(ctx, reasonBlockID, msgID, msgID, eventlogdomain.BlockTypeReasoning, nil)
			}
			if reasonBlockID != "" {
				em.DeltaBlock(ctx, reasonBlockID, event.Delta)
			}
			reasonBuf.WriteString(event.Delta)
			publishThrottled()

		case llminfra.EventToolStart:
			// Tool start is a low-frequency milestone (one per tool call,
			// not per token) — push immediately so the UI can render the
			// "running…" pill without waiting up to 16ms.
			//
			// tool_start 是低频里程碑（每 tool 调用一次，非每 token），
			// 立即推，UI "running…" 无需等 16ms。
			closeText(eventlogdomain.StatusCompleted)
			closeReason(eventlogdomain.StatusCompleted)
			accums[event.ToolIndex] = &toolAccum{id: event.ToolID, name: event.ToolName}
			if msgID != "" && event.ToolID != "" {
				toolBlockIDs[event.ToolIndex] = event.ToolID
				em.EmitBlockStart(ctx, event.ToolID, msgID, msgID,
					eventlogdomain.BlockTypeToolCall,
					map[string]any{"tool": event.ToolName})
			}
			publishNow()
			lastPublish = time.Now()
			pendingPublish = false

		case llminfra.EventToolDelta:
			if a := accums[event.ToolIndex]; a != nil {
				a.args.WriteString(event.ArgsDelta)
				if id := toolBlockIDs[event.ToolIndex]; id != "" {
					em.DeltaBlock(ctx, id, event.ArgsDelta)
				}
				publishThrottled()
			}

		case llminfra.EventFinish:
			if event.FinishReason == "length" {
				stopReason = chatdomain.StopReasonMaxTokens
			}
			if event.InputTokens > 0 {
				inputTokens = event.InputTokens
			}
			if event.OutputTokens > 0 {
				outputTokens = event.OutputTokens
			}

		case llminfra.EventError:
			if ctx.Err() != nil {
				stopReason = chatdomain.StopReasonCancelled
			} else {
				stopReason = chatdomain.StopReasonError
				if event.Err != nil {
					errMsg = event.Err.Error()
				}
			}
		}
	}

	// Close any still-open event-log blocks before returning. The status
	// follows the stream's stopReason: cancelled → cancelled, error →
	// error, otherwise → completed (which covers normal end_turn / tool
	// transitions where the LLM finished delivering args).
	//
	// 返前关掉所有仍 open 的事件日志 block。状态跟随流 stopReason：取消 →
	// cancelled，error → error，其他 → completed（覆盖正常 end_turn / tool
	// 切换 LLM 完成 args 派发的情况）。
	closeStatus := eventlogdomain.StatusCompleted
	switch stopReason {
	case chatdomain.StopReasonCancelled:
		closeStatus = eventlogdomain.StatusCancelled
	case chatdomain.StopReasonError:
		closeStatus = eventlogdomain.StatusError
	}
	closeText(closeStatus)
	closeReason(closeStatus)
	for _, id := range toolBlockIDs {
		em.StopBlock(ctx, id, closeStatus, nil)
	}

	if ctx.Err() != nil && stopReason == chatdomain.StopReasonEndTurn {
		stopReason = chatdomain.StopReasonCancelled
	}

	// Final flush: if the loop ended on a throttled-skipped event, push the
	// last accumulated state so the UI sees the streaming-final state
	// without waiting for loop.Run's WriteCheckpoint (which writes DB and
	// can be slower than the 16ms throttle window).
	//
	// 终态 flush：循环结束时若最后一个 event 被节流跳过，强制推一次让 UI
	// 看到 streaming 最终态，不等 loop.Run 的 WriteCheckpoint（写 DB 比 16ms
	// 慢）。
	if pendingPublish {
		publishNow()
	}

	blocks = assembleBlocks(textBuf.String(), reasonBuf.String(), accums)
	toolCalls = extractToolCalls(blocks)
	return
}

// assembleBlocks builds the final Block slice from accumulated stream buffers.
// Order: reasoning → text → tool_calls (by ToolIndex). Seq is local; the host
// re-stamps global seq when persisting.
//
// assembleBlocks 从流缓冲组装最终的 Block 列表。顺序：reasoning → text →
// tool_calls（按 ToolIndex）。Seq 是本地值，host 落库时重新打全局 seq。
func assembleBlocks(text, reasoning string, accums map[int]*toolAccum) []chatdomain.Block {
	var blocks []chatdomain.Block
	seq := 0

	if reasoning != "" {
		d, _ := json.Marshal(chatdomain.TextData{Text: reasoning})
		blocks = append(blocks, chatdomain.Block{
			ID: idgenpkg.New("blk"), Seq: seq, Type: chatdomain.BlockTypeReasoning,
			Data: string(d), CreatedAt: time.Now().UTC(),
		})
		seq++
	}
	if text != "" {
		d, _ := json.Marshal(chatdomain.TextData{Text: text})
		blocks = append(blocks, chatdomain.Block{
			ID: idgenpkg.New("blk"), Seq: seq, Type: chatdomain.BlockTypeText,
			Data: string(d), CreatedAt: time.Now().UTC(),
		})
		seq++
	}

	indices := make([]int, 0, len(accums))
	for i := range accums {
		indices = append(indices, i)
	}
	sortInts(indices)
	for _, i := range indices {
		a := accums[i]
		fields, args := parseToolArgs(a.args.String())
		td := chatdomain.ToolCallData{
			ID:             a.id,
			Name:           a.name,
			Arguments:      args,
			Summary:        fields.Summary,
			Destructive:    fields.Destructive,
			ExecutionGroup: fields.ExecutionGroup,
		}
		d, _ := json.Marshal(td)
		blocks = append(blocks, chatdomain.Block{
			ID: idgenpkg.New("blk"), Seq: seq, Type: chatdomain.BlockTypeToolCall,
			Data: string(d), CreatedAt: time.Now().UTC(),
		})
		seq++
	}
	return blocks
}

// joinBlocks concatenates two block slices into a fresh slice (no aliasing).
// joinBlocks 拼接两段 block 切片到新 slice（无别名）。
func joinBlocks(a, b []chatdomain.Block) []chatdomain.Block {
	out := make([]chatdomain.Block, 0, len(a)+len(b))
	out = append(out, a...)
	out = append(out, b...)
	return out
}

// extractToolCalls walks blocks and returns every tool_call's ToolCallData.
// extractToolCalls 遍历 blocks，返回所有 tool_call 的 ToolCallData。
func extractToolCalls(blocks []chatdomain.Block) []chatdomain.ToolCallData {
	var calls []chatdomain.ToolCallData
	for _, b := range blocks {
		if b.Type != chatdomain.BlockTypeToolCall {
			continue
		}
		var tc chatdomain.ToolCallData
		if json.Unmarshal([]byte(b.Data), &tc) == nil {
			calls = append(calls, tc)
		}
	}
	return calls
}

// parseToolArgs strips the three standard fields from raw JSON args via the
// canonical toolapp.StripStandardFields, surfacing malformed JSON as
// args["raw"] so the LLM can still see what it sent.
//
// parseToolArgs 用 toolapp.StripStandardFields 剥三个标准字段；JSON 损坏时
// 把原文塞 args["raw"] 让 LLM 仍能看到自己发了什么。
func parseToolArgs(raw string) (toolapp.StandardFields, map[string]any) {
	if raw == "" {
		return toolapp.StandardFields{}, map[string]any{}
	}
	fields, stripped := toolapp.StripStandardFields(raw)
	var args map[string]any
	if err := json.Unmarshal([]byte(stripped), &args); err != nil || args == nil {
		return fields, map[string]any{"raw": raw}
	}
	return fields, args
}

// sortInts is a tiny in-place ascending int sort.
// sortInts 是一个就地升序整数排序。
func sortInts(a []int) {
	for i := 1; i < len(a); i++ {
		for j := i; j > 0 && a[j-1] > a[j]; j-- {
			a[j-1], a[j] = a[j], a[j-1]
		}
	}
}
