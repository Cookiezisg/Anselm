package loop

import (
	"context"
	"testing"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	messagesdomain "github.com/sunweilin/anselm/backend/internal/domain/messages"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func TestRedactOpaqueMachineValues(t *testing.T) {
	input := "bootId=1785570385396807000 handler hd_2a5fdba507830767 at 2026-08-01T07:46:40.084187Z"
	want := "bootId=<opaque value omitted> handler <opaque value omitted> at <opaque value omitted>"
	if got := redactOpaqueMachineValues(input); got != want {
		t.Fatalf("redactOpaqueMachineValues() = %q, want %q", got, want)
	}
}

func TestRedactOpaqueMachineValuesKeepsHumanSemantics(t *testing.T) {
	input := "mode warm -> cool; prefix alpha; bootId changed; 7 steps"
	if got := redactOpaqueMachineValues(input); got != input {
		t.Fatalf("human-readable semantics changed: got %q, want %q", got, input)
	}
}

func TestTextRedactorRedactsAcrossProviderChunks(t *testing.T) {
	var r textRedactor
	var got string
	got += r.Write("bootId=178557")
	got += r.Write("0385396807000 and handler hd_2a5f")
	got += r.Write("dba507830767 done")
	got += r.Flush()

	want := "bootId=<opaque value omitted> and handler <opaque value omitted> done"
	if got != want {
		t.Fatalf("stream redaction = %q, want %q", got, want)
	}
}

func TestTextRedactorFlushesOrdinaryTrailingWord(t *testing.T) {
	var r textRedactor
	if got := r.Write("hello"); got != "" {
		t.Fatalf("trailing word emitted before delimiter: %q", got)
	}
	if got := r.Write(" world"); got != "hello " {
		t.Fatalf("first completed word = %q, want %q", got, "hello ")
	}
	if got := r.Flush(); got != "world" {
		t.Fatalf("flush = %q, want %q", got, "world")
	}
}

func TestStreamLLM_PreservesOpaqueValuesForWorkflowAgent(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		textEv(`{"attachmentId":"att_00112233445566aa","source":"function_artifact"}`),
		finishEv(),
	}}}
	ctx := reqctxpkg.SetFlowrunID(context.Background(), "fr_00112233445566aa")
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	blocks, _, _, _, _, _ := streamLLM(ctx, client, llminfra.Request{}, noBuild, nil)

	if len(blocks) != 1 || blocks[0].Type != messagesdomain.BlockTypeText {
		t.Fatalf("workflow text blocks = %+v", blocks)
	}
	if blocks[0].Content != `{"attachmentId":"att_00112233445566aa","source":"function_artifact"}` {
		t.Fatalf("workflow agent data was redacted: %q", blocks[0].Content)
	}
}

func TestStreamLLM_RedactsOpaqueValuesForChat(t *testing.T) {
	client := &fakeClient{scripts: [][]llminfra.StreamEvent{{
		textEv(`done att_00112233445566aa`),
		finishEv(),
	}}}
	noBuild := func(string) (toolapp.BuildSpec, bool) { return toolapp.BuildSpec{}, false }
	blocks, _, _, _, _, _ := streamLLM(context.Background(), client, llminfra.Request{}, noBuild, nil)

	if len(blocks) != 1 || blocks[0].Content != "done <opaque value omitted>" {
		t.Fatalf("chat prose redaction changed: %+v", blocks)
	}
}
