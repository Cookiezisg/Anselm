// types_test.go — wire-compat checks for ChatMessage MarshalJSON.
// Critical invariant: when subagent fields are zero, output must be byte-
// identical to json.Marshal(*chatdomain.Message) — i.e. extension is
// fully backward-compatible. When set, the three fields must appear at
// the top level beside the Message fields.
//
// types_test.go ——ChatMessage MarshalJSON 的 wire 兼容检查。关键不变量：
// subagent 字段为零时输出必须与 json.Marshal(*chatdomain.Message) 字节一致
// ——扩展完全向后兼容。设置后三字段必须出现在顶层（与 Message 字段并列）。
package events

import (
	"encoding/json"
	"testing"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
	subagentdomain "github.com/sunweilin/forgify/backend/internal/domain/subagent"
)

func TestChatMessage_NilMessage_EmitsJSONNull(t *testing.T) {
	out, err := json.Marshal(ChatMessage{})
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	if string(out) != "null" {
		t.Errorf("got %q, want null", out)
	}
}

func TestChatMessage_ZeroSubagentFields_ByteIdenticalToMessage(t *testing.T) {
	m := &chatdomain.Message{
		ID:             "msg_1",
		ConversationID: "cv_1",
		Role:           chatdomain.RoleAssistant,
		Status:         chatdomain.StatusCompleted,
	}
	plainBytes, err := json.Marshal(m)
	if err != nil {
		t.Fatalf("Marshal Message: %v", err)
	}
	wrappedBytes, err := json.Marshal(ChatMessage{Message: m})
	if err != nil {
		t.Fatalf("Marshal ChatMessage: %v", err)
	}
	if string(plainBytes) != string(wrappedBytes) {
		t.Errorf("zero-subagent wire drift:\n plain   = %s\n wrapped = %s",
			plainBytes, wrappedBytes)
	}
}

func TestChatMessage_SubagentFields_AppearTopLevel(t *testing.T) {
	m := &chatdomain.Message{
		ID:             "smm_1",
		ConversationID: "cv_main",
		Role:           chatdomain.RoleAssistant,
		Status:         chatdomain.StatusStreaming,
	}
	run := &subagentdomain.SubagentRun{
		ID:                   "sar_xyz",
		ParentConversationID: "cv_main",
		Type:                 "Explore",
		Status:               subagentdomain.StatusRunning,
		TotalTokensIn:        100,
		TotalTokensOut:       50,
	}
	out, err := json.Marshal(ChatMessage{
		Message:              m,
		SubagentRunID:        "sar_xyz",
		ParentConversationID: "cv_main",
		SubagentRun:          run,
	})
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}

	var got map[string]any
	if err := json.Unmarshal(out, &got); err != nil {
		t.Fatalf("Unmarshal back: %v", err)
	}
	if got["id"] != "smm_1" {
		t.Errorf("Message.id missing: got %v", got["id"])
	}
	if got["subagentRunId"] != "sar_xyz" {
		t.Errorf("subagentRunId missing/wrong: %v", got["subagentRunId"])
	}
	if got["parentConversationId"] != "cv_main" {
		t.Errorf("parentConversationId missing/wrong: %v", got["parentConversationId"])
	}
	sub, ok := got["subagentRun"].(map[string]any)
	if !ok {
		t.Fatalf("subagentRun missing or wrong type: %v", got["subagentRun"])
	}
	if sub["id"] != "sar_xyz" {
		t.Errorf("nested run.id wrong: %v", sub["id"])
	}
	if sub["type"] != "Explore" {
		t.Errorf("nested run.type wrong: %v", sub["type"])
	}
}

func TestChatMessage_PartialSubagentFields_NoEmptyKeys(t *testing.T) {
	// Only SubagentRunID set; the other two omitempty.
	// 只设 SubagentRunID；另两个 omitempty 不出现。
	m := &chatdomain.Message{ID: "msg_partial", Role: chatdomain.RoleAssistant}
	out, err := json.Marshal(ChatMessage{
		Message:       m,
		SubagentRunID: "sar_only",
	})
	if err != nil {
		t.Fatalf("Marshal: %v", err)
	}
	var got map[string]any
	_ = json.Unmarshal(out, &got)
	if got["subagentRunId"] != "sar_only" {
		t.Errorf("subagentRunId missing: %v", got["subagentRunId"])
	}
	if _, present := got["parentConversationId"]; present {
		t.Errorf("parentConversationId should be omitted when empty")
	}
	if _, present := got["subagentRun"]; present {
		t.Errorf("subagentRun should be omitted when nil")
	}
}

func TestChatMessage_EventName_Stable(t *testing.T) {
	if got := (ChatMessage{}).EventName(); got != "chat.message" {
		t.Errorf("EventName = %q, want chat.message", got)
	}
}
