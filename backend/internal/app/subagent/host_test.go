package subagent

import (
	"testing"

	chatdomain "github.com/sunweilin/forgify/backend/internal/domain/chat"
)

// TestSubagentStatusToEventLog_AllChatdomainStatusesCovered guards the §17.11 contract:
// every chatdomain.Status* value must be matched in subagentStatusToEventLog's switch,
// preventing subagent host drift from chat host when a new chatdomain.Status* is added.
//
// TestSubagentStatusToEventLog_AllChatdomainStatusesCovered 守 §17.11 契约：
// subagentStatusToEventLog switch 必须覆盖每个 chatdomain.Status*；防 subagent 与 chat host 漂移。
func TestSubagentStatusToEventLog_AllChatdomainStatusesCovered(t *testing.T) {
	for _, s := range chatdomain.AllStatuses {
		if _, ok := subagentStatusToEventLog(s); !ok {
			t.Errorf("subagentStatusToEventLog: chatdomain.%q fell through to default branch", s)
		}
	}
}
