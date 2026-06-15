package loop

import (
	"context"
	"strings"
	"testing"

	entitystreamapp "github.com/sunweilin/foryx/backend/internal/app/entitystream"
	toolapp "github.com/sunweilin/foryx/backend/internal/app/tool"
	streamdomain "github.com/sunweilin/foryx/backend/internal/domain/stream"
	llminfra "github.com/sunweilin/foryx/backend/internal/infra/llm"
)

// TestStreamLLM_BuildDoubleWritesToEntities: a build tool_call's streaming args are mirrored onto
// the entities stream as a build node (scope = a build session keyed by the tool_call id), so the
// entity panel fills in live. The entities bridge is the only one seeded here, isolating the
// double-write from the messages emitter.
//
// TestStreamLLM_BuildDoubleWritesToEntities：build tool_call 的流式 args 被镜像到 entities 流，成 build
// 节点（scope=以 tool_call id 为键的 build 会话），使实体面板实时填充。此处只种 entities bridge，把双写与
// messages emitter 隔离。
func TestStreamLLM_BuildDoubleWritesToEntities(t *testing.T) {
	ent := &captureBridge{}
	ctx := entitystreamapp.WithBridge(context.Background(), ent)
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		toolStartEv(0, "tc1", "create_function"),
		toolDeltaEv(0, `{"ops":[{"op":"set_code",`),
		toolDeltaEv(0, `"code":"def f(): pass"}]}`),
		finishEv(),
	}}}
	buildOf := func(name string) (toolapp.BuildSpec, bool) {
		if name == "create_function" {
			return toolapp.BuildSpec{Kind: "function", Op: "create"}, true
		}
		return toolapp.BuildSpec{}, false
	}

	streamLLM(ctx, client, llminfra.Request{}, buildOf, nil)

	if len(ent.events) != 4 {
		t.Fatalf("want 4 entities frames (open + 2 delta + close), got %d: %+v", len(ent.events), ent.events)
	}
	open, ok := ent.events[0].Frame.(streamdomain.Open)
	if !ok || open.Node.Type != entitystreamapp.NodeBuild {
		t.Fatalf("frame[0] not a build Open: %+v", ent.events[0])
	}
	// The build session is keyed by the SERVER-minted tool_call block id (blk_), never the
	// provider's wire id — providers recycle wire ids, which cannot key anything durable.
	// build 会话以服务端构建的 tool_call 块 id（blk_）为键、绝非 provider 线缆 id——provider 会
	// 复用线缆 id，不能作任何持久键。
	if ent.events[0].Scope.Kind != streamdomain.KindFunction || !strings.HasPrefix(ent.events[0].Scope.ID, "blk_") {
		t.Fatalf("build not scoped to a blk_-keyed function build session: %+v", ent.events[0].Scope)
	}
	for i := 1; i < 4; i++ {
		if ent.events[i].Scope.ID != ent.events[0].Scope.ID {
			t.Fatalf("frame[%d] scope drifted from the build session: %+v", i, ent.events[i].Scope)
		}
	}
	if !strings.Contains(string(open.Node.Content), `"create"`) {
		t.Fatalf("open content missing op=create: %s", open.Node.Content)
	}
	cl, ok := ent.events[3].Frame.(streamdomain.Close)
	if !ok || cl.Result == nil || !strings.Contains(string(cl.Result.Content), "def f()") {
		t.Fatalf("close result missing the final args snapshot: %+v", ent.events[3])
	}
}

// TestStreamLLM_NonBuildToolNoEntities: a non-build tool_call emits nothing on the entities stream.
//
// TestStreamLLM_NonBuildToolNoEntities：非 build tool_call 不在 entities 流发任何帧。
func TestStreamLLM_NonBuildToolNoEntities(t *testing.T) {
	ent := &captureBridge{}
	ctx := entitystreamapp.WithBridge(context.Background(), ent)
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		toolStartEv(0, "tc1", "Read"),
		toolDeltaEv(0, `{"path":"/x"}`),
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }

	streamLLM(ctx, client, llminfra.Request{}, noBuild, nil)

	if len(ent.events) != 0 {
		t.Fatalf("non-build tool must not emit entities frames, got %d", len(ent.events))
	}
}
