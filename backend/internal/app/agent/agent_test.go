package agent

import (
	"context"
	"database/sql"
	"errors"
	"iter"
	"testing"

	_ "github.com/glebarez/go-sqlite"
	"go.uber.org/zap"

	agentdomain "github.com/sunweilin/anselm/backend/internal/domain/agent"
	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	agentstore "github.com/sunweilin/anselm/backend/internal/infra/store/agent"
	ormpkg "github.com/sunweilin/anselm/backend/internal/pkg/orm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
	schemapkg "github.com/sunweilin/anselm/backend/internal/pkg/schema"
)

// fakeLLMClient replays one scripted step of stream events.
type fakeLLMClient struct{ events []llminfra.StreamEvent }

func (c *fakeLLMClient) Stream(_ context.Context, _ llminfra.Request) iter.Seq[llminfra.StreamEvent] {
	return func(yield func(llminfra.StreamEvent) bool) {
		for _, ev := range c.events {
			if !yield(ev) {
				return
			}
		}
	}
}

type fakeResolver struct {
	client llminfra.Client
	err    error // when set, ResolveAgent fails (simulates a bad api-key / unresolvable model)
}

func (r fakeResolver) ResolveAgent(context.Context, *modeldomain.ModelRef) (LLMBundle, error) {
	if r.err != nil {
		return LLMBundle{}, r.err
	}
	return LLMBundle{Client: r.client, Request: llminfra.Request{ModelID: "test-model"}, APIKeyID: "ak_test", Provider: "deepseek"}, nil
}

type fakeKnowledge struct{}

func (fakeKnowledge) BuildKnowledgePrefix(context.Context, []string) (string, error) { return "", nil }

func newSvc(t *testing.T) (*Service, context.Context) {
	t.Helper()
	sqlDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = sqlDB.Close() })
	for _, stmt := range agentstore.Schema {
		if _, err := sqlDB.Exec(stmt); err != nil {
			t.Fatalf("schema: %v", err)
		}
	}
	svc := NewService(agentstore.New(ormpkg.Open(sqlDB)), nil, zap.NewNop())
	return svc, reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
}

func TestService_CreateEditRevert(t *testing.T) {
	svc, ctx := newSvc(t)

	a, v1, err := svc.Create(ctx, CreateInput{Name: "alpha", Config: Config{Prompt: "p1"}})
	if err != nil || v1.Version != 1 {
		t.Fatalf("create: %v v%d", err, v1.Version)
	}
	v2, err := svc.Edit(ctx, EditInput{ID: a.ID, Config: Config{Prompt: "p2"}})
	if err != nil || v2.Version != 2 {
		t.Fatalf("edit: %v v%d", err, v2.Version)
	}
	if got, _ := svc.Get(ctx, a.ID); got.ActiveVersionID != v2.ID {
		t.Fatalf("active should be v2 after edit")
	}
	rv, err := svc.Revert(ctx, a.ID, 1)
	if err != nil || rv.ID != v1.ID {
		t.Fatalf("revert: %v", err)
	}
	if got, _ := svc.Get(ctx, a.ID); got.ActiveVersionID != v1.ID {
		t.Fatalf("active should be v1 after revert")
	}
}

func TestService_CreateRejectsAgentRef(t *testing.T) {
	svc, ctx := newSvc(t)
	_, _, err := svc.Create(ctx, CreateInput{Name: "x", Config: Config{
		Prompt: "p", Tools: []agentdomain.ToolRef{{Ref: "ag_other"}},
	}})
	if !errors.Is(err, agentdomain.ErrToolsAgentRef) {
		t.Fatalf("want ErrToolsAgentRef, got %v", err)
	}
}

