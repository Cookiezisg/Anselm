package loop

import (
	"context"
	"encoding/json"
	"testing"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

type normalizingTestTool struct{}

func (normalizingTestTool) Name() string                                    { return "normalize_me" }
func (normalizingTestTool) Description() string                             { return "test" }
func (normalizingTestTool) Parameters() json.RawMessage                     { return json.RawMessage(`{"type":"object"}`) }
func (normalizingTestTool) ValidateInput(json.RawMessage) error             { return nil }
func (normalizingTestTool) Execute(context.Context, string) (string, error) { return "", nil }
func (normalizingTestTool) NormalizeArguments(args json.RawMessage) (json.RawMessage, bool) {
	return json.RawMessage(`{"flowrunId":"fr_exact"}`), true
}

var _ toolapp.ArgumentNormalizer = normalizingTestTool{}

func TestNormalizeToolCallArgumentsUpdatesDurableToolBlock(t *testing.T) {
	calls := []messagesdomain.ToolCallData{{ID: "blk_call", Name: "normalize_me", Arguments: map[string]any{"file_path": "fr_exact"}}}
	blocks := []messagesdomain.Block{{ID: "blk_call", Type: messagesdomain.BlockTypeToolCall, Content: `{"file_path":"fr_exact"}`}}
	gotCalls, gotBlocks, repaired := normalizeToolCallArguments(calls, blocks, map[string]toolapp.Tool{"normalize_me": normalizingTestTool{}}, nil)
	if len(repaired) != 1 || repaired[0] != "normalize_me" {
		t.Fatalf("repaired tools = %v, want normalize_me", repaired)
	}
	if got := gotCalls[0].Arguments["flowrunId"]; got != "fr_exact" {
		t.Fatalf("normalized call args = %#v, want flowrunId", gotCalls[0].Arguments)
	}
	if gotBlocks[0].Content != `{"flowrunId":"fr_exact"}` {
		t.Fatalf("durable block content = %q, want normalized JSON", gotBlocks[0].Content)
	}
	if got := gotBlocks[0].Attrs["argumentRepair"]; got != "provider arguments normalized by tool boundary" {
		t.Fatalf("generic repair reason = %#v", got)
	}
}

func TestNormalizeToolCallArgumentsDoesNothingWithoutActivatedTool(t *testing.T) {
	calls := []messagesdomain.ToolCallData{{ID: "blk_call", Name: "normalize_me", Arguments: map[string]any{"file_path": "fr_exact"}}}
	blocks := []messagesdomain.Block{{ID: "blk_call", Type: messagesdomain.BlockTypeToolCall, Content: `{"file_path":"fr_exact"}`}}
	gotCalls, gotBlocks, repaired := normalizeToolCallArguments(calls, blocks, map[string]toolapp.Tool{}, nil)
	if repaired != nil {
		t.Fatalf("inactive tool must not be repaired: %v", repaired)
	}
	if gotCalls[0].Arguments["file_path"] != "fr_exact" || gotBlocks[0].Content != `{"file_path":"fr_exact"}` {
		t.Fatalf("inactive tool arguments changed: calls=%#v block=%q", gotCalls[0].Arguments, gotBlocks[0].Content)
	}
}

type evidenceRepairTestTool struct{}

func (evidenceRepairTestTool) Name() string        { return "get_flowrun" }
func (evidenceRepairTestTool) Description() string { return "test" }
func (evidenceRepairTestTool) Parameters() json.RawMessage {
	return json.RawMessage(`{"type":"object"}`)
}
func (evidenceRepairTestTool) ValidateInput(json.RawMessage) error             { return nil }
func (evidenceRepairTestTool) Execute(context.Context, string) (string, error) { return "", nil }

func TestNormalizeToolCallArgumentsRestoresExactFlowrunEvidence(t *testing.T) {
	calls := []messagesdomain.ToolCallData{{ID: "blk_call", Name: "get_flowrun", Arguments: map[string]any{"file_path": "fr_truncated"}}}
	blocks := []messagesdomain.Block{{ID: "blk_call", Type: messagesdomain.BlockTypeToolCall, Content: `{"file_path":"fr_truncated"}`}}
	evidence := []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: "Use get_flowrun for flowrunId fr_19b3486793b3b754."}}
	gotCalls, gotBlocks, repaired := normalizeToolCallArguments(calls, blocks, map[string]toolapp.Tool{"get_flowrun": evidenceRepairTestTool{}}, evidence)
	if len(repaired) != 1 || gotCalls[0].Arguments["flowrunId"] != "fr_19b3486793b3b754" {
		t.Fatalf("evidence repair = calls=%#v repaired=%v", gotCalls, repaired)
	}
	if gotBlocks[0].Content != `{"flowrunId":"fr_19b3486793b3b754"}` {
		t.Fatalf("durable evidence repair = %q", gotBlocks[0].Content)
	}
	if gotBlocks[0].Attrs["argumentRepair"] != "flowrunId restored from one unambiguous user/tool evidence value" {
		t.Fatalf("repair reason = %#v", gotBlocks[0].Attrs["argumentRepair"])
	}
}

func TestLatestUnambiguousFlowrunIDRejectsMultipleCandidates(t *testing.T) {
	messages := []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: "Compare fr_one111 and fr_two222."}}
	if got := latestUnambiguousFlowrunID(messages); got != "" {
		t.Fatalf("ambiguous evidence = %q, want no repair", got)
	}
}
