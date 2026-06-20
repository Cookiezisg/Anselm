package conversation

import (
	"errors"
	"testing"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
)

// TestSearchConversations_Wiring: group shape + query required (reuses the search domain
// sentinel — same physical violation, same wire code).
//
// TestSearchConversations_Wiring：组形状 + query 必填（复用 search 域 sentinel——同一物理
// 违例、同一 wire code）。
func TestSearchConversations_Wiring(t *testing.T) {
	tools := ConversationTools(nil, nil)
	var search toolapp.Tool
	for _, tl := range tools {
		if tl.Name() == "search_conversations" {
			search = tl
		}
	}
	if search == nil {
		t.Fatalf("search_conversations missing from group: %v", tools)
	}
	if err := search.ValidateInput([]byte(`{"query":"  "}`)); !errors.Is(err, searchdomain.ErrQueryRequired) {
		t.Fatalf("blank query must reject: %v", err)
	}
	if err := search.ValidateInput([]byte(`{"query":"上次的方案"}`)); err != nil {
		t.Fatalf("valid query rejected: %v", err)
	}
}
