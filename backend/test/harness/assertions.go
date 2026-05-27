//go:build pipeline

package harness

import (
	"strings"
	"testing"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	eventlogdomain "github.com/sunweilin/forgify/backend/internal/domain/eventlog"
)

// ErrEnvelope decodes the standard error envelope from any API response.
//
// ErrEnvelope 解 API 标准错误信封。
type ErrEnvelope struct {
	Error struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	} `json:"error"`
}

// ExtractTextFromBlocks concatenates content of all text blocks in order.
//
// ExtractTextFromBlocks 顺序拼接所有 text block 的内容。
func ExtractTextFromBlocks(blocks []chatdomain.Block) string {
	var b strings.Builder
	for _, blk := range blocks {
		if blk.Type != eventlogdomain.BlockTypeText {
			continue
		}
		b.WriteString(blk.Content)
	}
	return b.String()
}

// ExtractToolCallByName finds the first tool_call block matching name and returns its ID.
//
// ExtractToolCallByName 找匹配 name 的第一个 tool_call block,返其 ID。
func ExtractToolCallByName(blocks []chatdomain.Block, name string) (id string, found bool) {
	for _, blk := range blocks {
		if blk.Type != eventlogdomain.BlockTypeToolCall {
			continue
		}
		if n, _ := blk.Attrs["tool"].(string); n == name {
			return blk.ID, true
		}
	}
	return "", false
}

// ExtractToolResultByCallID finds the tool_result paired with callID; returns synthesized envelope.
//
// ExtractToolResultByCallID 找与 callID 配对的 tool_result,返合成 envelope。
func ExtractToolResultByCallID(blocks []chatdomain.Block, callID string) (data map[string]any, found bool) {
	for _, blk := range blocks {
		if blk.Type != eventlogdomain.BlockTypeToolResult {
			continue
		}
		if blk.ParentBlockID != callID {
			continue
		}
		out := map[string]any{
			"ok":     blk.Status == eventlogdomain.StatusCompleted,
			"result": blk.Content,
		}
		if blk.Error != "" {
			out["error"] = blk.Error
		}
		return out, true
	}
	return nil, false
}

// AssertErrCode fails the test when status or envelope.error.code mismatch.
// Reports both expected/actual and dumps the envelope's Message for context.
//
// AssertErrCode 在 status 或 envelope.error.code 不匹配时 fatal,
// 同时 dump envelope 的 Message 字段以利诊断。
func AssertErrCode(t *testing.T, gotStatus, wantStatus int, env ErrEnvelope, wantCode string) {
	t.Helper()
	if gotStatus != wantStatus {
		t.Fatalf("status=%d, want %d; code=%q msg=%q",
			gotStatus, wantStatus, env.Error.Code, env.Error.Message)
	}
	if env.Error.Code != wantCode {
		t.Fatalf("code=%q, want %q; status=%d msg=%q",
			env.Error.Code, wantCode, gotStatus, env.Error.Message)
	}
}

// AssertBlockType fails when no block with the given type+status exists.
// wantType ∈ eventlogdomain.BlockType* constants; wantStatus ∈ Status* constants
// (both are untyped string constants in eventlogdomain).
//
// AssertBlockType 在不存在指定 type+status 的 block 时 fatal。
// 参数取 eventlogdomain 的 BlockType* / Status* 常量(untyped string)。
func AssertBlockType(t *testing.T, blocks []chatdomain.Block, wantType, wantStatus string) {
	t.Helper()
	for _, blk := range blocks {
		if blk.Type == wantType && blk.Status == wantStatus {
			return
		}
	}
	t.Fatalf("no block of type=%q status=%q found; got %d blocks", wantType, wantStatus, len(blocks))
}

// SSEEvent is a minimal shape for ordering checks on a captured SSE stream.
// Tests that need richer assertions use the typed messages/blocks tree.
//
// SSEEvent 是 SSE 流捕获的最小 shape;只用于 seq 顺序断言。
type SSEEvent struct {
	Event string
	Seq   int64
	ID    string
}

// AssertSeqMonotonic fails when any consecutive SSE seq is not strictly greater.
// Dumps the offending pair and surrounding window for diagnosis.
//
// AssertSeqMonotonic 在任意相邻 SSE seq 非严格递增时 fatal,
// dump 出问题 pair 与上下文窗口。
func AssertSeqMonotonic(t *testing.T, events []SSEEvent) {
	t.Helper()
	for i := 1; i < len(events); i++ {
		if events[i].Seq <= events[i-1].Seq {
			start := i - 2
			if start < 0 {
				start = 0
			}
			end := i + 2
			if end > len(events) {
				end = len(events)
			}
			t.Fatalf("non-monotonic seq at i=%d (prev=%d, this=%d); window=%+v",
				i, events[i-1].Seq, events[i].Seq, events[start:end])
		}
	}
}
