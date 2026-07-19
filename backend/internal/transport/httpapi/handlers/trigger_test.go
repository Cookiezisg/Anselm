package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// TestListFirings_BothURLsReachOneHandler — the firing inbox answers on TWO URLs (scheduler 工单⑭):
// the workspace-level GET /firings (the Overview's 24h track, which cannot be served by paging one
// trigger at a time) and the per-trigger GET /triggers/{id}/firings (the entities ocean's trigger
// observability tab — a LIVE frontend consumer). Both must stay registered and both must land on the
// same handler, because dropping either is a silent breakage: the nested one is called by shipped
// frontend code, and the flat one is the only answer to a workspace-scoped question.
//
// Driven through the 422 path, which is decided before the service is ever touched — so this pins the
// ROUTING (and the filter grammar's error code) without standing up a store.
//
// TestListFirings_BothURLsReachOneHandler——firing 收件箱在**两个** URL 上应答（scheduler 工单⑭）：
// workspace 级的 GET /firings（Overview 的 24h 轨道，逐 trigger 翻是答不了的）与逐 trigger 的
// GET /triggers/{id}/firings（entities 海洋 trigger 观测 tab——**现役**前端消费者）。两者都必须注册、
// 且都必须落到同一个 handler：少任何一个都是静默破坏——嵌套那个被已发布的前端代码调用，扁平那个是
// workspace 尺度问题的唯一答案。
//
// 经 422 路径驱动——它在碰到 service 之前就判定了，故本测试无需立起 store 就能钉住**路由**（与过滤文法
// 的错误码）。
func TestListFirings_BothURLsReachOneHandler(t *testing.T) {
	// A nil service is safe here: an unparseable ?createdAfter is rejected before any read.
	h := NewTriggerHandler(nil, nil, nil)
	mux := http.NewServeMux()
	h.Register(mux)

	for _, url := range []string{
		"/api/v1/firings?createdAfter=gremlin",                               // workspace-level
		"/api/v1/triggers/trg_00000000000000ab/firings?createdAfter=gremlin", // per-trigger
	} {
		t.Run(url, func(t *testing.T) {
			rec := httptest.NewRecorder()
			mux.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, url, nil))

			// 404 here would mean the route is not registered at all — the regression this pins.
			if rec.Code == http.StatusNotFound {
				t.Fatalf("%s is not registered — a firing URL disappeared", url)
			}
			if rec.Code != http.StatusUnprocessableEntity {
				t.Fatalf("%s: status = %d, want 422", url, rec.Code)
			}
			var body struct {
				Error struct {
					Code    string         `json:"code"`
					Details map[string]any `json:"details"`
				} `json:"error"`
			}
			if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
				t.Fatalf("%s: envelope: %v (%s)", url, err, rec.Body)
			}
			// The code must name the FIRING filter — not the flowrun list's, whose parser is shared.
			if body.Error.Code != "TRIGGER_FIRING_INVALID_FILTER" {
				t.Fatalf("%s: code = %q, want TRIGGER_FIRING_INVALID_FILTER", url, body.Error.Code)
			}
			if body.Error.Details["param"] != "createdAfter" || body.Error.Details["got"] != "gremlin" {
				t.Fatalf("%s: details must carry the offending param + value, got %+v", url, body.Error.Details)
			}
		})
	}
}
