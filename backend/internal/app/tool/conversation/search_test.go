package conversation

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	searchdomain "github.com/sunweilin/anselm/backend/internal/domain/search"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

func TestSearchConversationsParametersAreValidJSON(t *testing.T) {
	var schema any
	if err := json.Unmarshal((&SearchConversations{}).Parameters(), &schema); err != nil {
		t.Fatalf("tool parameter schema must be valid JSON: %v", err)
	}
}

func TestCurrentConversationExclusionUsesConversationScope(t *testing.T) {
	ctx := reqctxpkg.SetConversationID(context.Background(), "cv_current")
	got := currentConversationExclusion(ctx)
	if len(got) != 1 || got[0] != "cv_current" {
		t.Fatalf("exclusion = %v, want current conversation", got)
	}
	if got := currentConversationExclusion(context.Background()); got != nil {
		t.Fatalf("unscoped exclusion = %v, want nil", got)
	}
}

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
	if err := search.ValidateInput([]byte(`{"query":"recall","limit":"10"}`)); err != nil {
		t.Fatalf("exact decimal limit string must be accepted: %v", err)
	}
	for _, raw := range []string{
		`{"query":"recall","limit":1.5}`,
		`{"query":"recall","limit":"ten"}`,
		`{"query":"recall","limit":[]}`,
	} {
		if err := search.ValidateInput([]byte(raw)); err == nil {
			t.Fatalf("invalid limit shape must reject: %s", raw)
		}
	}
}
