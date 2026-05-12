// runner_test.go — focused unit tests for the chat runner's small,
// pure helpers. Full chat-loop coverage lives in the pipeline test
// suite (test/chat/, test/skill/, test/subagent/) where the FakeLLM
// can drive realistic scenarios; here we only cover the helpers
// where unit testing pays off — buildSystemPrompt's catalog injection
// is the obvious one.
//
// runner_test.go ——chat runner 小而纯 helper 的聚焦单测。完整 chat-loop
// 覆盖在 pipeline test 套件（test/chat/、test/skill/、test/subagent/），
// FakeLLM 能驱动逼真场景；本文件只覆盖单测划算的 helper——buildSystemPrompt
// 的 catalog 注入是显而易见的一个。
package chat

import (
	"context"
	"strings"
	"testing"

	convdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
)

// fakePromptProvider implements catalogdomain.SystemPromptProvider for
// unit testing the catalog injection path. Nil safety is tested with a
// literal nil rather than this stub.
//
// fakePromptProvider 实现 catalogdomain.SystemPromptProvider 给 catalog
// 注入路径单测。Nil 安全测用字面 nil 而非本 stub。
type fakePromptProvider struct {
	text string
}

func (f *fakePromptProvider) GetForSystemPrompt() string { return f.text }

func TestBuildSystemPrompt_NilProvider_SkipsCatalogBlock(t *testing.T) {
	s := &Service{}
	conv := &convdomain.Conversation{}
	got := s.buildSystemPrompt(context.Background(), conv)
	if !strings.Contains(got, "You are Forgify") {
		t.Errorf("base prompt lost: %q", got)
	}
	// Catalog block when present starts with '## Available capabilities'.
	// Multi-agent forging block (Plan 06 F2) also starts with '## ' but
	// is always present — so we look for the catalog-specific marker
	// instead of any '## ' prefix.
	// catalog 块存在时以 '## Available capabilities' 起;multi-agent forging
	// 块(F2)也以 '## ' 起但永远存在,所以专门看 catalog 标记。
	if strings.Contains(got, "## Available capabilities") {
		t.Errorf("catalog block leaked into system prompt with nil provider:\n%s", got)
	}
}

func TestBuildSystemPrompt_EmptyProviderText_SkipsCatalogBlock(t *testing.T) {
	// Provider is non-nil but returns empty (boot window before first
	// Refresh tick). buildSystemPrompt must NOT inject a catalog block,
	// though the multi-agent forging block (Plan 06 F2) is always present.
	// Provider 非 nil 返空(首 Refresh 前 boot 窗口);catalog 块该跳,但
	// multi-agent forging 块(F2)永远在。
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
	// Catalog block should come after the base prompt (chat.runner.md /
	// catalog.md §8.1 design: prepend AFTER intro, BEFORE locale hint).
	// catalog 块应在基础 prompt 之后（chat.runner.md / catalog.md §8.1：
	// intro 之后、locale 之前注入）。
	if idx := strings.Index(got, "## Available capabilities"); idx <= strings.Index(got, "You are Forgify") {
		t.Errorf("catalog block came before intro; ordering wrong:\n%s", got)
	}
}

func TestBuildSystemPrompt_ConvSystemPromptStillIncluded(t *testing.T) {
	// Per-conversation custom system prompt and catalog block are
	// independent — both should appear when both are set.
	// per-conversation 定制 system prompt 与 catalog 块独立——同时设置
	// 时都该出现。
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

// TestBuildSystemPrompt_AlwaysIncludesMultiAgentForging — Plan 06 F2 +
// D21 教学:multi-agent forging 块永远拼到每对话 system prompt(独立于
// catalog provider 状态)。教主 LLM 何时并发 spawn forger 子 agent +
// sub-agent 无 workflow ops + workflow 装配主 agent 独享。
//
// multi-agent forging 块永远在(独立于 catalog provider);测试覆盖关键
// keyword。
func TestBuildSystemPrompt_AlwaysIncludesMultiAgentForging(t *testing.T) {
	// 3 个 catalog 配置 (nil / empty / non-empty) 全应含 multi-agent 段。
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
	// SetSystemPromptProvider should plug the dependency post-
	// construction — verifies the setter actually mutates Service.catalog
	// (rather than being a no-op).
	// SetSystemPromptProvider 后置注入依赖——验 setter 真改 Service.catalog
	// （非 no-op）。
	s := &Service{}
	if s.catalog != nil {
		t.Fatal("catalog non-nil before setter called")
	}
	provider := &fakePromptProvider{text: "## hello"}
	s.SetSystemPromptProvider(provider)
	if s.catalog == nil {
		t.Fatal("catalog still nil after setter")
	}
	if got := s.catalog.GetForSystemPrompt(); got != "## hello" {
		t.Errorf("setter wired wrong provider; got %q", got)
	}
}
