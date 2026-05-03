//go:build pipeline

// seed.go — quick fixture helpers built on top of the harness Service layer.
// Use these at the start of a pipeline test to get to "ready to chat" in 1-2 lines.
//
// seed.go — 基于 harness Service 层的 fixture helper。pipeline 测试开头几行就能
// 走到"准备聊天"状态。
package harness

import (
	"context"
	"os"
	"testing"

	apikeyapp "github.com/sunweilin/forgify/backend/internal/app/apikey"
	forgeapp "github.com/sunweilin/forgify/backend/internal/app/forge"
	modelapp "github.com/sunweilin/forgify/backend/internal/app/model"
	convdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	forgedomain "github.com/sunweilin/forgify/backend/internal/domain/forge"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// ProviderDeepSeek is the provider name string the apikey/model layers expect.
// Lives here (not in domain) since the domain treats provider as a free string.
//
// ProviderDeepSeek 是 apikey/model 层期望的 provider 名字字符串。放这里
// （不放 domain）因为 domain 把 provider 当自由字符串。
const ProviderDeepSeek = "deepseek"

// SimpleForgeCode is minimal valid Python for forge tests.
const SimpleForgeCode = `def hello(name: str) -> str:
    """Greet someone.

    Args:
        name: Person's name.

    Returns:
        Greeting message.
    """
    return f"Hello, {name}!"
`

// LocalCtx returns a context stamped with the default local user — the same
// user the InjectUserID middleware stamps for HTTP requests. Use this for
// service-layer calls that bypass HTTP.
//
// LocalCtx 返回打了默认本地用户的 ctx——与 InjectUserID 中间件给 HTTP 请求
// 打的 user 一致。绕过 HTTP 直接调 service 层时用这个。
func (h *Harness) LocalCtx() context.Context {
	return reqctxpkg.SetUserID(context.Background(), reqctxpkg.DefaultLocalUserID)
}

// SeedDeepSeek inserts a DeepSeek API key + chat scenario model config so
// chat flows can resolve credentials. apiKey defaults to env DEEPSEEK_API_KEY
// when empty (use RequireDeepSeekKey to fail-skip on missing).
//
// SeedDeepSeek 插入 DeepSeek API key + chat scenario 模型配置，让 chat 流能
// 解出 credentials。apiKey 为空时用环境 DEEPSEEK_API_KEY（缺时用
// RequireDeepSeekKey 让 test skip）。
func (h *Harness) SeedDeepSeek(t *testing.T, apiKey string) {
	t.Helper()
	if apiKey == "" {
		apiKey = RequireDeepSeekKey(t)
	}
	ctx := h.LocalCtx()

	if _, err := h.APIKey.Create(ctx, apikeyapp.CreateInput{
		Provider:    ProviderDeepSeek,
		DisplayName: "pipeline-deepseek",
		Key:         apiKey,
		BaseURL:     h.fakeLLMBaseURL, // non-empty → routes calls to FakeLLMServer
	}); err != nil {
		t.Fatalf("seed apikey: %v", err)
	}

	if _, err := h.Model.Upsert(ctx, modeldomain.ScenarioChat, modelapp.UpsertInput{
		Provider: ProviderDeepSeek,
		ModelID:  "deepseek-chat",
	}); err != nil {
		t.Fatalf("seed model config: %v", err)
	}
}

// NewConversation creates a fresh conversation via the conversation service.
// Returns the entity (with allocated ID) for further operations.
//
// NewConversation 通过 conversation service 新建一个对话，返回带分配 ID 的 entity。
func (h *Harness) NewConversation(t *testing.T, title string) *convdomain.Conversation {
	t.Helper()
	c, err := h.Conversation.Create(h.LocalCtx(), title)
	if err != nil {
		t.Fatalf("create conversation: %v", err)
	}
	return c
}

// NewForge creates a forge with the given name + Python code via the forge
// service. Code is parsed (AST validated) by the service; on parse failure
// the test fails. Returns the persisted entity.
//
// NewForge 通过 forge service 新建一个 forge（含 AST 校验）。解析失败 fail。
// 返回已落库 entity。
func (h *Harness) NewForge(t *testing.T, name, code string) *forgedomain.Forge {
	t.Helper()
	f, err := h.Forge.Create(h.LocalCtx(), forgeapp.CreateInput{
		Name: name,
		Code: code,
	})
	if err != nil {
		t.Fatalf("create forge %q: %v", name, err)
	}
	return f
}

// RequireForgeResources skips the test if FORGIFY_DEV_RESOURCES is not set
// or if the harness sandbox was not successfully bootstrapped (Python binary
// absent). All forge-sandbox pipeline tests call this at the top.
//
// RequireForgeResources 在 FORGIFY_DEV_RESOURCES 未设置或沙箱 Bootstrap 失败
// （Python 不存在）时 skip 测试。所有 forge sandbox pipeline 测试在开头调用。
func RequireForgeResources(t *testing.T, h *Harness) {
	t.Helper()
	if os.Getenv("FORGIFY_DEV_RESOURCES") == "" {
		t.Skip("FORGIFY_DEV_RESOURCES not set; skipping (run `go run ./cmd/resources` from backend/ first)")
	}
	pythonPath := h.Sandbox.PythonPath()
	if _, err := os.Stat(pythonPath); err != nil {
		t.Skipf("sandbox Python not found at %q (Bootstrap may have failed): %v", pythonPath, err)
	}
}
