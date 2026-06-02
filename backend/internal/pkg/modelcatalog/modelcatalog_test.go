package modelcatalog

import "testing"

func TestLookup_DeepSeekV4_OneMillionContext(t *testing.T) {
	c := Lookup("deepseek", "deepseek-v4-pro")
	if c.ContextWindow != 1_000_000 {
		t.Fatalf("window=%d want 1M", c.ContextWindow)
	}
	if len(c.Options) == 0 || c.Options[0].Key != "thinking" {
		t.Fatalf("options=%+v, want thinking option", c.Options)
	}
}

func TestLookup_ClaudeOpus48_OneMillionContext(t *testing.T) {
	c := Lookup("anthropic", "claude-opus-4-8")
	if c.ContextWindow != 1_000_000 {
		t.Fatalf("window=%d", c.ContextWindow)
	}
	if len(c.Options) != 2 {
		t.Fatalf("options=%+v, want thinking + context", c.Options)
	}
}

func TestLookup_Sonnet45_200K(t *testing.T) {
	c := Lookup("anthropic", "claude-sonnet-4-5")
	if c.ContextWindow != 200_000 {
		t.Fatalf("window=%d want 200K", c.ContextWindow)
	}
}

func TestLookup_GLM46_HasThinkingToggle(t *testing.T) {
	c := Lookup("zhipu", "glm-4.6")
	if len(c.Options) == 0 || c.Options[0].Key != "thinking" {
		t.Fatalf("options=%+v, want thinking toggle", c.Options)
	}
}

func TestLookup_Unknown_Fallback(t *testing.T) {
	c := Lookup("deepseek", "totally-new-model-2099")
	if c.ContextWindow == 0 {
		t.Fatal("fallback must give nonzero window")
	}
}

func TestLookup_MostSpecificPrefixWins(t *testing.T) {
	c := Lookup("deepseek", "deepseek-v4-flash")
	if c.ContextWindow != 1_000_000 {
		t.Fatalf("v4-flash window=%d want 1M", c.ContextWindow)
	}
}

func TestUsableInput_SubtractsOutputAndBuffer(t *testing.T) {
	c := Capability{ContextWindow: 200_000, MaxOutput: 64_000}
	if got := c.UsableInput(); got != 200_000-64_000-SafetyBuffer {
		t.Fatalf("usable=%d", got)
	}
}

func TestUsableInput_Floor(t *testing.T) {
	c := Capability{ContextWindow: 1000, MaxOutput: 900}
	if got := c.UsableInput(); got != 1000 {
		t.Fatalf("usable=%d want floor 1000", got)
	}
}
