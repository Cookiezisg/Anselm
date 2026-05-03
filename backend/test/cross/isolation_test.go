//go:build pipeline

// isolation_test.go — cross-user data isolation tests.
// Verifies that resources created by one user are not visible to or modifiable
// by another user, using direct service-layer calls with different user
// contexts. HTTP middleware hard-codes local-user, so isolation is tested
// at the service level where user-scoping is enforced by repositories.
//
// isolation_test.go — 跨用户数据隔离测试。
// 验证一个用户创建的资源对另一个用户不可见也不可操作，直接用不同 user ctx
// 调 service 层（HTTP 中间件硬编码 local-user，隔离在 repo 层强制执行）。
package cross

import (
	"errors"
	"testing"

	apikeyapp "github.com/sunweilin/forgify/backend/internal/app/apikey"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	convdomain "github.com/sunweilin/forgify/backend/internal/domain/conversation"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// ── Conversation isolation ────────────────────────────────────────────────────

func TestIsolation_Conversation_User2CannotDeleteUser1Conv(t *testing.T) {
	h := th.New(t)

	// user-001 creates a conversation.
	// user-001 创建对话。
	conv, err := h.Conversation.Create(th.LocalCtxAs("user-001"), "user-001 private conv")
	if err != nil {
		t.Fatalf("create as user-001: %v", err)
	}

	// user-002 tries to delete it → ErrNotFound (repo scopes by userID).
	// user-002 尝试删除 → ErrNotFound（repo 按 userID 过滤）。
	err = h.Conversation.Delete(th.LocalCtxAs("user-002"), conv.ID)
	if !errors.Is(err, convdomain.ErrNotFound) {
		t.Errorf("expected ErrNotFound for cross-user delete, got: %v", err)
	}
}

func TestIsolation_Conversation_User2ListSeesOnlyOwnData(t *testing.T) {
	h := th.New(t)

	// user-001 creates two conversations.
	// user-001 创建两个对话。
	ctx1 := th.LocalCtxAs("user-001")
	for i := range 2 {
		if _, err := h.Conversation.Create(ctx1, "conv"); err != nil {
			t.Fatalf("create conv %d: %v", i, err)
		}
	}

	// user-002 lists → sees none of user-001's conversations.
	// user-002 列出 → 看不到 user-001 的对话。
	items, _, err := h.Conversation.List(th.LocalCtxAs("user-002"), convdomain.ListFilter{Limit: 50})
	if err != nil {
		t.Fatalf("list as user-002: %v", err)
	}
	if len(items) != 0 {
		t.Errorf("user-002 sees %d conversations; should see 0 (all belong to user-001)",
			len(items))
	}
}

// ── APIKey isolation ──────────────────────────────────────────────────────────

func TestIsolation_APIKey_User2ListSeesOnlyOwnData(t *testing.T) {
	h := th.New(t)

	// user-001 creates an API key.
	// user-001 创建一个 API key。
	if _, err := h.APIKey.Create(th.LocalCtxAs("user-001"), apikeyapp.CreateInput{
		Provider:    th.ProviderDeepSeek,
		DisplayName: "user-001 key",
		Key:         "sk-fake-u1",
	}); err != nil {
		t.Fatalf("create apikey as user-001: %v", err)
	}

	// user-002 lists → sees no keys.
	// user-002 列出 → 无 key。
	items, _, err := h.APIKey.List(th.LocalCtxAs("user-002"), apikeydomain.ListFilter{Limit: 50})
	if err != nil {
		t.Fatalf("list as user-002: %v", err)
	}
	if len(items) != 0 {
		t.Errorf("user-002 sees %d API keys; should see 0", len(items))
	}
}
