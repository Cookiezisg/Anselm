package loop

import (
	"context"
	"encoding/json"
	"testing"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/forgify/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"

	"go.uber.org/zap"
)

// parkHost is a fakeHost that opts into human-in-the-loop parking (ParkHandler). allow is the
// always-allow session whitelist.
//
// parkHost 是 opt-in 人在环 park（ParkHandler）的 fakeHost。allow 是 always-allow 会话白名单。
type parkHost struct {
	*fakeHost
	allow map[string]bool
}

func (h parkHost) AllowsTool(name string) bool { return h.allow[name] }

// interactiveTool is an ask_user-style tool: the loop must park on it and NEVER call Execute.
//
// interactiveTool 是 ask_user 式工具：loop 须在其上 park、绝不调 Execute。
type interactiveTool struct {
	fakeTool
	executed *bool
}

func (interactiveTool) Interactive() {}
func (t interactiveTool) Execute(context.Context, string) (string, error) {
	if t.executed != nil {
		*t.executed = true
	}
	return "should-never-run", nil
}

func runWith(host Host, script []llminfra.StreamEvent) Result {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{script}}
	return Run(context.Background(), host, client, llminfra.Request{}, 5, zap.NewNop())
}

// TestRun_DangerParks: a host that opts into parking parks on a self-reported dangerous call — the
// turn finalizes `parked`, the tool does NOT execute, a pending tool_result placeholder is written,
// and the ParkRequest surfaces the gated call.
//
// TestRun_DangerParks：opt-in park 的 host 在自报危险调用处 park——回合落 `parked`、工具不执行、写
// pending tool_result 占位、ParkRequest 露出被门调用。
func TestRun_DangerParks(t *testing.T) {
	ran := false
	tools := []toolapp.Tool{recordTool{name: "delete_everything", ran: &ran}}
	host := parkHost{fakeHost: &fakeHost{tools: tools}}

	res := runWith(host, []llminfra.StreamEvent{
		toolStartEv(0, "tc1", "delete_everything"),
		toolDeltaEv(0, `{"danger":"dangerous","summary":"rm -rf"}`),
		finishEv(),
	})

	if res.Status != messagesdomain.StatusParked || res.StopReason != messagesdomain.StopReasonParked {
		t.Fatalf("want parked turn, got status=%q stop=%q", res.Status, res.StopReason)
	}
	if ran {
		t.Fatal("dangerous tool executed before approval — interrupt-before-side-effect violated")
	}
	if len(res.Parks) != 1 || res.Parks[0].Kind != ParkKindDanger || res.Parks[0].ToolCallID != "tc1" || res.Parks[0].ToolName != "delete_everything" {
		t.Fatalf("ParkRequest wrong: %+v", res.Parks)
	}
	if host.fin.status != messagesdomain.StatusParked {
		t.Fatalf("WriteFinalize status = %q, want parked", host.fin.status)
	}
	// a pending tool_result placeholder parented to the tool_call must be present
	var pending *messagesdomain.Block
	for i := range host.fin.blocks {
		if host.fin.blocks[i].Type == messagesdomain.BlockTypeToolResult {
			pending = &host.fin.blocks[i]
		}
	}
	if pending == nil || pending.Status != messagesdomain.StatusPending || pending.ParentBlockID != "tc1" {
		t.Fatalf("pending tool_result placeholder missing/wrong: %+v", pending)
	}
}

// TestRun_AskParks: an InteractiveTool (ask_user) call parks WITHOUT executing the tool.
//
// TestRun_AskParks：InteractiveTool（ask_user）调用 park 且不执行工具。
func TestRun_AskParks(t *testing.T) {
	executed := false
	tools := []toolapp.Tool{interactiveTool{fakeTool: fakeTool{name: "ask_user"}, executed: &executed}}
	host := parkHost{fakeHost: &fakeHost{tools: tools}}

	res := runWith(host, []llminfra.StreamEvent{
		toolStartEv(0, "tc1", "ask_user"),
		toolDeltaEv(0, `{"message":"which file?"}`),
		finishEv(),
	})

	if res.Status != messagesdomain.StatusParked {
		t.Fatalf("want parked, got %q", res.Status)
	}
	if executed {
		t.Fatal("ask_user Execute was called — the loop must park, never run an InteractiveTool")
	}
	if len(res.Parks) != 1 || res.Parks[0].Kind != ParkKindAsk {
		t.Fatalf("want one ask ParkRequest, got %+v", res.Parks)
	}
}

// TestRun_NoParkHandlerRunsDangerous: a host WITHOUT ParkHandler never parks — a dangerous call
// runs (pure trust). This keeps non-interactive hosts (subagent / workflow-agent) unchanged.
//
// TestRun_NoParkHandlerRunsDangerous：无 ParkHandler 的 host 永不 park——危险调用照跑（纯信任）。非交互
// host（subagent / workflow-agent）不变。
func TestRun_NoParkHandlerRunsDangerous(t *testing.T) {
	ran := false
	host := &fakeHost{tools: []toolapp.Tool{recordTool{name: "delete_everything", ran: &ran}}}

	res := runWith(host, []llminfra.StreamEvent{
		toolStartEv(0, "tc1", "delete_everything"),
		toolDeltaEv(0, `{"danger":"dangerous"}`),
		finishEv(),
		// second call after the tool result: stop
		textEv("done"),
		finishEv(),
	})

	if !ran {
		t.Fatal("no ParkHandler → dangerous tool must run (pure trust), but it did not")
	}
	if res.Status == messagesdomain.StatusParked {
		t.Fatal("a host without ParkHandler must never park")
	}
}

// TestRun_AlwaysAllowSkipsDangerPark: a tool on the always-allow whitelist runs even when flagged
// dangerous (the danger park is skipped). ask is unaffected (not tested here).
//
// TestRun_AlwaysAllowSkipsDangerPark：always-allow 白名单上的工具即便标危险也照跑（跳过 danger park）。
func TestRun_AlwaysAllowSkipsDangerPark(t *testing.T) {
	ran := false
	tools := []toolapp.Tool{recordTool{name: "deploy", ran: &ran}}
	host := parkHost{fakeHost: &fakeHost{tools: tools}, allow: map[string]bool{"deploy": true}}

	res := runWith(host, []llminfra.StreamEvent{
		toolStartEv(0, "tc1", "deploy"),
		toolDeltaEv(0, `{"danger":"dangerous"}`),
		finishEv(),
		textEv("deployed"),
		finishEv(),
	})

	if !ran {
		t.Fatal("always-allow tool should run without parking")
	}
	if res.Status == messagesdomain.StatusParked {
		t.Fatal("always-allow must skip the danger park")
	}
}

// recordTool records whether Execute ran (so a park test can assert non-execution).
//
// recordTool 记录 Execute 是否跑过（供 park 测试断言未执行）。
type recordTool struct {
	name string
	ran  *bool
}

func (t recordTool) Name() string                        { return t.name }
func (t recordTool) Description() string                 { return "record tool" }
func (t recordTool) Parameters() json.RawMessage         { return json.RawMessage(`{"type":"object"}`) }
func (t recordTool) ValidateInput(json.RawMessage) error { return nil }
func (t recordTool) Execute(context.Context, string) (string, error) {
	*t.ran = true
	return "ran", nil
}
