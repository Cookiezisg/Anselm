package loop

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	"go.uber.org/zap"

	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// progressEmittingTool emits two progress lines then returns a final result, exercising the full
// stream + persist path through runOneTool.
type progressEmittingTool struct{}

func (progressEmittingTool) Name() string                        { return "emitter" }
func (progressEmittingTool) Description() string                 { return "" }
func (progressEmittingTool) Parameters() json.RawMessage         { return json.RawMessage(`{"type":"object"}`) }
func (progressEmittingTool) ValidateInput(json.RawMessage) error { return nil }
func (progressEmittingTool) Execute(ctx context.Context, _ string) (string, error) {
	prog := ToolProgress(ctx)
	defer prog.Close()
	prog.Print("step 1\n")
	prog.Print("step 2\n")
	return "final result", nil
}

// TestRunOneTool_PersistsProgressBeforeResult: a tool that streams progress yields, from runOneTool,
// [progress, tool_result] — the progress block carries the accumulated output, is parented to the
// tool_call, and precedes the result so the persisted sibling order is chronological.
//
// TestRunOneTool_PersistsProgressBeforeResult：发进度的工具经 runOneTool 产出 [progress, tool_result]
// ——progress 块带累积输出、挂 tool_call 下、排在 result 前，使持久化兄弟序符合时序。
func TestRunOneTool_PersistsProgressBeforeResult(t *testing.T) {
	b := &captureBridge{}
	ctx := reqctxpkg.SetConversationID(WithBridge(context.Background(), b), "c1")
	tc := messagesdomain.ToolCallData{ID: "tc1", Name: "emitter"}

	blocks := runOneTool(ctx, progressEmittingTool{}, tc, zap.NewNop())

	if len(blocks) != 2 {
		t.Fatalf("want 2 persisted blocks (progress + tool_result), got %d: %+v", len(blocks), blocks)
	}
	prog := blocks[0]
	if prog.Type != messagesdomain.BlockTypeProgress {
		t.Fatalf("blocks[0] not progress: %q", prog.Type)
	}
	if prog.ParentBlockID != "tc1" {
		t.Fatalf("progress not parented to the tool_call: %q", prog.ParentBlockID)
	}
	if !strings.Contains(prog.Content, "step 1") || !strings.Contains(prog.Content, "step 2") {
		t.Fatalf("progress content missing accumulated output: %q", prog.Content)
	}
	if blocks[1].Type != messagesdomain.BlockTypeToolResult || blocks[1].Content != "final result" {
		t.Fatalf("blocks[1] not the tool_result: %+v", blocks[1])
	}
}

// TestRunOneTool_NoProgressNoExtraBlock: a tool that emits no progress yields just its tool_result —
// the capture stays empty, so a silent tool persists exactly as before.
//
// TestRunOneTool_NoProgressNoExtraBlock：不发进度的工具只产出 tool_result——capture 为空，沉默工具的持久化
// 与从前一致。
func TestRunOneTool_NoProgressNoExtraBlock(t *testing.T) {
	b := &captureBridge{}
	ctx := reqctxpkg.SetConversationID(WithBridge(context.Background(), b), "c1")
	tc := messagesdomain.ToolCallData{ID: "tc1", Name: "silent"}

	blocks := runOneTool(ctx, silentTool{}, tc, zap.NewNop())
	if len(blocks) != 1 || blocks[0].Type != messagesdomain.BlockTypeToolResult {
		t.Fatalf("want exactly 1 tool_result block, got %+v", blocks)
	}
}

// TestRunOneTool_ResultFramesBracketRealExecution locks the wire boundary used by the sidestage:
// tool_call close is only the LLM's argument boundary; tool_result opens BEFORE Execute and closes
// with its durable output snapshot AFTER Execute. First Python environment setup therefore remains
// visibly live instead of disappearing between two unrelated stream phases.
//
// tool_call Close 只是模型参数边界；tool_result 必须在 Execute 前 Open、结束后携结果快照 Close。首次
// Python 环境准备由此持续可见，不会在两段无关流之间消失。
func TestRunOneTool_ResultFramesBracketRealExecution(t *testing.T) {
	b := &captureBridge{}
	ctx := reqctxpkg.SetConversationID(WithBridge(context.Background(), b), "c1")
	runOneTool(ctx, silentTool{}, messagesdomain.ToolCallData{ID: "tc1", Name: "silent"}, zap.NewNop())

	if len(b.events) != 2 {
		t.Fatalf("want result open + close, got %d: %+v", len(b.events), b.events)
	}
	open, ok := b.events[0].Frame.(streamdomain.Open)
	if !ok || open.ParentID != "tc1" || open.Node.Type != messagesdomain.BlockTypeToolResult {
		t.Fatalf("first frame must open execution result under tool call: %+v", b.events[0])
	}
	close, ok := b.events[1].Frame.(streamdomain.Close)
	if !ok || close.Result == nil || !strings.Contains(string(close.Result.Content), "ok") {
		t.Fatalf("last frame must close with the durable result snapshot: %+v", b.events[1])
	}
}

type silentTool struct{}

func (silentTool) Name() string                        { return "silent" }
func (silentTool) Description() string                 { return "" }
func (silentTool) Parameters() json.RawMessage         { return json.RawMessage(`{"type":"object"}`) }
func (silentTool) ValidateInput(json.RawMessage) error { return nil }
func (silentTool) Execute(context.Context, string) (string, error) {
	return "ok", nil
}
