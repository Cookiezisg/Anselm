package chat

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	toolapp "github.com/sunweilin/forgify/backend/internal/app/tool"
	convdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
)

type fakePromptProvider struct {
	text string
}

func (f *fakePromptProvider) GetForSystemPrompt(_ context.Context) string { return f.text }

func TestBuildSystemPrompt_NilProvider_SkipsCatalogBlock(t *testing.T) {
	s := &Service{}
	conv := &convdomain.Conversation{}
	got := s.buildSystemPrompt(context.Background(), conv)
	if !strings.Contains(got, "You are Forgify") {
		t.Errorf("base prompt lost: %q", got)
	}
	if strings.Contains(got, "## Available capabilities") {
		t.Errorf("catalog block leaked into system prompt with nil provider:\n%s", got)
	}
}

func TestBuildSystemPrompt_EmptyProviderText_SkipsCatalogBlock(t *testing.T) {
	s := &Service{catalog: &fakePromptProvider{text: ""}}
	conv := &convdomain.Conversation{}
	got := s.buildSystemPrompt(context.Background(), conv)

	if strings.Contains(got, "## Available capabilities") {
		t.Errorf("catalog block leaked into system prompt with empty provider:\n%s", got)
	}
}

func TestBuildSystemPrompt_NonEmptyProvider_InjectsCatalogBlock(t *testing.T) {
	provider := &fakePromptProvider{text: "## Available capabilities\n- 5 forges...\n"}
	s := &Service{catalog: provider}
	conv := &convdomain.Conversation{}
	got := s.buildSystemPrompt(context.Background(), conv)

	if !strings.Contains(got, "You are Forgify") {
		t.Errorf("base prompt lost: %q", got)
	}
	if !strings.Contains(got, "## Available capabilities") {
		t.Errorf("catalog block missing from system prompt:\n%s", got)
	}
	if !strings.Contains(got, "5 forges") {
		t.Errorf("catalog body missing:\n%s", got)
	}
	if idx := strings.Index(got, "## Available capabilities"); idx <= strings.Index(got, "You are Forgify") {
		t.Errorf("catalog block came before intro; ordering wrong:\n%s", got)
	}
}

func TestBuildSystemPrompt_ConvSystemPromptStillIncluded(t *testing.T) {
	s := &Service{catalog: &fakePromptProvider{text: "## CAT"}}
	conv := &convdomain.Conversation{SystemPrompt: "extra CONV hint"}
	got := s.buildSystemPrompt(context.Background(), conv)
	if !strings.Contains(got, "extra CONV hint") {
		t.Errorf("conv.SystemPrompt lost: %q", got)
	}
	if !strings.Contains(got, "## CAT") {
		t.Errorf("catalog block lost: %q", got)
	}
}

func TestSetSystemPromptProvider_AfterConstruction(t *testing.T) {
	s := &Service{}
	if s.catalog != nil {
		t.Fatal("catalog non-nil before setter called")
	}
	provider := &fakePromptProvider{text: "## hello"}
	s.SetSystemPromptProvider(provider)
	if s.catalog == nil {
		t.Fatal("catalog still nil after setter")
	}
	if got := s.catalog.GetForSystemPrompt(context.Background()); got != "## hello" {
		t.Errorf("setter wired wrong provider; got %q", got)
	}
}

func TestSystemPromptSections_RewrittenSections(t *testing.T) {
	s := &Service{}
	conv := &convdomain.Conversation{}
	sections := s.SystemPromptSections(context.Background(), conv)

	got := map[string]string{}
	order := make([]string, 0, len(sections))
	for _, sec := range sections {
		got[sec.Name] = sec.Content
		order = append(order, sec.Name)
		if sec.Name != strings.ToLower(sec.Name) {
			t.Errorf("section name not snake_case: %q", sec.Name)
		}
	}

	for _, want := range []string{"identity", "how_to_work", "tools", "environment"} {
		if _, ok := got[want]; !ok {
			t.Errorf("missing section %q; order: %v", want, order)
		}
	}
	for _, gone := range []string{"base", "tool_conventions", "multi_agent_forging", "locale_hint", "user_systemPrompt"} {
		if _, ok := got[gone]; ok {
			t.Errorf("retired section %q still present; order: %v", gone, order)
		}
	}

	// Static head is identity → how_to_work → tools (cache-friendly, deterministic).
	if len(order) < 3 || order[0] != "identity" || order[1] != "how_to_work" || order[2] != "tools" {
		t.Errorf("static head order wrong; want identity/how_to_work/tools, got: %v", order)
	}

	if !strings.Contains(got["tools"], "execution_group") || !strings.Contains(got["tools"], "destructive") {
		t.Errorf("tools section dropped standard-field teaching: %q", got["tools"])
	}
	if !strings.Contains(got["identity"], "You are Forgify") {
		t.Errorf("identity section lost brand line: %q", got["identity"])
	}
	if !strings.Contains(got["environment"], "reply language") {
		t.Errorf("environment section missing reply-language: %q", got["environment"])
	}
}

// stubTool satisfies toolapp.Tool minimally for toolset construction in tests.
type stubTool struct{ name string }

