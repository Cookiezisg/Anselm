package bootstrap

import (
	"context"
	"testing"

	modelapp "github.com/sunweilin/anselm/backend/internal/app/model"
	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// fakePicker records the scenario it was asked for and returns a fixed default ref.
type fakePicker struct{ lastScenario string }

func (p *fakePicker) Pick(_ context.Context, scenario string) (modeldomain.ModelRef, error) {
	p.lastScenario = scenario
	return modeldomain.ModelRef{APIKeyID: "default_key", ModelID: "default_model"}, nil
}

// fakeCreds records the api-key id it resolved and returns mock-provider credentials (so the real
// factory short-circuits to the MockClient — no network).
type fakeCreds struct{ lastID string }

func (c *fakeCreds) ResolveCredentialsByID(_ context.Context, apiKeyID string) (apikeydomain.Credentials, error) {
	c.lastID = apiKeyID
	return apikeydomain.Credentials{Provider: "mock", Key: "secret", BaseURL: "http://mock", CredentialFingerprint: "credential-revision"}, nil
}

type gatewayCreds struct{}

func (gatewayCreds) ResolveCredentialsByID(_ context.Context, _ string) (apikeydomain.Credentials, error) {
	return apikeydomain.Credentials{Provider: "anselm", Key: "ins_test", BaseURL: "https://api.anselm.website/v1"}, nil
}

// fakeCaps is a CapabilityLister with one usable (mock, default_model) entry carrying caps.
type fakeCaps struct{}

func (fakeCaps) List(context.Context) ([]modelapp.CapabilityView, error) {
	return []modelapp.CapabilityView{
		{
			Provider: "mock", ModelID: "default_model",
			ContextWindow: 100000, MaxOutput: 8000, Vision: true, Video: true, Audio: true, NativeDocs: true,
			MaxMediaParts: 3, MaxMediaBytes: 42,
		},
		{Provider: "anselm", ModelID: "managed_model", ContextWindow: 100000, MaxOutput: 8000, Vision: true, Video: true, MaxMediaParts: 8, MaxMediaBytes: 3 << 20},
	}, nil
}

func newResolvers() (ModelResolvers, *fakePicker, *fakeCreds) {
	pk, cr := &fakePicker{}, &fakeCreds{}
	lookup := NewModelInfoLookup(fakeCaps{})
	return NewModelResolvers(pk, cr, llminfra.NewFactory(), lookup), pk, cr
}

func TestModelResolvers_ScenarioRouting(t *testing.T) {
	rs, pk, cr := newResolvers()
	ctx := context.Background()

	// chat dialogue
	b, err := rs.Chat().ResolveChat(ctx, nil)
	if err != nil {
		t.Fatalf("ResolveChat: %v", err)
	}
	if pk.lastScenario != modeldomain.ScenarioDialogue {
		t.Fatalf("ResolveChat scenario = %q, want dialogue", pk.lastScenario)
	}
	if b.Client == nil || b.Provider != "mock" || b.Request.ModelID != "default_model" {
		t.Fatalf("chat bundle wrong: client=%v provider=%q model=%q", b.Client, b.Provider, b.Request.ModelID)
	}
	if cr.lastID != "default_key" {
		t.Fatalf("creds resolved for %q, want default_key", cr.lastID)
	}
	// External metadata may be stale/custom/route-dependent; it is not an
	// admission budget. Learning starts from an honest unknown (0).
	if b.Request.InputBudgetTokens != 0 {
		t.Fatalf("external InputBudgetTokens = %d, want unknown 0", b.Request.InputBudgetTokens)
	}
	if b.RuntimeProfile.Provider != "mock" || b.RuntimeProfile.APIKeyID != "default_key" ||
		b.RuntimeProfile.EndpointFingerprint == "" || b.RuntimeProfile.CredentialFingerprint == "" || b.RuntimeProfile.ConfigFingerprint == "" {
		t.Fatalf("external runtime profile identity missing: %+v", b.RuntimeProfile)
	}

	// chat utility
	if _, err := rs.Chat().ResolveUtility(ctx); err != nil || pk.lastScenario != modeldomain.ScenarioUtility {
		t.Fatalf("ResolveUtility scenario = %q (err %v), want utility", pk.lastScenario, err)
	}
	// contextmgr utility
	cb, err := rs.ContextmgrUtility().ResolveUtility(ctx)
	if err != nil || cb.Client == nil || pk.lastScenario != modeldomain.ScenarioUtility {
		t.Fatalf("contextmgr utility wrong: scenario=%q err=%v", pk.lastScenario, err)
	}
	// subagent dialogue
	sb, err := rs.Subagent().Resolve(ctx)
	if err != nil || sb.Provider != "mock" || pk.lastScenario != modeldomain.ScenarioDialogue {
		t.Fatalf("subagent resolve wrong: scenario=%q provider=%q err=%v", pk.lastScenario, sb.Provider, err)
	}
	// agent scenario
	ab, err := rs.Agent().ResolveAgent(ctx, nil)
	if err != nil || ab.Client == nil || pk.lastScenario != modeldomain.ScenarioAgent {
		t.Fatalf("agent resolve wrong: scenario=%q err=%v", pk.lastScenario, err)
	}
}

func TestModelResolvers_OverrideWinsSkippingPicker(t *testing.T) {
	rs, pk, cr := newResolvers()
	override := &modeldomain.ModelRef{APIKeyID: "override_key", ModelID: "override_model"}

	b, err := rs.Chat().ResolveChat(context.Background(), override)
	if err != nil {
		t.Fatalf("ResolveChat(override): %v", err)
	}
	// A valid override resolves directly — the picker is never consulted.
	if pk.lastScenario != "" {
		t.Fatalf("override must skip the picker, but it ran scenario %q", pk.lastScenario)
	}
	if cr.lastID != "override_key" || b.Request.ModelID != "override_model" {
		t.Fatalf("override not honored: creds=%q model=%q", cr.lastID, b.Request.ModelID)
	}
}

// fakeConvStore is a minimal ConversationStore for the summary adapter.
type fakeConvStore struct {
	conv      *conversationdomain.Conversation
	setS      string
	setSeq    int64
	setCalled bool
}

func (f *fakeConvStore) Get(_ context.Context, _ string) (*conversationdomain.Conversation, error) {
	return f.conv, nil
}
func (f *fakeConvStore) SetSummary(_ context.Context, _, summary string, coversUpToSeq int64) error {
	f.setS, f.setSeq, f.setCalled = summary, coversUpToSeq, true
	return nil
}

func TestConversationSummary_Adapter(t *testing.T) {
	store := &fakeConvStore{conv: &conversationdomain.Conversation{Summary: "running summary", SummaryCoversUpToSeq: 42}}
	adapter := NewConversationSummary(store)

	gotSummary, gotSeq, err := adapter.GetSummary(context.Background(), "cv_1")
	if err != nil || gotSummary != "running summary" || gotSeq != 42 {
		t.Fatalf("GetSummary = (%q, %d, %v)", gotSummary, gotSeq, err)
	}

	if err := adapter.SetSummary(context.Background(), "cv_1", "new summary", 99); err != nil {
		t.Fatalf("SetSummary: %v", err)
	}
	if !store.setCalled || store.setS != "new summary" || store.setSeq != 99 {
		t.Fatalf("SetSummary not passed through: %+v", store)
	}
}

func TestModelInfoLookup_WindowAndCaps(t *testing.T) {
	lookup := NewModelInfoLookup(fakeCaps{})

	// Only the managed gateway publishes an Anselm-owned authoritative budget.
	wr := lookup.WindowResolver()
	if w, o := wr.ContextBudget(context.Background(), "anselm", "managed_model"); w != 100000 || o != 8000 {
		t.Fatalf("ContextBudget(known) = (%d,%d), want (100000,8000)", w, o)
	}
	if w, o := wr.ContextBudget(context.Background(), "mock", "default_model"); w != 0 || o != 0 {
		t.Fatalf("external ContextBudget must be unknown (0,0), got (%d,%d)", w, o)
	}

	// ...and chat's Bundle.Caps reads vision/native-docs from the same lookup.
	rs, _, _ := newResolvers()
	b, err := rs.Chat().ResolveChat(context.Background(), nil)
	if err != nil {
		t.Fatalf("ResolveChat: %v", err)
	}
	if !b.Caps.Vision || !b.Caps.Video || !b.Caps.Audio || !b.Caps.NativeDocs ||
		b.Caps.MaxMediaParts != 3 || b.Caps.MaxMediaBytes != 42 {
		t.Fatalf("chat Caps must come from the lookup, got %+v", b.Caps)
	}
}

func TestChatResolver_ManagedGatewayStagesMediaWithoutInlineEnvelope(t *testing.T) {
	lookup := NewModelInfoLookup(fakeCaps{})
	resolver := chatResolver{
		core: &modelResolver{
			picker:  &fakePicker{},
			keys:    gatewayCreds{},
			factory: llminfra.NewFactory(),
			windows: lookup.WindowResolver(),
			lookup:  lookup,
		},
		lookup: lookup,
	}
	b, err := resolver.ResolveChat(context.Background(), &modeldomain.ModelRef{APIKeyID: "managed", ModelID: "managed_model"})
	if err != nil {
		t.Fatalf("ResolveChat: %v", err)
	}
	if b.Caps.ManagedGateway == nil || b.Caps.ManagedGateway.BaseURL != "https://api.anselm.website/v1" ||
		b.Caps.ManagedGateway.InstallID != "ins_test" {
		t.Fatalf("managed media target = %+v", b.Caps.ManagedGateway)
	}
	if b.Caps.MaxMediaParts != 0 || b.Caps.MaxMediaBytes != 0 {
		t.Fatalf("remote media must not inherit inline envelope: %+v", b.Caps)
	}
}
