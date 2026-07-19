package response

import (
	"encoding/json"
	"net/http/httptest"
	"testing"
)

func TestSuccessEnvelope(t *testing.T) {
	w := httptest.NewRecorder()
	Success(w, 200, map[string]string{"x": "y"})
	var env map[string]json.RawMessage
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil {
		t.Fatal(err)
	}
	if _, ok := env["data"]; !ok {
		t.Errorf("success must wrap in {data}: %s", w.Body.String())
	}
	if _, ok := env["error"]; ok {
		t.Error("success must not carry error")
	}
}

// TestSuccessEnvelope_NilSliceIsArray — F170: a NON-paged list endpoint (documents/skills/memories) that
// returns a nil slice when empty must still serialize as {"data": []}, never {"data": null} — otherwise
// the same endpoint flips between [] (populated) and null (empty) and breaks a client's `for (x of data)`.
// A single-object body still passes through (not coerced to a slice).
func TestSuccessEnvelope_NilSliceIsArray(t *testing.T) {
	w := httptest.NewRecorder()
	Success(w, 200, []int(nil))
	if got := w.Body.String(); got != "{\"data\":[]}\n" && got != "{\"data\":[]}" {
		t.Fatalf("empty list must be [] not null, got %q", got)
	}
	// A single object must NOT be coerced.
	w2 := httptest.NewRecorder()
	Success(w2, 200, map[string]string{"x": "y"})
	var env struct {
		Data map[string]string `json:"data"`
	}
	if err := json.Unmarshal(w2.Body.Bytes(), &env); err != nil || env.Data["x"] != "y" {
		t.Fatalf("single-object body must pass through untouched, got %q err=%v", w2.Body.String(), err)
	}
}

func TestPagedEnvelope(t *testing.T) {
	w := httptest.NewRecorder()
	Paged(w, []int{1, 2}, "cur1", true)
	var env struct {
		Data       []int   `json:"data"`
		NextCursor *string `json:"nextCursor"`
		HasMore    *bool   `json:"hasMore"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil {
		t.Fatal(err)
	}
	if len(env.Data) != 2 || env.NextCursor == nil || *env.NextCursor != "cur1" || env.HasMore == nil || !*env.HasMore {
		t.Errorf("paged envelope = %s", w.Body.String())
	}
}

// TestPagedEnvelope_EmptyIsArray — F-empty-list-null (round-9 entitydelete): an empty page must
// serialize as {"data": []}, never null or an absent key, so a client iterating data does not NPE (N4).
// Covers both a nil typed slice (the common store-returns-nil case) and an explicit empty slice.
func TestPagedEnvelope_EmptyIsArray(t *testing.T) {
	for _, items := range []any{[]int(nil), []int{}, []string(nil)} {
		w := httptest.NewRecorder()
		Paged(w, items, "", false)
		var raw map[string]json.RawMessage
		if err := json.Unmarshal(w.Body.Bytes(), &raw); err != nil {
			t.Fatalf("unmarshal %s: %v", w.Body.String(), err)
		}
		data, ok := raw["data"]
		if !ok {
			t.Fatalf("empty page must include a data key, got %s", w.Body.String())
		}
		if string(data) != "[]" {
			t.Fatalf("empty page data must be [], got %s (full: %s)", data, w.Body.String())
		}
	}
}

// TestOffsetPagedEnvelope — WRK-070 B4: the offset/page-number envelope carries `total` (the full
// row count under the filter) and computes hasMore = offset+len < total, but NO nextCursor. It is
// the disjoint counterpart of Paged: offset mode adds total, cursor mode never does — the two shapes
// must not blur, or a client's decode drifts.
//
// TestOffsetPagedEnvelope — WRK-070 B4：offset/页码信封带 `total`（过滤下总行数）、算 hasMore =
// offset+len < total，但**无** nextCursor。它是 Paged 的互斥对应物：offset 模式加 total、cursor 模式
// 永不加——两形状不可模糊，否则 client 解码漂移。
func TestOffsetPagedEnvelope(t *testing.T) {
	// Mid-list page: offset 2, two of five rows → hasMore true, total 5, no nextCursor key.
	w := httptest.NewRecorder()
	OffsetPaged(w, []int{3, 4}, 2, 5)
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(w.Body.Bytes(), &raw); err != nil {
		t.Fatalf("unmarshal %s: %v", w.Body.String(), err)
	}
	if _, ok := raw["nextCursor"]; ok {
		t.Fatalf("offset envelope must NOT carry nextCursor, got %s", w.Body.String())
	}
	var env struct {
		Data    []int `json:"data"`
		Total   int   `json:"total"`
		HasMore bool  `json:"hasMore"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil {
		t.Fatal(err)
	}
	if len(env.Data) != 2 || env.Total != 5 || !env.HasMore {
		t.Fatalf("offset envelope = %s (want data:2, total:5, hasMore:true)", w.Body.String())
	}

	// Last page: offset 4, one row, total 5 → hasMore false (4+1 == 5, nothing past this page).
	w2 := httptest.NewRecorder()
	OffsetPaged(w2, []int{5}, 4, 5)
	var env2 struct {
		HasMore bool `json:"hasMore"`
		Total   int  `json:"total"`
	}
	if err := json.Unmarshal(w2.Body.Bytes(), &env2); err != nil {
		t.Fatal(err)
	}
	if env2.HasMore || env2.Total != 5 {
		t.Fatalf("last page must be hasMore:false total:5, got %s", w2.Body.String())
	}

	// An empty page still serializes data as [] (N4), with total preserved (the filter matched rows
	// this offset overshot). 空页 data 仍为 []（N4），total 保留（过滤匹配了行、只是本 offset 翻过头）。
	w3 := httptest.NewRecorder()
	OffsetPaged(w3, []int(nil), 99, 5)
	var raw3 map[string]json.RawMessage
	if err := json.Unmarshal(w3.Body.Bytes(), &raw3); err != nil {
		t.Fatal(err)
	}
	if string(raw3["data"]) != "[]" {
		t.Fatalf("empty offset page data must be [], got %s", w3.Body.String())
	}
	if string(raw3["total"]) != "5" {
		t.Fatalf("empty offset page must keep total, got %s", w3.Body.String())
	}
}

// TestPagedEnvelope_NoTotal guards the disjointness from the other side: the cursor-mode Paged
// envelope must NEVER carry a total (that field belongs to offset mode alone) — a contract that must
// stay byte-for-byte stable so existing clients do not drift.
//
// TestPagedEnvelope_NoTotal 从另一侧守互斥：cursor 模式 Paged 信封**绝不**带 total（那是 offset 模式
// 专属）——此契约须逐字节稳定，免既有 client 漂移。
func TestPagedEnvelope_NoTotal(t *testing.T) {
	w := httptest.NewRecorder()
	Paged(w, []int{1, 2}, "cur1", true)
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(w.Body.Bytes(), &raw); err != nil {
		t.Fatal(err)
	}
	if _, ok := raw["total"]; ok {
		t.Fatalf("cursor-mode Paged must NOT carry total, got %s", w.Body.String())
	}
}

func TestErrorEnvelope(t *testing.T) {
	w := httptest.NewRecorder()
	Error(w, 400, "BAD", "bad thing", map[string]any{"field": "name"})
	if w.Code != 400 {
		t.Errorf("status = %d", w.Code)
	}
	code, msg := decodeErr(t, w.Body.Bytes())
	if code != "BAD" || msg != "bad thing" {
		t.Errorf("error envelope = %q / %q", code, msg)
	}
}
