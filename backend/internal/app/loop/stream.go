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
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
)

// toolAccum accumulates streaming fragments for one tool call.
// toolAccum 累积单个 tool call 的流式片段。
type toolAccum struct {
	id, name string
	args     strings.Builder
}

// streamLLM executes one LLM call. parentBlocks are blocks already accumulated
// from earlier ReAct steps — host snapshots prepend them so subscribers always
// see the full message-so-far.
//
// streamLLM 执行一次 LLM 调用。parentBlocks 是之前 ReAct 步骤累积的 blocks
// ——host 快照前置它们让订阅者始终看到 message-so-far。
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

	publish := func() {
		current := assembleBlocks(textBuf.String(), reasonBuf.String(), accums)
		host.Publish(ctx, joinBlocks(parentBlocks, current),
			chatdomain.StatusStreaming, "", "", "",
			inputTokens, outputTokens)
	}

	for event := range client.Stream(ctx, req) {
		switch event.Type {
		case llminfra.EventText:
			textBuf.WriteString(event.Delta)
			publish()

		case llminfra.EventReasoning:
			reasonBuf.WriteString(event.Delta)
			publish()

		case llminfra.EventToolStart:
			accums[event.ToolIndex] = &toolAccum{id: event.ToolID, name: event.ToolName}
			publish()

		case llminfra.EventToolDelta:
			if a := accums[event.ToolIndex]; a != nil {
				a.args.WriteString(event.ArgsDelta)
				publish()
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

	if ctx.Err() != nil && stopReason == chatdomain.StopReasonEndTurn {
		stopReason = chatdomain.StopReasonCancelled
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