func (st *stubTool) Name() string            { return st.name }
func (st *stubTool) Description() string     { return "" }
func (st *stubTool) Parameters() json.RawMessage {
	return json.RawMessage(`{"type":"object","properties":{},"required":[]}`)
}
func (st *stubTool) IsReadOnly() bool                                                             { return false }
func (st *stubTool) NeedsReadFirst() bool                                                         { return false }
func (st *stubTool) RequiresWorkspace() bool                                                      { return false }
func (st *stubTool) ValidateInput(_ json.RawMessage) error                                        { return nil }
func (st *stubTool) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
	return toolapp.PermissionAllow
}
func (st *stubTool) Execute(_ context.Context, _ string) (string, error) { return "", nil }

func TestSystemPromptSections_CapabilitiesSection_WithLazyGroupsAndCatalog(t *testing.T) {
	ts := toolapp.Toolset{
		Lazy: map[string][]toolapp.Tool{
			"function": {&stubTool{name: "create_function"}},
			"handler":  {&stubTool{name: "create_handler"}},
		},
	}
	catalog := &fakePromptProvider{text: "## Available capabilities\n- 3 forges in your library\n"}
	s := &Service{catalog: catalog}
	s.SetToolset(ts)

	conv := &convdomain.Conversation{}
	sections := s.SystemPromptSections(context.Background(), conv)

	var cap *PromptSection
	for i := range sections {
		if sections[i].Name == "capabilities" {
			cap = &sections[i]
			break
		}
	}
	if cap == nil {
		t.Fatal("capabilities section missing from SystemPromptSections")
	}
	if !strings.Contains(cap.Content, "activate_tools") {
		t.Errorf("capabilities content missing 'activate_tools' lead-in: %q", cap.Content)
	}
	if !strings.Contains(cap.Content, "function") {
		t.Errorf("capabilities content missing 'function' group line: %q", cap.Content)
	}
	if !strings.Contains(cap.Content, "handler") {
		t.Errorf("capabilities content missing 'handler' group line: %q", cap.Content)
	}
	// Asset menu (b) should appear under ## Your library
	if !strings.Contains(cap.Content, "## Your library") {
		t.Errorf("capabilities content missing '## Your library' header: %q", cap.Content)
	}
	if !strings.Contains(cap.Content, "3 forges") {
		t.Errorf("capabilities content missing catalog body '3 forges': %q", cap.Content)
	}
	// No old "catalog" section should appear
	for _, sec := range sections {
		if sec.Name == "catalog" {
			t.Errorf("old 'catalog' section must not appear alongside 'capabilities'")
		}
	}
}

func TestSystemPromptSections_CapabilitiesSection_EmptyLazyNilCatalog(t *testing.T) {
	// Both empty → no capabilities section at all.
	s := &Service{}
	conv := &convdomain.Conversation{}
	sections := s.SystemPromptSections(context.Background(), conv)

	for _, sec := range sections {
		if sec.Name == "capabilities" {
			t.Errorf("capabilities section should be absent when toolset.Lazy empty and catalog nil; got sections: %v",
				func() []string {
					names := make([]string, len(sections))
					for i, ss := range sections {
						names[i] = ss.Name
					}
					return names
				}())
		}
	}
}

func TestSystemPromptSections_CapabilitiesSection_OnlyLazyNoLabel(t *testing.T) {
	// Lazy with an unknown category still renders with the raw category name.
	ts := toolapp.Toolset{
		Lazy: map[string][]toolapp.Tool{
			"workflow": {&stubTool{name: "run_workflow"}},
		},
	}
	s := &Service{}
	s.SetToolset(ts)

	conv := &convdomain.Conversation{}
	sections := s.SystemPromptSections(context.Background(), conv)

	var cap *PromptSection
	for i := range sections {
		if sections[i].Name == "capabilities" {
			cap = &sections[i]
			break
		}
	}
	if cap == nil {
		t.Fatal("capabilities section missing when lazy non-empty but catalog nil")
	}
	if !strings.Contains(cap.Content, "workflow") {
		t.Errorf("capabilities content missing 'workflow': %q", cap.Content)
	}
	// No ## Your library when catalog is nil
	if strings.Contains(cap.Content, "## Your library") {
		t.Errorf("'## Your library' should be absent with nil catalog: %q", cap.Content)
	}
}

func TestSystemPromptSections_CapabilitiesSection_OnlyCatalogNoLazy(t *testing.T) {
	// Only catalog text (no lazy groups) → capabilities section exists but no tool-group index.
	catalog := &fakePromptProvider{text: "## Available capabilities\n- 2 forges\n"}
	s := &Service{catalog: catalog}
	conv := &convdomain.Conversation{}
	sections := s.SystemPromptSections(context.Background(), conv)

	var cap *PromptSection
	for i := range sections {
		if sections[i].Name == "capabilities" {
			cap = &sections[i]
			break
		}
	}
	if cap == nil {
		t.Fatal("capabilities section missing when only catalog is non-empty")
	}
	if strings.Contains(cap.Content, "activate_tools") {
		t.Errorf("tool-group index lead-in must be absent when lazy empty: %q", cap.Content)
	}
	if !strings.Contains(cap.Content, "## Your library") {
		t.Errorf("'## Your library' header missing: %q", cap.Content)
	}
	if !strings.Contains(cap.Content, "2 forges") {
		t.Errorf("catalog body missing: %q", cap.Content)
	}
}
