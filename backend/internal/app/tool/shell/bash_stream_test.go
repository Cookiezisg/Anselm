package shell

import (
	"context"
	"strings"
	"testing"

	loopapp "github.com/sunweilin/anselm/backend/internal/app/loop"
	streamdomain "github.com/sunweilin/anselm/backend/internal/domain/stream"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// recBridge records published frames so the Bash progress stream can be asserted.
type recBridge struct{ events []streamdomain.Event }

func (b *recBridge) Publish(_ context.Context, e streamdomain.Event) (streamdomain.Envelope, error) {
	b.events = append(b.events, e)
	return streamdomain.Envelope{}, nil
}
func (b *recBridge) Subscribe(_ context.Context, _ int64) (<-chan streamdomain.Envelope, func(), error) {
	return nil, func() {}, nil
}

// TestBash_StreamsProgressUnderToolCall: a foreground Bash on a streamed chat turn tees its
// combined stdout/stderr to a live `progress` block nested under its tool_call (so the user
// watches output scroll), while the final tool_result still carries the full output.
//
// TestBash_StreamsProgressUnderToolCall：流式 chat turn 上的前台 Bash 把合并 stdout/stderr 双写到
// 嵌在其 tool_call 下的实时 `progress` 块（用户看输出滚动），而最终 tool_result 仍含完整输出。
func TestBash_StreamsProgressUnderToolCall(t *testing.T) {
	b := &Bash{mgr: NewProcessManager()}
	bridge := &recBridge{}
	ctx := reqctxpkg.SetToolCallID(reqctxpkg.SetConversationID(loopapp.WithBridge(context.Background(), bridge), "c1"), "tc1")

	out, err := b.Execute(ctx, `{"command":"echo hello-stream"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if !strings.Contains(out, "hello-stream") {
		t.Fatalf("tool_result missing output (tee to buf broken): %q", out)
	}

	if len(bridge.events) == 0 {
		t.Fatal("no progress frames streamed under the tool_call")
	}
	open, ok := bridge.events[0].Frame.(streamdomain.Open)
	if !ok || open.ParentID != "tc1" || open.Node.Type != "progress" {
		t.Fatalf("first frame not a progress Open under tc1: %+v", bridge.events[0])
	}
	var sawOutput bool
	for _, e := range bridge.events {
		if d, ok := e.Frame.(streamdomain.Delta); ok && strings.Contains(d.Chunk, "hello-stream") {
			sawOutput = true
		}
		if c, ok := e.Frame.(streamdomain.Close); ok && c.Result != nil && strings.Contains(string(c.Result.Content), "hello-stream") {
			sawOutput = true
		}
	}
	if !sawOutput {
		t.Fatalf("streamed progress missing echoed output: %+v", bridge.events)
	}
}

// TestBash_NoProgressFramesOffStream: off a streamed turn (no Bridge / no tool_call id) Bash runs
// identically and emits no frames — ToolProgress is a silent no-op.
//
// TestBash_NoProgressFramesOffStream：不在流式 turn（无 Bridge / 无 tool_call id），Bash 照常跑、不发
// 任何帧——ToolProgress 静默 no-op。
func TestBash_NoProgressFramesOffStream(t *testing.T) {
	b := &Bash{mgr: NewProcessManager()}
	out, err := b.Execute(context.Background(), `{"command":"echo plain"}`)
	if err != nil || !strings.Contains(out, "plain") {
		t.Fatalf("Execute off-stream: out=%q err=%v", out, err)
	}
}
