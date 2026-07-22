package scenarios

// flowrun_offset_test.go — WRK-070 B4 黑盒: GET /flowruns 的 offset/页码分页模式。
// offset 模式额外带 total(同过滤总行数)、cursor 模式逐字不变(无 total)、两模式互斥(双给 422)、坏 offset 422。
//
// flowrun_offset_test.go — WRK-070 B4 black-box for GET /flowruns' offset/page-number pagination:
// offset mode adds `total` (the filtered row count), cursor mode is byte-for-byte unchanged (no
// total), the two modes are mutually exclusive (both given → 422), and a malformed offset is a loud
// 422. What black-box CAN prove here that the unit tests cannot: the wire envelope shapes of the two
// modes over a real server + real runs.

import (
	"encoding/json"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// offsetBody decodes the full envelope so `total` (absent from Resp) is observable, plus a raw key
// map so a test can assert a field's PRESENCE/ABSENCE (the cursor-vs-offset disjointness).
//
// offsetBody 解全 envelope,使 `total`(Resp 无此字段)可观测,另带原始键 map 使测试能断言字段的
// 在场/缺席(cursor 与 offset 的互斥)。
type offsetBody struct {
	Data    []json.RawMessage `json:"data"`
	Total   int               `json:"total"`
	HasMore bool              `json:"hasMore"`
	raw     []byte
	keys    map[string]json.RawMessage
}

func (b offsetBody) hasKey(k string) bool { _, ok := b.keys[k]; return ok }

func offsetGet(t *testing.T, wc *harness.Client, query string) offsetBody {
	t.Helper()
	r := wc.GET("/api/v1/flowruns" + query)
	if r.Status != 200 {
		t.Fatalf("GET %s: status %d (%s)", query, r.Status, r.Raw)
	}
	var b offsetBody
	if err := json.Unmarshal(r.Raw, &b); err != nil {
		t.Fatalf("GET %s: decode envelope: %v (%s)", query, err, r.Raw)
	}
	b.raw = r.Raw
	if err := json.Unmarshal(r.Raw, &b.keys); err != nil {
		t.Fatalf("GET %s: decode keys: %v", query, err)
	}
	return b
}

// TestFlowruns_OffsetPagination — WRK-070 B4: drive five real completed runs, then walk the offset
// pages and prove the two pagination modes stay disjoint on the wire.
func TestFlowruns_OffsetPagination(t *testing.T) {
	t.Parallel()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "fr-offset"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	trgID := trgCreate(t, wc, "offset_hook", "webhook", map[string]any{"path": "offp"})
	wfID, _ := wfWithTrigger(t, wc, "offset_pipe", trgID)

	// Five manual runs on this one workflow (a webhook trigger never self-fires, so the workflow's
	// run count is exactly these five). 五个手动 run(webhook trigger 从不自触发,故此 workflow 的 run 数恰为五)。
	const n = 5
	for i := 0; i < n; i++ {
		wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wfID, "payload": map[string]any{}}).OK(t, nil)
	}
	harness.Eventually(t, 30000, "all five runs complete", func() bool {
		return len(listRunRows(t, wc, "?workflowId="+wfID+"&status=completed")) == n
	})

	// offset page 0: two rows, total 5, hasMore true, and NO nextCursor (offset paging has no cursor).
	// offset 第 0 页:两行、total 5、hasMore true,且**无** nextCursor(offset 分页无游标)。
	b := offsetGet(t, wc, "?workflowId="+wfID+"&offset=0&limit=2")
	if len(b.Data) != 2 || b.Total != n || !b.HasMore {
		t.Fatalf("offset page 0: rows=%d total=%d hasMore=%v, want 2/5/true", len(b.Data), b.Total, b.HasMore)
	}
	if b.hasKey("nextCursor") {
		t.Fatalf("offset envelope must NOT carry nextCursor: %s", b.raw)
	}

	// last page: offset 4 → the single oldest row, total still 5, hasMore false.
	// 末页:offset 4 → 单条最旧行、total 仍 5、hasMore false。
	b = offsetGet(t, wc, "?workflowId="+wfID+"&offset=4&limit=2")
	if len(b.Data) != 1 || b.Total != n || b.HasMore {
		t.Fatalf("offset last page: rows=%d total=%d hasMore=%v, want 1/5/false", len(b.Data), b.Total, b.HasMore)
	}

	// overshoot: offset past the end → empty page, total unchanged (the client learns it overshot).
	// 越界:offset 翻过头 → 空页、total 不变(客户端据此知道翻过头了)。
	b = offsetGet(t, wc, "?workflowId="+wfID+"&offset=99&limit=2")
	if len(b.Data) != 0 || b.Total != n {
		t.Fatalf("offset overshoot: rows=%d total=%d, want 0/5", len(b.Data), b.Total)
	}

	// cursor mode is byte-for-byte unchanged: it must NEVER carry total (contract-drift guard).
	// cursor 模式逐字节不变:绝不带 total(契约漂移守卫)。
	cur := offsetGet(t, wc, "?workflowId="+wfID+"&limit=2")
	if cur.hasKey("total") {
		t.Fatalf("cursor mode must NOT carry total (contract drift): %s", cur.raw)
	}

	// two pagination modes at once → loud 422 with the new conflict code.
	// 同时给两种分页模式 → 大声 422、带新的冲突码。
	wc.GET("/api/v1/flowruns?workflowId="+wfID+"&cursor=abc&offset=0").Fail(t, 422, "FLOWRUN_LIST_CURSOR_OFFSET_CONFLICT")
	// a malformed offset alone → loud 422 (shares the list's invalid-filter code, param=offset).
	// 单独给畸形 offset → 大声 422(共用列表的 invalid-filter 码,param=offset)。
	wc.GET("/api/v1/flowruns?offset=-5").Fail(t, 422, "FLOWRUN_LIST_INVALID_FILTER")
	wc.GET("/api/v1/flowruns?offset=abc").Fail(t, 422, "FLOWRUN_LIST_INVALID_FILTER")
}