// TestService_InvokeRunsLoopAndRecords: with a fake LLM (no real network), InvokeAgent runs the
// real ReAct loop, returns the final output, and records one execution. This is the whole
// invoke-with-loop surface, fake-tested.
//
// TestService_InvokeRunsLoopAndRecords：假 LLM（无网络）下 InvokeAgent 跑真 ReAct loop、返回最终
// 输出、落一条 execution。这是 invoke-接-loop 全面，fake 测。
func TestService_InvokeRunsLoopAndRecords(t *testing.T) {
	svc, ctx := newSvc(t)
	svc.SetInvokeDeps(InvokeDeps{
		Resolver: fakeResolver{client: &fakeLLMClient{events: []llminfra.StreamEvent{
			{Type: llminfra.EventText, Delta: "approve"},
			{Type: llminfra.EventFinish, InputTokens: 10, OutputTokens: 5},
		}}},
		Knowledge: fakeKnowledge{},
	})

	a, _, err := svc.Create(ctx, CreateInput{
		Name: "judge",
		Config: Config{
			Prompt:  "judge the PR",
			Outputs: []schemapkg.Field{{Name: "decision", Type: schemapkg.TypeString, Description: "one of: approve, reject"}},
		},
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	res, err := svc.InvokeAgent(ctx, InvokeInput{AgentID: a.ID, TriggeredBy: agentdomain.TriggeredByChat})
	if err != nil {
		t.Fatalf("invoke: %v", err)
	}
	if !res.OK {
		t.Fatalf("expected OK, got %+v", res)
	}
	// F40: with one declared output, the agent's final answer is coerced to node.decision (a map),
	// not left as a bare string that toResultMap would bury under node.text.
	out, ok := res.Output.(map[string]any)
	if !ok || out["decision"] != "approve" {
		t.Fatalf("declared output should map to node.decision, got %#v", res.Output)
	}
	if res.ExecutionID == "" {
		t.Fatalf("expected an execution to be recorded")
	}

	sr, err := svc.SearchExecutions(ctx, agentdomain.ExecutionFilter{AgentID: a.ID})
	if err != nil || len(sr.Executions) != 1 || sr.Aggregates.OKCount != 1 {
		t.Fatalf("execution not recorded as ok: %v %+v", err, sr)
	}

	// F155: the audit row records the resolved credential provenance — which model ran, under which
	// api-key, on which provider — so two keys exposing the same model name stay distinguishable.
	detail, err := svc.GetExecutionDetail(ctx, res.ExecutionID)
	if err != nil {
		t.Fatalf("get execution detail: %v", err)
	}
	if detail.ModelID != "test-model" || detail.APIKeyID != "ak_test" || detail.Provider != "deepseek" {
		t.Fatalf("execution audit must record model/key/provider provenance (F155), got modelId=%q apiKeyId=%q provider=%q",
			detail.ModelID, detail.APIKeyID, detail.Provider)
	}
}

// TestService_InvokeRecordsDeclaredModelOnResolveFailure pins F154: when the run fails BEFORE the LLM
// is resolved (ResolveAgent errors on a bad api-key), the recorded modelID is empty — but the DECLARED
// target model is still known from the override, so the audit row must record it. Otherwise a failed
// run can't say which model it meant to hit.
//
// TestService_InvokeRecordsDeclaredModelOnResolveFailure 锁 F154：run 在解析 LLM **之前**就失败时
// （ResolveAgent 因坏 api-key 报错）modelID 为空——但声明的目标模型仍可从 override 取，审计行须记下它，
// 否则失败 run 说不出它本要打哪个模型。
func TestService_InvokeRecordsDeclaredModelOnResolveFailure(t *testing.T) {
	svc, ctx := newSvc(t)
	svc.SetInvokeDeps(InvokeDeps{
		Resolver:  fakeResolver{err: errors.New("api key not found")},
		Knowledge: fakeKnowledge{},
	})

	a, _, err := svc.Create(ctx, CreateInput{
		Name: "judge",
		Config: Config{
			Prompt:        "p",
			ModelOverride: &modeldomain.ModelRef{APIKeyID: "aki_test", ModelID: "deepseek-x"},
		},
	})
	if err != nil {
		t.Fatalf("create: %v", err)
	}

	res, err := svc.InvokeAgent(ctx, InvokeInput{AgentID: a.ID, TriggeredBy: agentdomain.TriggeredByChat})
	if err != nil {
		t.Fatalf("InvokeAgent surfaces the failed run as a result, not a Go error: %v", err)
	}
	if res.OK || res.Status != agentdomain.ExecutionStatusFailed {
		t.Fatalf("resolve failure must record a failed run, got OK=%v status=%q", res.OK, res.Status)
	}

	sr, err := svc.SearchExecutions(ctx, agentdomain.ExecutionFilter{AgentID: a.ID})
	if err != nil || len(sr.Executions) != 1 {
		t.Fatalf("a failed execution must still be recorded: %v %+v", err, sr)
	}
	if got := sr.Executions[0].ModelID; got != "deepseek-x" {
		t.Fatalf("failed-run audit row must name the declared target model deepseek-x (F154), got %q", got)
	}
	// F155: apiKeyId likewise falls back to the declared override on a pre-resolve failure; provider has
	// no override source so it stays empty (the run never reached a resolved provider).
	if got := sr.Executions[0].APIKeyID; got != "aki_test" {
		t.Fatalf("failed-run audit row must fall back to the declared apiKeyId aki_test (F155), got %q", got)
	}
	if got := sr.Executions[0].Provider; got != "" {
		t.Fatalf("provider has no override fallback; must stay empty on a pre-resolve failure, got %q", got)
	}
}

// TestService_InvokeCoercesJSONOutput — F40: an agent declaring multiple outputs that answers with the
// JSON object has each field land as node.<field> (the object passes through, not buried in node.text).
func TestService_InvokeCoercesJSONOutput(t *testing.T) {
	svc, ctx := newSvc(t)
	svc.SetInvokeDeps(InvokeDeps{
		Resolver: fakeResolver{client: &fakeLLMClient{events: []llminfra.StreamEvent{
			{Type: llminfra.EventText, Delta: `{"decision": "approve", "score": 8}`},
			{Type: llminfra.EventFinish, InputTokens: 10, OutputTokens: 5},
		}}},
		Knowledge: fakeKnowledge{},
	})
	a, _, _ := svc.Create(ctx, CreateInput{Name: "judge", Config: Config{
		Prompt: "judge",
		Outputs: []schemapkg.Field{
			{Name: "decision", Type: schemapkg.TypeString},
			{Name: "score", Type: schemapkg.TypeNumber},
		},
	}})
	res, err := svc.InvokeAgent(ctx, InvokeInput{AgentID: a.ID, TriggeredBy: agentdomain.TriggeredByChat})
	if err != nil || !res.OK {
		t.Fatalf("invoke: err=%v res=%+v", err, res)
	}
	out, ok := res.Output.(map[string]any)
	if !ok || out["decision"] != "approve" {
		t.Fatalf("JSON output should pass through to the field map, got %#v", res.Output)
	}
}

// TestService_InvokeLoudFailsUnstructuredMultiOutput — F40: an agent declaring 2+ outputs that answers
// with prose (not a JSON object) fails loudly — a bare string can't be split into the named fields, so
// the run records failed instead of silently handing the next node an unusable text blob.
func TestService_InvokeLoudFailsUnstructuredMultiOutput(t *testing.T) {
	svc, ctx := newSvc(t)
	svc.SetInvokeDeps(InvokeDeps{
		Resolver: fakeResolver{client: &fakeLLMClient{events: []llminfra.StreamEvent{
			{Type: llminfra.EventText, Delta: "I think we should approve it, the score is high."},
			{Type: llminfra.EventFinish, InputTokens: 10, OutputTokens: 5},
		}}},
		Knowledge: fakeKnowledge{},
	})
	a, _, _ := svc.Create(ctx, CreateInput{Name: "judge", Config: Config{
		Prompt: "judge",
		Outputs: []schemapkg.Field{
			{Name: "decision", Type: schemapkg.TypeString},
			{Name: "score", Type: schemapkg.TypeNumber},
		},
	}})
	res, err := svc.InvokeAgent(ctx, InvokeInput{AgentID: a.ID, TriggeredBy: agentdomain.TriggeredByChat})
	if err != nil {
		t.Fatalf("invoke: %v", err)
	}
	if res.OK || res.Status != agentdomain.ExecutionStatusFailed || res.ErrorMsg == "" {
		t.Fatalf("a multi-output agent answering with prose must fail loudly, got %+v", res)
	}
}

// TestCoerceDeclaredOutputs_FencedJSONWithProse — F-structured-output-fence (round-14 agentstructured):
// the LLM commonly wraps its JSON answer in a ```json fence AFTER some prose. The old code only stripped
// a fence at the very start, so a prose-prefixed fenced answer was rejected as AGENT_OUTPUT_NOT_STRUCTURED
// — a probabilistic terminal failure. The fenced block is now extracted from anywhere in the answer.
func TestCoerceDeclaredOutputs_FencedJSONWithProse(t *testing.T) {
	fields := []schemapkg.Field{{Name: "decision", Type: schemapkg.TypeString}, {Name: "score", Type: schemapkg.TypeNumber}}

	msg := "Here is my assessment:\n```json\n{\"decision\": \"approve\", \"score\": 8}\n```\nLet me know if you need more."
	out, err := coerceDeclaredOutputs(msg, fields)
	if err != nil || out["decision"] != "approve" {
		t.Fatalf("prose-before-fence JSON must parse to the field map, got %#v err=%v", out, err)
	}
	// Bare JSON (no fence) still works.
	if out2, err := coerceDeclaredOutputs(`{"decision":"reject","score":2}`, fields); err != nil || out2["decision"] != "reject" {
		t.Fatalf("bare JSON must still parse, got %#v err=%v", out2, err)
	}
	// Pure prose (no JSON anywhere) with 2+ declared fields still fails loudly (F40).
	if _, err := coerceDeclaredOutputs("just some words about the decision", fields); err == nil {
		t.Fatal("pure prose with 2+ fields must still fail loudly")
	}
}

func TestService_InvokeWithoutDepsFails(t *testing.T) {
	svc, ctx := newSvc(t)
	a, _, _ := svc.Create(ctx, CreateInput{Name: "x", Config: Config{Prompt: "p"}})
	if _, err := svc.InvokeAgent(ctx, InvokeInput{AgentID: a.ID}); err == nil {
		t.Fatal("expected error when invoke deps not configured")
	}
}

type fakeKeyChecker struct{ known map[string]bool }

func (f fakeKeyChecker) KeyExists(_ context.Context, id string) error {
	if f.known[id] {
		return nil
	}
	return apikeydomain.ErrNotFound
}

// TestCreate_RejectsDanglingModelOverrideKey pins F153 for the agent override write path: a modelOverride
// pointing at a non-existent apiKeyId is rejected at WRITE with API_KEY_NOT_FOUND (was 200-then-invoke);
// a real key passes — even with a typo'd modelId (modelId stays fail-loud at invoke).
func TestCreate_RejectsDanglingModelOverrideKey(t *testing.T) {
	svc, ctx := newSvc(t)
	svc.SetKeyChecker(fakeKeyChecker{known: map[string]bool{"aki_real": true}})

	_, _, err := svc.Create(ctx, CreateInput{Name: "bad", Config: Config{Prompt: "p",
		ModelOverride: &modeldomain.ModelRef{APIKeyID: "aki_deadbeef", ModelID: "m"}}})
	if !errors.Is(err, apikeydomain.ErrNotFound) {
		t.Fatalf("dangling apiKeyId must reject at write with API_KEY_NOT_FOUND, got %v", err)
	}
	if _, _, err := svc.Create(ctx, CreateInput{Name: "ok", Config: Config{Prompt: "p",
		ModelOverride: &modeldomain.ModelRef{APIKeyID: "aki_real", ModelID: "deepseek-typo-v9"}}}); err != nil {
		t.Fatalf("a real apiKeyId must pass even with a typo'd modelId: %v", err)
	}
}
