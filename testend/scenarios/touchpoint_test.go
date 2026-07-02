package scenarios

import (
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// Touchpoint — the conversation context ledger (docs/references/backend/domains/touchpoint.md):
// every external thing a conversation touches lands as ONE aggregate row per
// (conversation, item, verb). This scenario walks the whole surface black-box: the user-side
// taps (@mention → mentioned, attachment → attached), the AI-side tap (tool choke point →
// viewed), aggregation (count bumps, no new row), name-snapshot hydration, the paged/filtered
// REST read (+ enum-checked filters), the durable messages-stream `touchpoint` signal, and
// the delete cascade.
//
// Touchpoint——对话上下文台账:对话碰过的一切外部之物,按 (对话,物,动词) 聚成一行。本场景黑盒
// 走完整面:用户侧水龙头(@提及→mentioned、附件→attached)、AI 侧水龙头(工具咽喉→viewed)、
// 聚合(count 递进、不长新行)、名字快照 hydrate、分页/过滤 REST 读(+枚举校验)、messages 流
// durable `touchpoint` 信号、删除级联。
type touchpointRow struct {
	ID            string `json:"id"`
	ItemKind      string `json:"itemKind"`
	ItemID        string `json:"itemId"`
	ItemName      string `json:"itemName"`
	Verb          string `json:"verb"`
	LastActor     string `json:"lastActor"`
	Count         int    `json:"count"`
	LastMessageID string `json:"lastMessageId"`
}

func listTouchpoints(t *testing.T, wc *harness.Client, convID, query string) []touchpointRow {
	t.Helper()
	var rows []touchpointRow
	wc.GET("/api/v1/conversations/"+convID+"/touchpoints"+query).OK(t, &rows)
	return rows
}

func findRow(rows []touchpointRow, verb, itemID string) *touchpointRow {
	for i := range rows {
		if rows[i].Verb == verb && rows[i].ItemID == itemID {
			return &rows[i]
		}
	}
	return nil
}

func TestTouchpoint_LedgerEndToEnd(t *testing.T) {
	wc, mock := chatSetup(t, false)
	fnID := fnCreate(t, wc, "tp_probe",
		"def probe() -> dict:\n    return {\"ok\": True}\n")
	attID := wc.Upload(t, "/api/v1/attachments", "notes.txt", "text/plain", []byte("hello ledger")).Field(t, "id")

	// Turn 1: the model views the mentioned function via get_function. 回合1:模型 get_function 看它。
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "get_function", Args: map[string]any{
			"functionId": fnID,
			"summary":    "Inspect the probe", "danger": "safe", "execution_group": 1,
		}}}},
		harness.LLMTurn{Text: "inspected."},
	)

	sse := wc.Subscribe(t, "messages")
	convID := convCreate(t, wc, "ledger e2e")
	mid := wc.POST("/api/v1/conversations/"+convID+"/messages", map[string]any{
		"content":       "look at my probe function",
		"attachmentIds": []string{attID},
		"mentions":      []map[string]any{{"type": "function", "id": fnID}},
	}).Field(t, "id")
	if turn := waitTurn(t, wc, convID, mid, 30000); turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s %s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	// The ledger holds exactly the three touches, each with the right actor + hydrated name.
	// 台账恰好三行,actor 与名字快照各就各位。
	var rows []touchpointRow
	harness.Eventually(t, 10000, "three ledger rows land", func() bool {
		rows = listTouchpoints(t, wc, convID, "")
		return len(rows) == 3
	})
	mentioned := findRow(rows, "mentioned", fnID)
	if mentioned == nil || mentioned.ItemKind != "function" || mentioned.LastActor != "user" ||
		mentioned.ItemName != "tp_probe" || mentioned.Count != 1 || mentioned.LastMessageID == "" {
		t.Fatalf("mentioned row wrong: %+v", rows)
	}
	attached := findRow(rows, "attached", attID)
	if attached == nil || attached.ItemKind != "attachment" || attached.LastActor != "user" ||
		attached.ItemName != "notes.txt" {
		t.Fatalf("attached row wrong (filename snapshot must hydrate): %+v", rows)
	}
	viewed := findRow(rows, "viewed", fnID)
	if viewed == nil || viewed.ItemKind != "function" || viewed.LastActor != "assistant" ||
		viewed.ItemName != "tp_probe" {
		t.Fatalf("viewed row wrong: %+v", rows)
	}

	// The live signal rode the messages stream (durable node.type=touchpoint, conversation scope).
	// 实时信号已上 messages 流(durable、node.type=touchpoint、对话 scope)。
	sse.WaitFor(t, 5000, "touchpoint signal on the messages stream", "touchpoint", convID, fnID)

	// Turn 2: mention the SAME function again — the aggregate bumps, no new row.
	// 回合2:再 @ 同一函数——聚合递进、不长新行。
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "noted."})
	mid2 := wc.POST("/api/v1/conversations/"+convID+"/messages", map[string]any{
		"content":  "same probe again",
		"mentions": []map[string]any{{"type": "function", "id": fnID}},
	}).Field(t, "id")
	if turn := waitTurn(t, wc, convID, mid2, 30000); turn.Status != "completed" {
		t.Fatalf("turn 2 must complete, got %s", turn.Status)
	}
	harness.Eventually(t, 10000, "mentioned count bumps to 2 without a new row", func() bool {
		rows = listTouchpoints(t, wc, convID, "")
		m := findRow(rows, "mentioned", fnID)
		return len(rows) == 3 && m != nil && m.Count == 2 && m.LastMessageID != mentioned.LastMessageID
	})

	// Filters: kind narrows, verb narrows, junk filters fail loudly with stable codes (N1).
	// 过滤:kind/verb 收窄;垃圾过滤器带稳定码大声失败。
	if got := listTouchpoints(t, wc, convID, "?kind=attachment"); len(got) != 1 || got[0].ItemID != attID {
		t.Fatalf("kind filter: %+v", got)
	}
	if got := listTouchpoints(t, wc, convID, "?verb=viewed"); len(got) != 1 || got[0].Verb != "viewed" {
		t.Fatalf("verb filter: %+v", got)
	}
	wc.GET("/api/v1/conversations/"+convID+"/touchpoints?kind=gizmo").Fail(t, 400, "TP_INVALID_KIND")
	wc.GET("/api/v1/conversations/"+convID+"/touchpoints?verb=poked").Fail(t, 400, "TP_INVALID_VERB")

	// Pagination: limit=2 pages the three rows with a live cursor. 分页:limit=2 三行两页。
	r := wc.GET("/api/v1/conversations/" + convID + "/touchpoints?limit=2")
	if r.Status != 200 || !r.HasMore || r.NextCursor == "" {
		t.Fatalf("page 1 must have more: status=%d hasMore=%v", r.Status, r.HasMore)
	}
	var page2 []touchpointRow
	wc.GET("/api/v1/conversations/"+convID+"/touchpoints?limit=2&cursor="+r.NextCursor).OK(t, &page2)
	if len(page2) != 1 {
		t.Fatalf("page 2 must hold the last row: %+v", page2)
	}

	// Delete cascade: the conversation dies, its ledger goes with it. 删除级联:对话死、台账随之。
	wc.DELETE("/api/v1/conversations/"+convID).OK(t, nil)
	harness.Eventually(t, 10000, "ledger purged with the conversation", func() bool {
		return len(listTouchpoints(t, wc, convID, "")) == 0
	})
}

