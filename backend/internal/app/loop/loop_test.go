package loop

import (
	"context"
	"encoding/json"
	"iter"
	"testing"

	"go.uber.org/zap/zaptest"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	toolsettool "github.com/sunweilin/forgify/backend/internal/app/tool/toolset"
	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
	agentstatepkg "github.com/sunweilin/forgify/backend/internal/pkg/agentstate"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// scriptedClient yields one pre-scripted StreamEvent slice per Stream call, FIFO.
//
// scriptedClient 每次 Stream 调用按 FIFO 吐一组预设 StreamEvent。
type scriptedClient struct {
	scripts [][]llminfra.StreamEvent
	calls   int
}

func (c *scriptedClient) Stream(_ context.Context, _ llminfra.Request) iter.Seq[llminfra.StreamEvent] {
	idx := c.calls
	c.calls++
	return func(yield func(llminfra.StreamEvent) bool) {
		if idx >= len(c.scripts) {
			yield(llminfra.StreamEvent{Type: llminfra.EventFinish, FinishReason: "stop"})
			return
		}
		for _, ev := range c.scripts[idx] {
			if !yield(ev) {
				return
			}
		}
	}
}

// gatingHost mimics chatHost: Tools(ctx) returns Resident plus the lazy groups
// activated on the ctx AgentState, so each step reflects activate_tools effects.
//
// gatingHost 模拟 chatHost：Tools(ctx) 返 Resident 加 ctx 上已激活的 lazy 组，
// 让每步反映 activate_tools 的效果。
type gatingHost struct {
	ts             toolapp.Toolset
	offeredPerCall [][]string
}

func (h *gatingHost) LoadHistory(_ context.Context) ([]llminfra.LLMMessage, error) {
	return []llminfra.LLMMessage{{Role: llminfra.RoleUser, Content: "go"}}, nil
}

func (h *gatingHost) Tools(ctx context.Context) []toolapp.Tool {
	out := append([]toolapp.Tool{}, h.ts.Resident...)
	if state, ok := reqctxpkg.GetAgentState(ctx); ok {
		for _, cat := range state.ActivatedGroups() {
			out = append(out, h.ts.Lazy[cat]...)
		}
	}
	names := make([]string, len(out))
	for i, t := range out {
		names[i] = t.Name()
	}
	h.offeredPerCall = append(h.offeredPerCall, names)
	return out
}

func (h *gatingHost) WriteFinalize(context.Context, []chatdomain.Block, string, string, string, string, int, int) {
}

func hasName(names []string, want string) bool {
	for _, n := range names {
		if n == want {
			return true
		}
	}
	return false
}

// TestRun_ActivateToolsExpandsNextStepToolset proves on-demand loading end-to-end:
// step 1 only offers resident tools; the LLM calls activate_tools{handler}; step 2
// then offers edit_handler, which was absent from step 1.
//
// TestRun_ActivateToolsExpandsNextStepToolset 端到端验证按需加载：
// 第 1 步只 offer resident；LLM 调 activate_tools{handler}；第 2 步才 offer edit_handler。
func TestRun_ActivateToolsExpandsNextStepToolset(t *testing.T) {
	ts := toolapp.Toolset{
		Lazy: map[string][]toolapp.Tool{
			"handler": {namedTool{"edit_handler"}},
		},
	}
	ts.Resident = []toolapp.Tool{toolsettool.NewActivateTools(ts)}

	host := &gatingHost{ts: ts}

	client := &scriptedClient{scripts: [][]llminfra.StreamEvent{
		// Step 1: call activate_tools{category:"handler"}.
		{
			{Type: llminfra.EventToolStart, ToolIndex: 0, ToolID: "call_1", ToolName: "activate_tools"},
			{Type: llminfra.EventToolDelta, ToolIndex: 0, ArgsDelta: `{"summary":"load handler tools","category":"handler"}`},
			{Type: llminfra.EventFinish, FinishReason: "tool_calls"},
		},
		// Step 2: plain text → loop ends.
		{
			{Type: llminfra.EventText, Delta: "done"},
			{Type: llminfra.EventFinish, FinishReason: "stop"},
		},
	}}

	state := &agentstatepkg.AgentState{}
	ctx := reqctxpkg.WithAgentState(context.Background(), state)

	res := Run(ctx, host, client, llminfra.Request{}, 5, zaptest.NewLogger(t))

	if len(host.offeredPerCall) != 2 {
		t.Fatalf("expected Tools(ctx) called once per step (2), got %d calls: %v",
			len(host.offeredPerCall), host.offeredPerCall)
	}
	if hasName(host.offeredPerCall[0], "edit_handler") {
		t.Errorf("step 1 must NOT offer edit_handler before activation; offered: %v", host.offeredPerCall[0])
	}
	if !hasName(host.offeredPerCall[1], "edit_handler") {
		t.Errorf("step 2 must offer edit_handler after activate_tools{handler}; offered: %v", host.offeredPerCall[1])
	}
	if res.Status != chatdomain.StatusCompleted {
		t.Errorf("status = %q, want completed", res.Status)
	}
}

// namedTool is a Name()-only Tool stub for asserting which tools a step offers.
//
// namedTool 是仅 Name() 的 Tool stub，用来断言某步 offer 了哪些工具。
type namedTool struct{ name string }

func (t namedTool) Name() string                        { return t.name }
func (t namedTool) Description() string                 { return "stub" }
func (t namedTool) Parameters() json.RawMessage         { return json.RawMessage(`{"type":"object"}`) }
func (t namedTool) IsReadOnly() bool                    { return true }
func (t namedTool) NeedsReadFirst() bool                { return false }
func (t namedTool) RequiresWorkspace() bool             { return false }
func (t namedTool) ValidateInput(json.RawMessage) error { return nil }
func (t namedTool) CheckPermissions(json.RawMessage, toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}
func (t namedTool) Execute(context.Context, string) (string, error) { return "", nil }
