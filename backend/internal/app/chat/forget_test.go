package chat

import (
	"testing"

	"go.uber.org/zap"
)

// TestForgetConversationClearsOnlyDeletedConversationGrants locks the chat-side lifecycle hook,
// not just Broker.Forget: deleting one conversation must not leave its approve_always state
// behind, and must not revoke another live conversation's grant.
//
// TestForgetConversationClearsOnlyDeletedConversationGrants 锁住 chat 侧生命周期钩子，而不只是
// Broker.Forget：删除一个对话不能留下其 approve_always 状态，也不能撤销另一个存活对话的授权。
func TestForgetConversationClearsOnlyDeletedConversationGrants(t *testing.T) {
	svc := NewService(newStore(t), Deps{}, zap.NewNop())
	svc.broker.Allow("cv_deleted", "deploy")
	svc.broker.Allow("cv_deleted", "filesystem.Write")
	svc.broker.Allow("cv_live", "deploy")

	svc.ForgetConversation("cv_deleted")

	if svc.broker.IsAllowed("cv_deleted", "deploy") || svc.broker.IsAllowed("cv_deleted", "filesystem.Write") {
		t.Fatal("deleted conversation grants survived ForgetConversation")
	}
	if !svc.broker.IsAllowed("cv_live", "deploy") {
		t.Fatal("ForgetConversation revoked a live conversation grant")
	}
}
