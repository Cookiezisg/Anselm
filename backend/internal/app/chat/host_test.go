package chat

import (
	"testing"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
)

// TestChatStatusToEventLog_AllChatdomainStatusesCovered guards the §17.11 contract:
// every chatdomain.Status* value must be matched in chatStatusToEventLog's switch.
// Adding a new Status* without extending the switch (or AllStatuses) trips this test.
//
// TestChatStatusToEventLog_AllChatdomainStatusesCovered 守 §17.11 契约：
// chatStatusToEventLog switch 必须覆盖每个 chatdomain.Status*；漏写则此测试爆。
func TestChatStatusToEventLog_AllChatdomainStatusesCovered(t *testing.T) {
	for _, s := range chatdomain.AllStatuses {
		if _, ok := chatStatusToEventLog(s); !ok {
			t.Errorf("chatStatusToEventLog: chatdomain.%q fell through to default branch", s)
		}
	}
}
