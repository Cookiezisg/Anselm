// agentrun_test.go — unit tests for agent-run ID helpers
// (conversationID / messageID / toolCallID).
//
// agentrun_test.go — agent-run ID helpers 的单元测试
// （conversationID / messageID / toolCallID）。
package reqctx

import (
	"context"
	"testing"
)

// ── conversation ID ───────────────────────────────────────────────────────────

func TestSetGetConversationID_RoundTrip(t *testing.T) {
	ctx := WithConversationID(context.Background(), "cv_abc123")

	id, ok := GetConversationID(ctx)
	if !ok {
		t.Fatal("ok: got false, want true after WithConversationID")
	}
	if id != "cv_abc123" {
		t.Errorf("id: got %q, want \"cv_abc123\"", id)
	}
}

func TestGetConversationID_MissingReturnsFalse(t *testing.T) {
	id, ok := GetConversationID(context.Background())
	if ok {
		t.Errorf("ok: got true for empty ctx, want false")
	}
	if id != "" {
		t.Errorf("id: got %q, want empty", id)
	}
}

func TestGetConversationID_EmptyStringReturnsFalse(t *testing.T) {
	// Empty conversation ID treated as missing — same convention as GetUserID.
	// 空 conversation ID 视同缺失——与 GetUserID 一致。
	ctx := WithConversationID(context.Background(), "")
	id, ok := GetConversationID(ctx)
	if ok {
		t.Errorf("ok: got true for empty-string convID, want false")
	}
	if id != "" {
		t.Errorf("id: got %q, want empty", id)
	}
}

// ── message ID ────────────────────────────────────────────────────────────────

func TestSetGetMessageID_RoundTrip(t *testing.T) {
	ctx := WithMessageID(context.Background(), "msg_xyz")
	id, ok := GetMessageID(ctx)
	if !ok || id != "msg_xyz" {
		t.Errorf("got %q ok=%v, want \"msg_xyz\" ok=true", id, ok)
	}
}

func TestGetMessageID_MissingReturnsFalse(t *testing.T) {
	id, ok := GetMessageID(context.Background())
	if ok || id != "" {
		t.Errorf("got %q ok=%v, want empty/false", id, ok)
	}
}

// ── tool-call ID ──────────────────────────────────────────────────────────────

func TestSetGetToolCallID_RoundTrip(t *testing.T) {
	ctx := WithToolCallID(context.Background(), "tc_001")
	id, ok := GetToolCallID(ctx)
	if !ok || id != "tc_001" {
		t.Errorf("got %q ok=%v, want \"tc_001\" ok=true", id, ok)
	}
}

func TestGetToolCallID_MissingReturnsFalse(t *testing.T) {
	id, ok := GetToolCallID(context.Background())
	if ok || id != "" {
		t.Errorf("got %q ok=%v, want empty/false", id, ok)
	}
}

// ── isolation between keys ────────────────────────────────────────────────────

func TestAgentRunIDs_KeyIsolation(t *testing.T) {
	// Stamping one ID must NOT leak into the other slots — each ID has its own
	// private key. Otherwise SetConversationID could be read out via GetMessageID.
	//
	// 注入一个 ID 不得渗透到其他槽位——每个 ID 有自己的私有 key。
	// 否则 SetConversationID 的值可能被 GetMessageID 读到。
	ctx := WithConversationID(context.Background(), "cv_only")

	if _, ok := GetMessageID(ctx); ok {
		t.Error("conversationID leaked into messageID slot")
	}
	if _, ok := GetToolCallID(ctx); ok {
		t.Error("conversationID leaked into toolCallID slot")
	}
}

// ── stacking ──────────────────────────────────────────────────────────────────

func TestAgentRunIDs_StackedRoundTrip(t *testing.T) {
	// All three IDs can coexist on the same ctx.
	// 三个 ID 可同时栖于同一 ctx。
	ctx := WithConversationID(context.Background(), "cv_1")
	ctx = WithMessageID(ctx, "msg_2")
	ctx = WithToolCallID(ctx, "tc_3")

	if id, _ := GetConversationID(ctx); id != "cv_1" {
		t.Errorf("convID: got %q, want \"cv_1\"", id)
	}
	if id, _ := GetMessageID(ctx); id != "msg_2" {
		t.Errorf("msgID: got %q, want \"msg_2\"", id)
	}
	if id, _ := GetToolCallID(ctx); id != "tc_3" {
		t.Errorf("tcID: got %q, want \"tc_3\"", id)
	}
}

// ── private key isolation from string keys ────────────────────────────────────

func TestAgentRunIDs_PrivateKeyIsolation(t *testing.T) {
	// External code with raw string keys must not collide with our private keys.
	// 外部代码用裸 string key 不得与我们的私有 key 冲突。
	//lint:ignore SA1029 intentional: simulating external code that uses a raw string key
	ctx := context.WithValue(context.Background(), "conversationID", "attacker")
	if _, ok := GetConversationID(ctx); ok {
		t.Error("string-keyed value leaked into private conversationID key")
	}
}

func TestSetWithConversationID_CopiesContext(t *testing.T) {
	// With* must return a NEW ctx — parent untouched.
	// With* 必须返回新 ctx，父 ctx 不变。
	parent := context.Background()
	_ = WithConversationID(parent, "child")

	if _, ok := GetConversationID(parent); ok {
		t.Error("parent ctx was mutated by WithConversationID")
	}
}