// TestTouchpoint_BuildToolRecordsCreated pins the OUTPUT-keyed extraction path: create_function's
// new id exists only in the tool's output JSON, yet the ledger books a `created` row for it.
//
// TestTouchpoint_BuildToolRecordsCreated 钉 output 键提取路径:create_function 的新 id 只在工具
// 输出 JSON 里,台账仍记下 `created` 行。
func TestTouchpoint_BuildToolRecordsCreated(t *testing.T) {
	wc, mock := chatSetup(t, false)
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "create_function", Args: map[string]any{
			"ops": []map[string]any{
				{"op": "set_meta", "name": "born_in_chat", "description": "ledger probe"},
				{"op": "set_code", "code": "def born() -> dict:\n    return {}\n"},
			},
			"summary": "Create the probe", "danger": "safe", "execution_group": 1,
		}}}},
		harness.LLMTurn{Text: "created."},
	)
	convID := convCreate(t, wc, "build ledger")
	mid := sendMsg(t, wc, convID, "create a function called born_in_chat")
	if turn := waitTurn(t, wc, convID, mid, 60000); turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s %s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	var created *touchpointRow
	harness.Eventually(t, 10000, "created row lands with the output-extracted id", func() bool {
		rows := listTouchpoints(t, wc, convID, "?verb=created")
		if len(rows) != 1 {
			return false
		}
		created = &rows[0]
		return true
	})
	if created.ItemKind != "function" || !strings.HasPrefix(created.ItemID, "fn_") ||
		created.ItemName != "born_in_chat" || created.LastActor != "assistant" {
		t.Fatalf("created row wrong: %+v", created)
	}
}
