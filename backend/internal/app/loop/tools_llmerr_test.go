package loop

import (
	"context"
	"encoding/json"
	stderrors "errors"
	"fmt"
	"strings"
	"testing"

	"go.uber.org/zap"
	"go.uber.org/zap/zaptest/observer"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// TestLLMErrText: a tool error surfaced to the LLM must carry the structured Details a tool/domain
// attached (e.g. a workflow validation's "reason" naming the offending node + the real CEL error),
// not just the bare Message — Error() drops Details. Regression for F7 (iteration loop): an opaque
// "workflow graph is invalid" with no detail had the agent guessing CEL syntax blindly.
func TestLLMErrText(t *testing.T) {
	e := errorspkg.New(errorspkg.KindInvalid, "WORKFLOW_GRAPH_INVALID", "workflow graph is invalid").
		WithDetails(map[string]any{"reason": "cel scope: undeclared reference to 'payload'", "node": "convert"})
	got := llmErrText(e)
	if !strings.Contains(got, "workflow graph is invalid") ||
		!strings.Contains(got, "undeclared reference to 'payload'") ||
		!strings.Contains(got, "node=convert") {
		t.Fatalf("llmErrText must surface Details to the LLM, got: %s", got)
	}

	if got := llmErrText(stderrors.New("plain boom")); got != "plain boom" {
		t.Errorf("plain error must pass through unchanged: %q", got)
	}

	if got := llmErrText(errorspkg.New(errorspkg.KindInvalid, "X", "nope")); got != "nope" {
		t.Errorf("no-details error must be just the message: %q", got)
	}

	// A sentinel wrapped by an app layer (fmt.Errorf("pkg.Method: %w", …)) must surface the clean
	// Message — never the Go call-path the wrap chain leaks. Regression for the tooload-lane finding:
	// run_function errors reached the LLM as "functionapp.RunFunction: function not found" (S20 violated).
	sentinel := errorspkg.New(errorspkg.KindNotFound, "FUNCTION_NOT_FOUND", "function not found")
	wrapped := fmt.Errorf("functionapp.RunFunction: %w", sentinel)
	if got := llmErrText(wrapped); got != "function not found" {
		t.Errorf("wrapped sentinel must surface clean Message without Go call-path, got: %q", got)
	}
}

// TestToolFailureLog_CarriesTheReason — the OPERATOR's copy of a tool failure must carry the same
// structured Details the LLM's does.
//
// [TestLLMErrText] above records the F7 lesson for the model: an opaque "workflow graph is invalid"
// with no detail had the agent guessing CEL syntax blindly, so the LLM path surfaces Details. The
// structured log had the identical hole and nobody noticed, because the hole is only visible when you
// go READING the log — which is exactly what the log is for. `zap.Error(err)` renders `Error()`, and
// `Error()` drops Details by construction, so the reason the backend already computed
// (`ops[3]: …`, the offending node, the real CEL error) was thrown away in the one channel an operator
// has. Real machine: a `tool execute failed … invalid workflow ops` line, and no way to tell WHICH op.
//
// TestToolFailureLog_CarriesTheReason——工具失败的**运维那一份**必须带上与 LLM 那份相同的结构化 Details。
//
// 上面的 [TestLLMErrText] 为模型记下了 F7 的教训:不透明的「workflow graph is invalid」不带细节,让 agent 盲猜
// CEL 语法,故 LLM 路径会 surface Details。结构化日志有**一模一样**的洞而没人发现,因为这个洞只有在你真去**读**
// 日志时才看得见——而那正是日志存在的意义。`zap.Error(err)` 渲染的是 `Error()`,而 `Error()` 按构造就丢
// Details,于是后端**已经算出来的**原因(`ops[3]: …`、出问题的节点、真正的 CEL 错误)在运维**唯一**的那条通道里
// 被扔掉了。真机:一行 `tool execute failed … invalid workflow ops`,而无从知道是**哪一个** op。
func TestToolFailureLog_CarriesTheReason(t *testing.T) {
	core, logs := observer.New(zap.WarnLevel)
	log := zap.New(core)

	boom := errorspkg.New(errorspkg.KindUnprocessable, "WORKFLOW_INVALID_OPS", "invalid workflow ops").
		WithDetails(map[string]any{"reason": "ops[3]: unknown op kind \"rename\""})
	executeTool(
		context.Background(),
		fakeTool{name: "edit_workflow", err: boom},
		"edit_workflow",
		json.RawMessage(`{}`),
		log,
	)

	entries := logs.FilterMessage("tool execute failed").All()
	if len(entries) != 1 {
		t.Fatalf("expected exactly one failure log line, got %d", len(entries))
	}
	var rendered string
	for _, f := range entries[0].Context {
		if f.Key == "error" {
			rendered = f.String
			if rendered == "" && f.Interface != nil {
				if e, ok := f.Interface.(error); ok {
					rendered = e.Error()
				}
			}
		}
	}
	if !strings.Contains(rendered, "invalid workflow ops") {
		t.Errorf("the log line lost the message: %q", rendered)
	}
	if !strings.Contains(rendered, `ops[3]`) {
		t.Errorf("the log line dropped the REASON the backend already computed — an operator reading "+
			"this line cannot tell which op was wrong (WRK-083): %q", rendered)
	}
}
