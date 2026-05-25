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

func TestBuildSystemPrompt_AlwaysIncludesMultiAgentForging(t *testing.T) {
	cases := []struct {
		name    string
		catalog *fakePromptProvider
	}{
		{"nil-catalog", nil},
		{"empty-catalog", &fakePromptProvider{text: ""}},
		{"populated-catalog", &fakePromptProvider{text: "## Available capabilities\n..."}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			s := &Service{}
			if tc.catalog != nil {
				s.catalog = tc.catalog
			}
			got := s.buildSystemPrompt(context.Background(), &convdomain.Conversation{})
			if !strings.Contains(got, "## Multi-agent forging") {
				t.Errorf("multi-agent section missing:\n%s", got)
			}
			if !strings.Contains(got, "Subagent") {
				t.Errorf("Subagent keyword missing from multi-agent section")
			}
			if !strings.Contains(got, "D21") {
				t.Errorf("D21 awareness missing — sub-agent workflow ops restriction must be taught")
			}
			if !strings.Contains(got, "configState") {
				t.Errorf("configState gate teaching missing")
			}
		})
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

func TestSystemPromptSections_ToolConventionsSection(t *testing.T) {
	s := &Service{}
	conv := &convdomain.Conversation{}
	sections := s.SystemPromptSections(context.Background(), conv)

	var found *PromptSection
	for i := range sections {
		if sections[i].Name == "tool_conventions" {
			found = &sections[i]
			break
		}
	}
	if found == nil {
		t.Fatal("tool_conventions section missing from SystemPromptSections")
	}
	if !strings.Contains(found.Content, "execution_group") {
		t.Errorf("tool_conventions content missing 'execution_group': %q", found.Content)
	}
	if !strings.Contains(found.Content, "destructive") {
		t.Errorf("tool_conventions content missing 'destructive': %q", found.Content)
	}

	// Must appear immediately after "base" (index 1).
	if len(sections) < 2 || sections[1].Name != "tool_conventions" {
		t.Errorf("tool_conventions not at index 1 (after base); order: %v",
			func() []string {
				names := make([]string, len(sections))
				for i, s := range sections {
					names[i] = s.Name
				}
				return names
			}())
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
