// contract_entities_test.go — Phase 1 契约全扫 · p1_entities 批次。
//
// 覆盖 COVERAGE 行：A-fn-3/8 · A-hd-3/6/7/8 · A-ag-3/6/8 · A-run-2/4/8 ·
// B-fn-3/6/8/9/10/11 · B-hd-3/6/7/11 · B-ag-4/10/14。
// 断言以 docs/references/backend/{api,error-codes,events}.md 与 domains/{function,handler,
// agent,workflow}.md 为准；行描述与契约文档不符处按文档断言并在批次报告 note 说明。
// 零 token（llmmock）；helper 一律前缀 entitiesC_，其余复用同包既有 helper
// （fnCreate/hdCreate/agCreate/agInvoke/fw/agentSetup/chatSetup/wfCreate/convCreate/...）。
package scenarios

import (
	"encoding/json"
	"fmt"
	"net/url"
	"strings"
	"sync"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// entitiesC_ws boots a bare server and binds one workspace (no LLM face needed).
//
// entitiesC_ws 拉起裸 server 并绑一个 workspace（无 LLM 面）。
func entitiesC_ws(t *testing.T, name string) *harness.Client {
	t.Helper()
	srv := harness.Start(t)
	c := srv.Client(t)
	return c.WS(c.POST("/api/v1/workspaces", map[string]any{"name": name}).Field(t, "id"))
}

// entitiesC_addUnique folds ids into seen, failing on any cross-page duplicate.
//
// entitiesC_addUnique 把 ids 并进 seen，跨页重复即失败。
func entitiesC_addUnique(t *testing.T, seen map[string]bool, ids []string, what string) {
	t.Helper()
	for _, id := range ids {
		if id == "" {
			t.Fatalf("%s: empty id in page", what)
		}
		if seen[id] {
			t.Fatalf("%s: duplicate id %s across pages (cursor page overlap)", what, id)
		}
		seen[id] = true
	}
}

// entitiesC_pagePath appends limit+cursor query params.
func entitiesC_pagePath(base string, limit int, cursor string) string {
	sep := "?"
	if strings.Contains(base, "?") {
		sep = "&"
	}
	p := fmt.Sprintf("%s%slimit=%d", base, sep, limit)
	if cursor != "" {
		p += "&cursor=" + url.QueryEscape(cursor)
	}
	return p
}

// TestContractEntities_FunctionCursorRoundTripAndUnknownFields —— A-fn-3 + A-fn-8。
// function 列表 / versions / executions 三面 cursor 往返不重不漏；limit 边界（0/负/非数
// 400、超 MaxLimit 钳制）；坏 cursor 400 MALFORMED_CURSOR；POST/PATCH 拒未知字段
// （transport 全局 DisallowUnknownFields → 400 INVALID_REQUEST）。
func TestContractEntities_FunctionCursorRoundTripAndUnknownFields(t *testing.T) {
	wc := entitiesC_ws(t, "fn-cursor")

	// 3 functions; the first accrues 5 versions + 5 executions.
	// 3 个 function；第一个攒 5 版本 + 5 执行。
	fnID := fnCreate(t, wc, "pager_fn", "def f(n: int) -> dict:\n    return {\"n\": n}\n")
	fnCreate(t, wc, "pager_fn_b", "def f() -> dict:\n    return {}\n")
	fnCreate(t, wc, "pager_fn_c", "def f() -> dict:\n    return {}\n")
	for i := 2; i <= 5; i++ {
		wc.POST("/api/v1/functions/"+fnID+":edit", map[string]any{
			"ops": []map[string]any{{"op": "set_code",
				"code": fmt.Sprintf("def f(n: int) -> dict:\n    return {\"n\": n, \"v\": %d}\n", i)}},
		}).OK(t, nil)
	}
	for i := 0; i < 5; i++ {
		wc.POST("/api/v1/functions/"+fnID+":run", map[string]any{"args": map[string]any{"n": i}}).OK(t, nil)
	}

	// —— functions list: limit=1 → 3 pages, no dup, hasMore mirrors nextCursor ——
	seenFns := map[string]bool{}
	cursor := ""
	for page := 0; ; page++ {
		if page > 6 {
			t.Fatal("functions list: cursor chain never terminates")
		}
		r := wc.GET(entitiesC_pagePath("/api/v1/functions", 1, cursor))
		var rows []struct {
			ID string `json:"id"`
		}
		r.OK(t, &rows)
		if len(rows) > 1 {
			t.Fatalf("functions list must honor limit=1, got %d rows", len(rows))
		}
		ids := make([]string, 0, len(rows))
		for _, row := range rows {
			ids = append(ids, row.ID)
		}
		entitiesC_addUnique(t, seenFns, ids, "functions list")
		if r.HasMore != (r.NextCursor != "") {
			t.Fatalf("hasMore must mirror nextCursor: hasMore=%v nextCursor=%q", r.HasMore, r.NextCursor)
		}
		if r.NextCursor == "" {
			break
		}
		cursor = r.NextCursor
	}
	if len(seenFns) != 3 {
		t.Fatalf("functions cursor round-trip lost/dup rows: got %d want 3", len(seenFns))
	}

	// —— versions: limit=2 over 5 versions → numbers exactly {1..5} ——
	seenVers := map[string]bool{}
	gotNums := map[int]bool{}
	cursor = ""
	for page := 0; ; page++ {
		if page > 6 {
			t.Fatal("versions list: cursor chain never terminates")
		}
		r := wc.GET(entitiesC_pagePath("/api/v1/functions/"+fnID+"/versions", 2, cursor))
		var rows []struct {
			ID      string `json:"id"`
			Version int    `json:"version"`
		}
		r.OK(t, &rows)
		if len(rows) > 2 {
			t.Fatalf("versions must honor limit=2, got %d", len(rows))
		}
		for _, row := range rows {
			entitiesC_addUnique(t, seenVers, []string{row.ID}, "versions")
			gotNums[row.Version] = true
		}
		if r.NextCursor == "" {
			break
		}
		cursor = r.NextCursor
	}
	if len(seenVers) != 5 {
		t.Fatalf("versions round-trip lost/dup rows: got %d want 5", len(seenVers))
	}
	for n := 1; n <= 5; n++ {
		if !gotNums[n] {
			t.Fatalf("version number %d missing from paged union: %v", n, gotNums)
		}
	}

	// —— executions: limit=2 over 5 rows; aggregates ride the data sub-object ——
	seenExecs := map[string]bool{}
	cursor = ""
	for page := 0; ; page++ {
		if page > 6 {
			t.Fatal("executions list: cursor chain never terminates")
		}
		r := wc.GET(entitiesC_pagePath("/api/v1/functions/"+fnID+"/executions", 2, cursor))
		var body struct {
			Executions []struct {
				ID string `json:"id"`
			} `json:"executions"`
			Aggregates struct {
				OKCount int `json:"okCount"`
			} `json:"aggregates"`
		}
		r.OK(t, &body)
		if len(body.Executions) > 2 {
			t.Fatalf("executions must honor limit=2, got %d", len(body.Executions))
		}
		if page == 0 && body.Aggregates.OKCount != 5 {
			t.Fatalf("aggregates must count the whole set: okCount=%d want 5", body.Aggregates.OKCount)
		}
		ids := make([]string, 0, len(body.Executions))
		for _, e := range body.Executions {
			ids = append(ids, e.ID)
		}
		entitiesC_addUnique(t, seenExecs, ids, "executions")
		if r.NextCursor == "" {
			break
		}
		cursor = r.NextCursor
	}
	if len(seenExecs) != 5 {
		t.Fatalf("executions round-trip lost/dup rows: got %d want 5", len(seenExecs))
	}

	// —— limit boundaries (N4 ParsePage): <1 / non-numeric → 400; huge → clamped 200 ——
	wc.GET("/api/v1/functions?limit=0").Fail(t, 400, "INVALID_REQUEST")
	wc.GET("/api/v1/functions?limit=-3").Fail(t, 400, "INVALID_REQUEST")
	wc.GET("/api/v1/functions?limit=abc").Fail(t, 400, "INVALID_REQUEST")
	wc.GET("/api/v1/functions?limit=5000").OK(t, nil) // clamp to MaxLimit, not an error. 钳制非报错。
	wc.GET("/api/v1/functions?cursor=not-a-cursor").Fail(t, 400, "MALFORMED_CURSOR")

	// —— A-fn-8: unknown fields reject loudly (strict decode), nothing is silently swallowed ——
	wc.POST("/api/v1/functions", map[string]any{
		"name": "stray_fn", "code": "def f() -> dict:\n    return {}\n", "wat": 1,
	}).Fail(t, 400, "INVALID_REQUEST")
	wc.PATCH("/api/v1/functions/"+fnID, map[string]any{"nombre": "x"}).Fail(t, 400, "INVALID_REQUEST")
	var f struct {
		Name string `json:"name"`
	}
	wc.GET("/api/v1/functions/"+fnID).OK(t, &f)
	if f.Name != "pager_fn" {
		t.Fatalf("rejected PATCH must not mutate the row, name=%q", f.Name)
	}
}

// TestContractEntities_HandlerCursorSoftDeleteUnknownFields —— A-hd-3 + A-hd-6 + A-hd-8。
// handler calls/versions cursor 往返；软删涟漪（列表过滤 / 404 读 / 同名复用 partial-UNIQUE /
// 调用台账 D1 保留 / env 销毁）；POST 拒未知字段。
func TestContractEntities_HandlerCursorSoftDeleteUnknownFields(t *testing.T) {
	wc := entitiesC_ws(t, "hd-cursor")

	hdID := hdCreate(t, wc, "pager_hd", map[string]any{
		"initBody": "self.n = 0",
		"methods": []map[string]any{
			{"name": "ping", "inputs": []any{}, "body": "self.n += 1\nreturn {\"pong\": self.n}"},
		},
	})
	for i := 0; i < 5; i++ {
		wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{"method": "ping", "args": map[string]any{}}).OK(t, nil)
	}
	// two code edits → 3 versions. 两次代码编辑 → 3 版本。
	wc.POST("/api/v1/handlers/"+hdID+":edit", map[string]any{
		"ops": []map[string]any{{"op": "set_imports", "imports": "import json"}},
	}).OK(t, nil)
	wc.POST("/api/v1/handlers/"+hdID+":edit", map[string]any{
		"ops": []map[string]any{{"op": "set_imports", "imports": "import json, os"}},
	}).OK(t, nil)

	// —— calls: limit=2 over 5 rows, no dup/miss ——
	seenCalls := map[string]bool{}
	firstCallID := ""
	cursor := ""
	for page := 0; ; page++ {
		if page > 6 {
			t.Fatal("calls list: cursor chain never terminates")
		}
		r := wc.GET(entitiesC_pagePath("/api/v1/handlers/"+hdID+"/calls", 2, cursor))
		var body struct {
			Calls []struct {
				ID string `json:"id"`
			} `json:"calls"`
			Aggregates struct {
				OKCount int `json:"okCount"`
			} `json:"aggregates"`
		}
		r.OK(t, &body)
		if len(body.Calls) > 2 {
			t.Fatalf("calls must honor limit=2, got %d", len(body.Calls))
		}
		if page == 0 && body.Aggregates.OKCount != 5 {
			t.Fatalf("call aggregates wrong: okCount=%d want 5", body.Aggregates.OKCount)
		}
		for _, cRow := range body.Calls {
			if firstCallID == "" {
				firstCallID = cRow.ID
			}
			entitiesC_addUnique(t, seenCalls, []string{cRow.ID}, "handler calls")
		}
		if r.NextCursor == "" {
			break
		}
		cursor = r.NextCursor
	}
	if len(seenCalls) != 5 {
		t.Fatalf("calls round-trip lost/dup rows: got %d want 5", len(seenCalls))
	}

	// —— versions: limit=2 over 3 rows → numbers {1,2,3} ——
	gotNums := map[int]bool{}
	total := 0
	cursor = ""
	for page := 0; ; page++ {
		if page > 6 {
			t.Fatal("handler versions: cursor chain never terminates")
		}
		r := wc.GET(entitiesC_pagePath("/api/v1/handlers/"+hdID+"/versions", 2, cursor))
		var rows []struct {
			Version int `json:"version"`
		}
		r.OK(t, &rows)
		total += len(rows)
		for _, row := range rows {
			if gotNums[row.Version] {
				t.Fatalf("handler versions: duplicate version %d across pages", row.Version)
			}
			gotNums[row.Version] = true
		}
		if r.NextCursor == "" {
			break
		}
		cursor = r.NextCursor
	}
	if total != 3 || !gotNums[1] || !gotNums[2] || !gotNums[3] {
		t.Fatalf("handler versions round-trip wrong: total=%d nums=%v", total, gotNums)
	}

	// —— A-hd-6: soft delete ripples ——
	var hd struct {
		ActiveVersion struct {
			EnvID string `json:"envId"`
		} `json:"activeVersion"`
	}
	wc.GET("/api/v1/handlers/"+hdID).OK(t, &hd)
	if r := wc.DELETE("/api/v1/handlers/" + hdID); r.Status != 204 {
		t.Fatalf("handler delete must 204, got %d %s", r.Status, r.Raw)
	}
	wc.GET("/api/v1/handlers/"+hdID).Fail(t, 404, "HANDLER_NOT_FOUND")
	var live []struct {
		ID string `json:"id"`
	}
	wc.GET("/api/v1/handlers").OK(t, &live)
	for _, row := range live {
		if row.ID == hdID {
			t.Fatal("soft-deleted handler must vanish from the list")
		}
	}
	// same-name recreate is legal right away (partial-UNIQUE WHERE deleted_at IS NULL).
	// 同名立即可复用（partial-UNIQUE）。
	hdCreate(t, wc, "pager_hd", map[string]any{
		"methods": []map[string]any{{"name": "ping", "inputs": []any{}, "body": "return {\"pong\": 0}"}},
	})
	// D1: the old call ledger row survives the entity's soft delete.
	// D1：旧调用台账行在实体软删后存活。
	wc.GET("/api/v1/handler-calls/"+firstCallID).OK(t, nil)
	// env destroyed (owner key functionID_envID-style: hdID_ prefix rows all gone).
	// env 已销毁（owner 前缀 hdID_ 的行全部消失）。
	harness.Eventually(t, 15000, "deleted handler's envs reclaimed", func() bool {
		r := wc.GET("/api/v1/sandbox/envs?ownerKind=handler")
		if r.Status != 200 {
			return false
		}
		var envs []struct {
			OwnerID string `json:"ownerId"`
		}
		if err := json.Unmarshal(r.Data, &envs); err != nil {
			return false
		}
		for _, e := range envs {
			if strings.HasPrefix(e.OwnerID, hdID+"_") {
				return false
			}
		}
		return true
	})

	// —— A-hd-8: unknown field rejects ——
	wc.POST("/api/v1/handlers", map[string]any{
		"name": "stray_hd", "wat": 1,
		"methods": []map[string]any{{"name": "m", "inputs": []any{}, "body": "return {}"}},
	}).Fail(t, 400, "INVALID_REQUEST")
}

// TestContractEntities_HandlerRevertConfigMergePatchIterate —— A-hd-7 的未打面：
// config PUT 是 JSON Merge Patch（null 删 key、部分更新保留其余）；:revert 纯指针 + 重启
// 生效于下一次调用且不动行 meta；:iterate 202 返 conversation id。
// （:call/:restart/:edit/config 三端其余面已由 TestHandler_* 既有场景锁定。）
func TestContractEntities_HandlerRevertConfigMergePatchIterate(t *testing.T) {
	wc, _ := chatSetup(t, false) // :iterate spawns a dialogue turn → needs the mock dialogue model. :iterate 起对话回合。

	hdID := hdCreate(t, wc, "verhd", map[string]any{
		"description": "契约探针",
		"initArgsSchema": []map[string]any{
			{"name": "a", "type": "string", "required": true},
			{"name": "b", "type": "string", "required": true},
		},
		"initBody": "self.a = a\nself.b = b",
		"methods": []map[string]any{
			{"name": "reply", "inputs": []any{}, "body": "return {\"v\": 1, \"a\": self.a, \"b\": self.b}"},
		},
	})

	call := func() map[string]any {
		t.Helper()
		var out map[string]any
		wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{"method": "reply", "args": map[string]any{}}).OK(t, &out)
		return out
	}

	wc.PUT("/api/v1/handlers/"+hdID+"/config", map[string]any{"a": "1", "b": "22"}).OK(t, nil)
	out := call()
	if out["v"] != float64(1) || out["a"] != "1" || out["b"] != "22" {
		t.Fatalf("configured v1 call wrong: %+v", out)
	}

	// Merge Patch: null deletes the key → required missing → spawn rejects again.
	// Merge Patch：null 删 key → 必填缺失 → spawn 再拒。
	wc.PUT("/api/v1/handlers/"+hdID+"/config", map[string]any{"b": nil}).OK(t, nil)
	wc.POST("/api/v1/handlers/"+hdID+":call", map[string]any{"method": "reply", "args": map[string]any{}}).
		Fail(t, 422, "HANDLER_CONFIG_INCOMPLETE")
	var cfg struct {
		ConfigState   string   `json:"configState"`
		MissingConfig []string `json:"missingConfig"`
	}
	wc.GET("/api/v1/handlers/"+hdID+"/config").OK(t, &cfg)
	if len(cfg.MissingConfig) != 1 || cfg.MissingConfig[0] != "b" {
		t.Fatalf("null-deleted key must show missing: %+v", cfg)
	}

	// Partial update: only b travels; a survives the merge.
	// 部分更新：只传 b；a 在合并后幸存。
	wc.PUT("/api/v1/handlers/"+hdID+"/config", map[string]any{"b": "3"}).OK(t, nil)
	out = call()
	if out["a"] != "1" || out["b"] != "3" {
		t.Fatalf("merge patch must keep untouched keys: %+v", out)
	}

	// edit → v2 behavior; revert → v1 behavior on the NEXT call; row meta untouched.
	// 编辑 → v2 行为；revert → 下一次调用回 v1 行为；行 meta 不动。
	wc.POST("/api/v1/handlers/"+hdID+":edit", map[string]any{
		"ops": []map[string]any{{"op": "update_method", "name": "reply",
			"patch": map[string]any{"body": "return {\"v\": 2, \"a\": self.a, \"b\": self.b}"}}},
	}).OK(t, nil)
	if out = call(); out["v"] != float64(2) {
		t.Fatalf("edit must take effect on next call: %+v", out)
	}
	var ver struct {
		Version int `json:"version"`
	}
	// NOTE: api.md 状态变更动作铁律说 :revert 返「实体完整快照」，但全实体实现一致返 Version
	// 快照——按当前实现断言、mismatch 已计入批次缺陷报告（LOW，疑文档面）。
	wc.POST("/api/v1/handlers/"+hdID+":revert", map[string]any{"version": 1}).OK(t, &ver)
	if ver.Version != 1 {
		t.Fatalf(":revert must return the target version snapshot, got %+v", ver)
	}
	if out = call(); out["v"] != float64(1) {
		t.Fatalf("revert must restore v1 behavior: %+v", out)
	}
	var hd struct {
		Name          string `json:"name"`
		Description   string `json:"description"`
		ActiveVersion struct {
			Version int `json:"version"`
		} `json:"activeVersion"`
	}
	wc.GET("/api/v1/handlers/"+hdID).OK(t, &hd)
	if hd.Name != "verhd" || hd.Description != "契约探针" || hd.ActiveVersion.Version != 1 {
		t.Fatalf("revert must move only the pointer, meta intact: %+v", hd)
	}

	// :iterate → 202 {data:{id:<conversationId>}} and the conversation exists.
	// :iterate → 202 返对话 id，且对话可读。
	r := wc.Do("POST", "/api/v1/handlers/"+hdID+":iterate", map[string]any{"request": "add logging"})
	if r.Status != 202 {
		t.Fatalf(":iterate must 202, got %d %s", r.Status, r.Raw)
	}
	convID := r.Field(t, "id")
	wc.GET("/api/v1/conversations/"+convID).OK(t, nil)
}

// TestContractEntities_AgentCursorSoftDeleteUnknownFields —— A-ag-3 + A-ag-6 + A-ag-8。
// agent executions/versions cursor 往返；软删（列表过滤 / 404 / 名字复用 / 活体重名 409 /
// 执行台账 D1）；创建与 :edit 拒未知字段。
func TestContractEntities_AgentCursorSoftDeleteUnknownFields(t *testing.T) {
	wc, _ := agentSetup(t)

	agID := agCreate(t, wc, map[string]any{"name": "Pager", "description": "契约探针", "prompt": "reply ok"})
	execID := ""
	for i := 0; i < 5; i++ {
		res := agInvoke(t, wc, agID, nil) // default "ok." mock turn per invoke. 默认 mock turn。
		if !res.OK {
			t.Fatalf("invoke %d failed: %+v", i, res)
		}
		if execID == "" {
			execID = res.ExecutionID
		}
	}
	wc.POST("/api/v1/agents/"+agID+":edit", map[string]any{"prompt": "v2 persona"}).OK(t, nil)
	wc.POST("/api/v1/agents/"+agID+":edit", map[string]any{"prompt": "v3 persona"}).OK(t, nil)

	// —— executions: limit=2 over 5 rows ——
	seen := map[string]bool{}
	cursor := ""
	for page := 0; ; page++ {
		if page > 6 {
			t.Fatal("agent executions: cursor chain never terminates")
		}
		r := wc.GET(entitiesC_pagePath("/api/v1/agents/"+agID+"/executions", 2, cursor))
		var body struct {
			Executions []struct {
				ID string `json:"id"`
			} `json:"executions"`
			Aggregates struct {
				OKCount int `json:"okCount"`
			} `json:"aggregates"`
		}
		r.OK(t, &body)
		if len(body.Executions) > 2 {
			t.Fatalf("executions must honor limit=2, got %d", len(body.Executions))
		}
		if page == 0 && body.Aggregates.OKCount != 5 {
			t.Fatalf("agent aggregates wrong: %+v", body.Aggregates)
		}
		for _, e := range body.Executions {
			entitiesC_addUnique(t, seen, []string{e.ID}, "agent executions")
		}
		if r.NextCursor == "" {
			break
		}
		cursor = r.NextCursor
	}
	if len(seen) != 5 {
		t.Fatalf("agent executions round-trip lost/dup: got %d want 5", len(seen))
	}

	// —— versions: limit=2 over 3 rows → {1,2,3} ——
	nums := map[int]bool{}
	total := 0
	cursor = ""
	for page := 0; ; page++ {
		if page > 6 {
			t.Fatal("agent versions: cursor chain never terminates")
		}
		r := wc.GET(entitiesC_pagePath("/api/v1/agents/"+agID+"/versions", 2, cursor))
		var rows []struct {
			Version int `json:"version"`
		}
		r.OK(t, &rows)
		total += len(rows)
		for _, row := range rows {
			if nums[row.Version] {
				t.Fatalf("agent versions duplicate %d", row.Version)
			}
			nums[row.Version] = true
		}
		if r.NextCursor == "" {
			break
		}
		cursor = r.NextCursor
	}
	if total != 3 || !nums[1] || !nums[2] || !nums[3] {
		t.Fatalf("agent versions round-trip wrong: total=%d nums=%v", total, nums)
	}

	// —— A-ag-6: live duplicate 409 → delete → list filter / 404 / name reuse / D1 ledger ——
	wc.Do("POST", "/api/v1/agents", map[string]any{"name": "Pager", "description": "x", "prompt": "x"}).
		Fail(t, 409, "AGENT_NAME_CONFLICT")
	if r := wc.DELETE("/api/v1/agents/" + agID); r.Status != 204 {
		t.Fatalf("agent delete must 204, got %d %s", r.Status, r.Raw)
	}
	wc.GET("/api/v1/agents/"+agID).Fail(t, 404, "AGENT_NOT_FOUND")
	var live []struct {
		ID string `json:"id"`
	}
	wc.GET("/api/v1/agents").OK(t, &live)
	for _, row := range live {
		if row.ID == agID {
			t.Fatal("soft-deleted agent must vanish from the list")
		}
	}
	agCreate(t, wc, map[string]any{"name": "Pager", "description": "reborn", "prompt": "x"}) // 同名复用
	// D1: execution log row survives the soft delete. D1：执行台账行存活。
	wc.GET("/api/v1/agent-executions/"+execID).OK(t, nil)

	// —— A-ag-8: unknown fields reject on create + :edit ——
	wc.Do("POST", "/api/v1/agents", map[string]any{"name": "Stray", "prompt": "x", "wat": 1}).
		Fail(t, 400, "INVALID_REQUEST")
	newID := nestedID(t, wc.POST("/api/v1/agents", map[string]any{"name": "EditProbe", "description": "x", "prompt": "x"}), "agent")
	wc.Do("POST", "/api/v1/agents/"+newID+":edit", map[string]any{"prompt": "x", "wat": 1}).
		Fail(t, 400, "INVALID_REQUEST")
}

// TestContractEntities_FlowrunEntryDecideAndErrorFaces —— A-run-2 + A-run-4 + A-run-8。
// POST /flowruns 直入口（201 + {flowrun,nodes} 复合形）与 entryNode 消歧（歧义/坏选择器/
// 非 trigger 节点 422 FLOWRUN_INVALID_ENTRY）；decide first-wins（并发恰一胜、输家 422
// FLOWRUN_APPROVAL_NOT_PARKED）；decision 枚举外 422 / body 未知字段 400；坏 status 过滤
// 422 FLOWRUN_INVALID_STATUS（error-codes.md；批次行写 400 与文档不符,以文档为准）；未知
// run 404 FLOWRUN_NOT_FOUND。
func TestContractEntities_FlowrunEntryDecideAndErrorFaces(t *testing.T) {
	wc := entitiesC_ws(t, "run-contract")

	// —— A-run-4: two-trigger graph + direct POST /flowruns ——
	fnA := fnCreate(t, wc, "door_a", "def f(x: str) -> dict:\n    return {\"door\": \"A\", \"x\": x}\n")
	fnB := fnCreate(t, wc, "door_b", "def f(x: str) -> dict:\n    return {\"door\": \"B\", \"x\": x}\n")
	wfID := wfCreate(t, wc, "two_doors", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "t1", "kind": "trigger", "ref": "trg_manual_a"}},
		{"op": "add_node", "node": map[string]any{"id": "t2", "kind": "trigger", "ref": "trg_manual_b"}},
		{"op": "add_node", "node": map[string]any{"id": "a", "kind": "action", "ref": fnA, "input": map[string]any{"x": "t1.v"}}},
		{"op": "add_node", "node": map[string]any{"id": "b", "kind": "action", "ref": fnB, "input": map[string]any{"x": "t2.v"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "t1", "to": "a"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e2", "from": "t2", "to": "b"}},
	})

	// ambiguity / bad selector / non-trigger selector → 422 FLOWRUN_INVALID_ENTRY.
	wc.Do("POST", "/api/v1/flowruns", map[string]any{"workflowId": wfID, "payload": map[string]any{}}).
		Fail(t, 422, "FLOWRUN_INVALID_ENTRY")
	wc.Do("POST", "/api/v1/flowruns", map[string]any{"workflowId": wfID, "entryNode": "ghost", "payload": map[string]any{}}).
		Fail(t, 422, "FLOWRUN_INVALID_ENTRY")
	wc.Do("POST", "/api/v1/flowruns", map[string]any{"workflowId": wfID, "entryNode": "a", "payload": map[string]any{}}).
		Fail(t, 422, "FLOWRUN_INVALID_ENTRY")

	// valid entryNode=t2: 201 + composite {flowrun, nodes} (响应形状铁律的复合读形；
	// 批次行写 202——api.md 的 202 铁律只列 :trigger 等返单 id 的动作,POST /flowruns 返复合形
	// 走 Created,以文档+实现为准记 note).
	r := wc.Do("POST", "/api/v1/flowruns", map[string]any{
		"workflowId": wfID, "entryNode": "t2", "payload": map[string]any{"v": "pong"},
	})
	if r.Status != 201 {
		t.Fatalf("POST /flowruns must 201 Created, got %d %s", r.Status, r.Raw)
	}
	var started struct {
		Flowrun struct {
			ID     string `json:"id"`
			Status string `json:"status"`
		} `json:"flowrun"`
		Nodes json.RawMessage `json:"nodes"`
	}
	if err := json.Unmarshal(r.Data, &started); err != nil || started.Flowrun.ID == "" {
		t.Fatalf("POST /flowruns must return the {flowrun,nodes} composite: %s", r.Data)
	}
	runID := started.Flowrun.ID
	harness.Eventually(t, 30000, "entry t2 runs door B only", func() bool {
		var got struct {
			Flowrun struct {
				Status string `json:"status"`
			} `json:"flowrun"`
			Nodes json.RawMessage `json:"nodes"`
		}
		rr := wc.GET("/api/v1/flowruns/" + runID)
		if rr.Status != 200 {
			return false
		}
		_ = json.Unmarshal(rr.Data, &got)
		s := string(got.Nodes)
		return got.Flowrun.Status == "completed" && strings.Contains(s, `"door":"B"`) && !strings.Contains(s, `"door":"A"`)
	})

	// —— error faces: unknown run / bad status enum / unknown body field ——
	wc.GET("/api/v1/flowruns/frn_00000000deadbeef").Fail(t, 404, "FLOWRUN_NOT_FOUND")
	wc.GET("/api/v1/flowruns?status=bogus").Fail(t, 422, "FLOWRUN_INVALID_STATUS")
	var page []struct {
		ID string `json:"id"`
	}
	wc.GET("/api/v1/flowruns?status=completed&workflowId="+wfID).OK(t, &page)
	if len(page) != 1 || page[0].ID != runID {
		t.Fatalf("valid status filter must list the run: %+v", page)
	}
	wc.Do("POST", "/api/v1/flowruns", map[string]any{"workflowId": wfID, "payloadd": map[string]any{}}).
		Fail(t, 400, "INVALID_REQUEST")

	// —— A-run-2 + A-run-8: approval decide faces ——
	pubFn := fnCreate(t, wc, "pub_step", "def f(d: str) -> dict:\n    return {\"published\": d}\n")
	apfID := wc.POST("/api/v1/approvals", map[string]any{
		"name": "contract_gate", "template": "approve {{ input.amt }}?", "allowReason": true,
	}).Field(t, "id")
	wfAp := wfCreate(t, wc, "gated_pipe", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}},
		{"op": "add_node", "node": map[string]any{"id": "human", "kind": "approval", "ref": apfID, "input": map[string]any{"amt": "start.amt"}}},
		{"op": "add_node", "node": map[string]any{"id": "pub", "kind": "action", "ref": pubFn, "input": map[string]any{"d": "human.decision"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "human"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e2", "from": "human", "to": "pub", "fromPort": "yes"}},
	})
	startParked := func() string {
		t.Helper()
		var st struct {
			Flowrun struct {
				ID string `json:"id"`
			} `json:"flowrun"`
			Nodes json.RawMessage `json:"nodes"`
		}
		wc.POST("/api/v1/flowruns", map[string]any{"workflowId": wfAp, "payload": map[string]any{"amt": "9"}}).OK(t, &st)
		if !strings.Contains(string(st.Nodes), `"parked"`) {
			t.Fatalf("approval run must park: %s", st.Nodes)
		}
		return st.Flowrun.ID
	}

	// concurrent yes/no race: first-wins — exactly one 2xx winner, the loser 422
	// FLOWRUN_APPROVAL_NOT_PARKED. 并发批/拒竞速：首决胜——恰一个 2xx，输家 422。
	run1 := startParked()
	type decideOut struct {
		status int
		code   string
	}
	results := make(chan decideOut, 2)
	var wg sync.WaitGroup
	for _, d := range []string{"yes", "no"} {
		d := d
		wg.Add(1)
		go func() {
			defer wg.Done()
			resp, err := wc.Try("POST", "/api/v1/flowruns/"+run1+"/approvals/human:decide",
				map[string]any{"decision": d, "reason": "race"})
			if err != nil {
				results <- decideOut{status: -1}
				return
			}
			results <- decideOut{status: resp.Status, code: resp.Code}
		}()
	}
	wg.Wait()
	close(results)
	wins, losses := 0, 0
	for out := range results {
		switch {
		case out.status >= 200 && out.status <= 299:
			wins++
		case out.status == 422 && out.code == "FLOWRUN_APPROVAL_NOT_PARKED":
			losses++
		default:
			t.Fatalf("decide race unexpected outcome: %+v", out)
		}
	}
	if wins != 1 || losses != 1 {
		t.Fatalf("first-wins violated: wins=%d losses=%d", wins, losses)
	}

	// enum-out decision → 422; unknown body field → 400; both leave the node parked.
	// 枚举外 decision → 422；body 未知字段 → 400；两者都不消耗 park。
	run2 := startParked()
	wc.Do("POST", "/api/v1/flowruns/"+run2+"/approvals/human:decide", map[string]any{"decision": "maybe"}).
		Fail(t, 422, "FLOWRUN_INVALID_DECISION")
	wc.Do("POST", "/api/v1/flowruns/"+run2+"/approvals/human:decide", map[string]any{"decision": "yes", "wat": 1}).
		Fail(t, 400, "INVALID_REQUEST")
	var inbox struct {
		Parked []struct {
			FlowRunID string `json:"flowrunId"`
		} `json:"parked"`
	}
	wc.GET("/api/v1/flowrun-inbox").OK(t, &inbox)
	stillParked := false
	for _, p := range inbox.Parked {
		if p.FlowRunID == run2 {
			stillParked = true
		}
	}
	if !stillParked {
		t.Fatal("rejected decide bodies must not consume the parked node")
	}
	// clean settle: 202 + composite confirmation. 收尾决策：202 + 复合确认形。
	rd := wc.Do("POST", "/api/v1/flowruns/"+run2+"/approvals/human:decide", map[string]any{"decision": "no"})
	if rd.Status != 202 || !strings.Contains(string(rd.Data), `"flowrun"`) {
		t.Fatalf("decide must 202 with the run composite, got %d %s", rd.Status, rd.Raw)
	}
}

// TestContractEntities_FunctionEnvLifecycle —— B-fn-6 + B-fn-8 + B-fn-9 + B-fn-10 + B-fn-11。
// 词法黑名单 import anselm_handler 创建即拒；坏依赖 env failed 不阻塞创建、:run 报
// FUNCTION_ENV_NOT_READY；空 ops edit = 重建 env（版本不变 + function.env_rebuilt 通知）；
// 无参函数无 args 调用 ok（nil input 归一 {}）；sandbox:gc 回收后 :run 自动重建 env 重试成功。
func TestContractEntities_FunctionEnvLifecycle(t *testing.T) {
	wc := entitiesC_ws(t, "fn-env")
	ns := wc.Subscribe(t, "notifications")

	// —— B-fn-10: zero-arg function runs with an empty body (input normalized to {}) ——
	fnID := fnCreate(t, wc, "noargs_fn", "def f() -> dict:\n    return {\"ok\": True}\n")
	var run struct {
		OK     bool           `json:"ok"`
		Output map[string]any `json:"output"`
	}
	wc.POST("/api/v1/functions/"+fnID+":run", map[string]any{}).OK(t, &run)
	if !run.OK || run.Output["ok"] != true {
		t.Fatalf("no-arg run with empty body must succeed: %+v", run)
	}

	// —— B-fn-9: empty-ops edit = rebuild active env; no version mint; env_rebuilt event ——
	var ver struct {
		Version int `json:"version"`
	}
	wc.POST("/api/v1/functions/"+fnID+":edit", map[string]any{"ops": []any{}}).OK(t, &ver)
	if ver.Version != 1 {
		t.Fatalf("empty-ops edit must return the untouched active version, got v%d", ver.Version)
	}
	ns.WaitFor(t, 10000, "env rebuild notification", "function.env_rebuilt")
	var vers []struct {
		Version int `json:"version"`
	}
	wc.GET("/api/v1/functions/"+fnID+"/versions").OK(t, &vers)
	if len(vers) != 1 {
		t.Fatalf("empty-ops edit must not mint a version, got %d rows", len(vers))
	}

	// —— B-fn-11: GC reclaims the ready env → :run rebuilds + retries once, succeeds ——
	var gc struct {
		Removed int `json:"removed"`
	}
	wc.POST("/api/v1/sandbox:gc?olderThanDays=0", nil).OK(t, &gc)
	if gc.Removed < 1 {
		t.Fatalf("gc olderThanDays=0 must reclaim the idle env, removed=%d", gc.Removed)
	}
	wc.POST("/api/v1/functions/"+fnID+":run", map[string]any{"args": map[string]any{}}).OK(t, &run)
	if !run.OK {
		t.Fatalf("run after env GC must auto-rebuild and succeed: %+v", run)
	}

	// —— B-fn-6: stateless/stateful boundary — anselm_handler import rejects at create ——
	wc.Do("POST", "/api/v1/functions", map[string]any{
		"name": "smuggler_a", "code": "import anselm_handler\n\ndef f() -> dict:\n    return {}\n",
	}).Fail(t, 422, "FUNCTION_INVALID_CODE")
	wc.Do("POST", "/api/v1/functions", map[string]any{
		"name": "smuggler_b", "code": "from anselm_handler import state\n\ndef f() -> dict:\n    return {}\n",
	}).Fail(t, 422, "FUNCTION_INVALID_CODE")

	// —— B-fn-8: env failure must NOT block create; run reports FUNCTION_ENV_NOT_READY ——
	r := wc.Do("POST", "/api/v1/functions", map[string]any{
		"name": "bad_dep_fn", "code": "def f() -> dict:\n    return {}\n",
		"dependencies": []string{"anselm-no-such-package-zz9"},
	})
	if r.Status != 201 {
		t.Fatalf("env failure must not block create (entity + visible status), got %d %s", r.Status, r.Raw)
	}
	badID := r.Field(t, "id")
	var got struct {
		ActiveVersion struct {
			EnvStatus string `json:"envStatus"`
			EnvError  string `json:"envError"`
		} `json:"activeVersion"`
	}
	wc.GET("/api/v1/functions/"+badID).OK(t, &got)
	if got.ActiveVersion.EnvStatus != "failed" || got.ActiveVersion.EnvError == "" {
		t.Fatalf("bad-dep version must read env failed + error visible: %+v", got.ActiveVersion)
	}
	wc.Do("POST", "/api/v1/functions/"+badID+":run", map[string]any{"args": map[string]any{}}).
		Fail(t, 422, "FUNCTION_ENV_NOT_READY")
}

// TestContractEntities_FunctionVersionCapTrimReclaimsEnvs —— B-fn-3。
// 越 cap（50）的 edit 硬删最老版本（绝不删 active）且回收被删版本的 per-version venv
// （reclaimTrimmedEnvs 经 DestroyEnv）——不留孤儿 venv 等手动 gc。
func TestContractEntities_FunctionVersionCapTrimReclaimsEnvs(t *testing.T) {
	wc := entitiesC_ws(t, "fn-trim")

	fnID := fnCreate(t, wc, "trim_fn", "def f() -> dict:\n    return {\"v\": 1}\n")
	var v1 struct {
		ActiveVersion struct {
			EnvID string `json:"envId"`
		} `json:"activeVersion"`
	}
	wc.GET("/api/v1/functions/"+fnID).OK(t, &v1)
	if v1.ActiveVersion.EnvID == "" {
		t.Fatal("v1 must carry a per-version envId")
	}
	v1Owner := fnID + "_" + v1.ActiveVersion.EnvID

	// 50 edits → 51 versions total → v1 trimmed (cap 50). 50 次编辑 → 51 版 → v1 被裁。
	for i := 2; i <= 51; i++ {
		wc.POST("/api/v1/functions/"+fnID+":edit", map[string]any{
			"ops": []map[string]any{{"op": "set_code",
				"code": fmt.Sprintf("def f() -> dict:\n    return {\"v\": %d}\n", i)}},
		}).OK(t, nil)
	}

	// versions: exactly 50 rows, numbering 2..51 (v1 gone, numbers never reshuffled).
	// 版本恰 50 行、号 2..51（v1 没了、号永不重排）。
	var rows []struct {
		Version int `json:"version"`
	}
	r := wc.GET("/api/v1/functions/" + fnID + "/versions?limit=200")
	r.OK(t, &rows)
	if len(rows) != 50 {
		t.Fatalf("cap must retain exactly 50 versions, got %d", len(rows))
	}
	minV, maxV := rows[0].Version, rows[0].Version
	for _, row := range rows {
		if row.Version < minV {
			minV = row.Version
		}
		if row.Version > maxV {
			maxV = row.Version
		}
	}
	if minV != 2 || maxV != 51 {
		t.Fatalf("trim must drop the oldest only: min=%d max=%d (want 2..51)", minV, maxV)
	}

	// the trimmed v1 venv is reclaimed; the surviving 50 remain addressable.
	// 被裁 v1 的 venv 已回收；幸存 50 个仍在。
	harness.Eventually(t, 20000, "trimmed v1 venv reclaimed, 50 survivors", func() bool {
		rr := wc.GET("/api/v1/sandbox/envs?ownerKind=function")
		if rr.Status != 200 {
			return false
		}
		var envs []struct {
			OwnerID string `json:"ownerId"`
		}
		if err := json.Unmarshal(rr.Data, &envs); err != nil {
			return false
		}
		mine := 0
		for _, e := range envs {
			if e.OwnerID == v1Owner {
				return false // orphan venv leak. 孤儿 venv 泄漏。
			}
			if strings.HasPrefix(e.OwnerID, fnID+"_") {
				mine++
			}
		}
		return mine == 50
	})
}

// TestContractEntities_HandlerResidentSemantics —— B-hd-3 + B-hd-6 + B-hd-7 + B-hd-11。
// 纯 meta 变更（PATCH / 全 set_meta edit）不铸版本不重启（内存态存活）；spawn 咽喉按 active
// schema 过滤孤儿 config key（edit 删 arg / revert 回来都不炸 __init__）；冷启并发调用共享
// 一次 in-flight spawn（同一 instanceId）；generator 终值 yield/return 两式均生效。
func TestContractEntities_HandlerResidentSemantics(t *testing.T) {
	wc := entitiesC_ws(t, "hd-resident")

	// —— B-hd-3: memory survives pure-meta changes ——
	counter := hdCreate(t, wc, "memory_keeper", map[string]any{
		"initBody": "self.count = 0",
		"methods": []map[string]any{
			{"name": "bump", "inputs": []any{}, "body": "self.count += 1\nreturn {\"count\": self.count}"},
		},
	})
	bump := func() float64 {
		t.Helper()
		var out map[string]any
		wc.POST("/api/v1/handlers/"+counter+":call", map[string]any{"method": "bump", "args": map[string]any{}}).OK(t, &out)
		n, _ := out["count"].(float64)
		return n
	}
	bump()
	if got := bump(); got != 2 {
		t.Fatalf("resident state must persist: %v", got)
	}
	wc.PATCH("/api/v1/handlers/"+counter, map[string]any{"name": "memory_keeper_2"}).OK(t, nil)
	if got := bump(); got != 3 {
		t.Fatalf("PATCH meta must NOT restart the instance (count reset): %v", got)
	}
	wc.POST("/api/v1/handlers/"+counter+":edit", map[string]any{
		"ops": []map[string]any{{"op": "set_meta", "description": "renamed but alive"}},
	}).OK(t, nil)
	if got := bump(); got != 4 {
		t.Fatalf("all-set_meta edit must NOT restart the instance: %v", got)
	}
	var hd struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	wc.GET("/api/v1/handlers/"+counter).OK(t, &hd)
	if hd.Name != "memory_keeper_2" || hd.Description != "renamed but alive" {
		t.Fatalf("meta edits must land on the row: %+v", hd)
	}
	var vers []struct {
		Version int `json:"version"`
	}
	wc.GET("/api/v1/handlers/"+counter+"/versions").OK(t, &vers)
	if len(vers) != 1 {
		t.Fatalf("pure meta edits must not mint versions, got %d", len(vers))
	}

	// —— B-hd-7: cold-start concurrency shares ONE in-flight spawn ——
	slow := hdCreate(t, wc, "slow_spawner", map[string]any{
		"imports":  "import time",
		"initBody": "time.sleep(1)\nself.ready = True",
		"methods": []map[string]any{
			{"name": "poke", "inputs": []any{}, "body": "return {\"ok\": True}"},
		},
	})
	const N = 5
	var wg sync.WaitGroup
	errs := make(chan string, N)
	for i := 0; i < N; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			resp, err := wc.Try("POST", "/api/v1/handlers/"+slow+":call",
				map[string]any{"method": "poke", "args": map[string]any{}})
			if err != nil {
				errs <- err.Error()
				return
			}
			if resp.Status != 200 {
				errs <- string(resp.Raw)
			}
		}()
	}
	wg.Wait()
	close(errs)
	for e := range errs {
		t.Fatalf("cold concurrent call failed: %s", e)
	}
	var callsPage struct {
		Calls []struct {
			InstanceID string `json:"instanceId"`
		} `json:"calls"`
	}
	wc.GET("/api/v1/handlers/"+slow+"/calls?limit=50").OK(t, &callsPage)
	if len(callsPage.Calls) != N {
		t.Fatalf("want %d call rows, got %d", N, len(callsPage.Calls))
	}
	instances := map[string]bool{}
	for _, cRow := range callsPage.Calls {
		if cRow.InstanceID == "" {
			t.Fatal("call row missing instanceId")
		}
		instances[cRow.InstanceID] = true
	}
	if len(instances) != 1 {
		t.Fatalf("cold-start batch must share ONE spawned instance, got %d distinct: %v", len(instances), instances)
	}

	// —— B-hd-6: spawn filters orphan config keys by the ACTIVE schema ——
	cfgHd := hdCreate(t, wc, "cfg_orphan", map[string]any{
		"initArgsSchema": []map[string]any{{"name": "token", "type": "string", "required": true}},
		"initBody":       "self.token = token",
		"methods": []map[string]any{
			{"name": "peek", "inputs": []any{}, "body": "return {\"who\": \"v1\"}"},
		},
	})
	wc.PUT("/api/v1/handlers/"+cfgHd+"/config", map[string]any{"token": "tok-123"}).OK(t, nil)
	var peek map[string]any
	wc.POST("/api/v1/handlers/"+cfgHd+":call", map[string]any{"method": "peek", "args": map[string]any{}}).OK(t, &peek)
	if peek["who"] != "v1" {
		t.Fatalf("configured v1 call wrong: %+v", peek)
	}
	// v2 removes the token init-arg; the stored config keeps the now-orphan key.
	// v2 删掉 token init-arg；存量 config 留着孤儿 key。
	wc.POST("/api/v1/handlers/"+cfgHd+":edit", map[string]any{
		"ops": []map[string]any{
			{"op": "set_init_args_schema", "args": []any{}},
			{"op": "set_init", "initBody": "self.token = \"builtin\""},
			{"op": "update_method", "name": "peek", "patch": map[string]any{"body": "return {\"who\": \"v2\"}"}},
		},
	}).OK(t, nil)
	wc.POST("/api/v1/handlers/"+cfgHd+":call", map[string]any{"method": "peek", "args": map[string]any{}}).OK(t, &peek)
	if peek["who"] != "v2" {
		t.Fatalf("orphan config key must be filtered at spawn (no __init__ TypeError): %+v", peek)
	}
	// revert to v1: the arg is back in schema, the kept config value serves it again.
	// revert 回 v1：arg 回到 schema，留存的 config 值重新生效。
	wc.POST("/api/v1/handlers/"+cfgHd+":revert", map[string]any{"version": 1}).OK(t, nil)
	wc.POST("/api/v1/handlers/"+cfgHd+":call", map[string]any{"method": "peek", "args": map[string]any{}}).OK(t, &peek)
	if peek["who"] != "v1" {
		t.Fatalf("revert must spawn v1 with the preserved config: %+v", peek)
	}

	// —— B-hd-11: generator finals — yield-final AND return-final (StopIteration.value) ——
	gen := hdCreate(t, wc, "gen_final", map[string]any{
		"methods": []map[string]any{
			{"name": "yield_final", "inputs": []any{},
				"body": "yield {\"progress\": \"half\"}\nyield {\"v\": \"yield-final\"}"},
			{"name": "return_final", "inputs": []any{},
				"body": "yield {\"progress\": \"half\"}\nreturn {\"v\": \"return-final\"}"},
		},
	})
	var out map[string]any
	wc.POST("/api/v1/handlers/"+gen+":call", map[string]any{"method": "yield_final", "args": map[string]any{}}).OK(t, &out)
	if out["v"] != "yield-final" {
		t.Fatalf("last non-progress yield must be the final: %+v", out)
	}
	wc.POST("/api/v1/handlers/"+gen+":call", map[string]any{"method": "return_final", "args": map[string]any{}}).OK(t, &out)
	if out["v"] != "return-final" {
		t.Fatalf("generator return value (StopIteration.value) must be the final: %+v", out)
	}
}

// TestContractEntities_AgentMountHealthMatrix —— B-ag-4。
// mount-health 预检逐挂载独立收集（非 fail-fast）：knowledge doc 被删 → 该行 unhealthy 而
// 其余照常健康；两挂载合成撞名 → 与 Resolve 对称、第二个挂载标 unhealthy 引撞名。
func TestContractEntities_AgentMountHealthMatrix(t *testing.T) {
	wc, _ := agentSetup(t)

	docID := wc.POST("/api/v1/documents", map[string]any{"name": "kb doc", "content": "facts"}).Field(t, "id")
	fnID := fnCreate(t, wc, "tally_mh", "def tally_mh() -> dict:\n    return {}\n")
	hdID := hdCreate(t, wc, "greeter", map[string]any{
		"methods": []map[string]any{
			{"name": "hello", "description": "hi", "inputs": []any{}, "body": "return {\"hi\": True}"},
		},
	})
	// avoid the create-time readiness race noted in TestAgentR2 (handler still provisioning).
	// 避开 TestAgentR2 记录的就绪竞态（handler 还在开通）。
	harness.Eventually(t, 60000, "handler env ready before mounting", func() bool {
		r := wc.GET("/api/v1/handlers/" + hdID)
		if r.Status != 200 {
			return false
		}
		var got struct {
			ActiveVersion struct {
				EnvStatus string `json:"envStatus"`
			} `json:"activeVersion"`
		}
		_ = json.Unmarshal(r.Data, &got)
		return got.ActiveVersion.EnvStatus == "ready"
	})

	agID := agCreate(t, wc, map[string]any{
		"name": "Health Probe", "description": "x", "prompt": "x",
		"tools": []map[string]any{
			{"ref": fnID, "name": "tally"},
			{"ref": hdID + ".hello", "name": "hello"},
		},
		"knowledge": []string{docID},
	})

	type mhRow struct {
		Ref     string `json:"ref"`
		Name    string `json:"name"`
		Healthy bool   `json:"healthy"`
		Error   string `json:"error"`
	}
	var rep struct {
		Mounts     []mhRow `json:"mounts"`
		AllHealthy bool    `json:"allHealthy"`
	}
	rowByRef := func(ref string) *mhRow {
		t.Helper()
		for i := range rep.Mounts {
			if rep.Mounts[i].Ref == ref {
				return &rep.Mounts[i]
			}
		}
		t.Fatalf("mount-health missing row for %s: %+v", ref, rep.Mounts)
		return nil
	}

	// baseline: 2 tools + 1 knowledge row, all healthy. 基线：3 行全健康。
	wc.GET("/api/v1/agents/"+agID+"/mount-health").OK(t, &rep)
	if len(rep.Mounts) != 3 || !rep.AllHealthy {
		t.Fatalf("baseline mount-health must be 3 healthy rows (tools + knowledge): %+v", rep)
	}

	// delete the knowledge doc → ITS row flips unhealthy; the tools stay healthy
	// (independent per-mount collection, not fail-fast).
	// 删知识文档 → 该行翻 unhealthy；工具行照常健康（逐挂载独立收集、非 fail-fast）。
	if r := wc.DELETE("/api/v1/documents/" + docID); r.Status != 204 {
		t.Fatalf("doc delete: %d %s", r.Status, r.Raw)
	}
	wc.GET("/api/v1/agents/"+agID+"/mount-health").OK(t, &rep)
	if len(rep.Mounts) != 3 || rep.AllHealthy {
		t.Fatalf("post-doc-delete report wrong: %+v", rep)
	}
	if row := rowByRef(docID); row.Healthy {
		t.Fatalf("deleted knowledge doc must read unhealthy: %+v", row)
	}
	if row := rowByRef(fnID); !row.Healthy {
		t.Fatalf("fn mount must stay healthy (non-fail-fast): %+v", row)
	}
	if row := rowByRef(hdID + ".hello"); !row.Healthy {
		t.Fatalf("hd mount must stay healthy (non-fail-fast): %+v", row)
	}

	// rename the fn so both mounts synthesize "greeter__hello" → symmetric with Resolve,
	// the SECOND mount is flagged citing the collision.
	// 改名使两挂载同名合成 → 与 Resolve 对称，第二个挂载被标、错误引撞名。
	wc.PATCH("/api/v1/functions/"+fnID, map[string]any{"name": "greeter__hello"}).OK(t, nil)
	wc.GET("/api/v1/agents/"+agID+"/mount-health").OK(t, &rep)
	if len(rep.Mounts) != 3 || rep.AllHealthy {
		t.Fatalf("collision report wrong: %+v", rep)
	}
	if row := rowByRef(fnID); !row.Healthy {
		t.Fatalf("first mount of the colliding pair stays healthy (Resolve symmetry): %+v", row)
	}
	if row := rowByRef(hdID + ".hello"); row.Healthy || !strings.Contains(row.Error, "collides") {
		t.Fatalf("second colliding mount must be unhealthy citing the collision: %+v", row)
	}
}

// TestContractEntities_AgentInvokeWallClockTimeout —— B-ag-10。
// AgentInvokeSec 整次运行墙钟：慢 LLM 流被 deadline 切断 → 超时压过 loop 自报终态、
// InvokeResult 与耐久执行行都记 timeout（durable、可 replay 的语义面）。
func TestContractEntities_AgentInvokeWallClockTimeout(t *testing.T) {
	wc, mock := agentSetup(t)

	agID := agCreate(t, wc, map[string]any{"name": "Slowpoke", "description": "x", "prompt": "answer"})
	// machine-level limits ride this server's throwaway data dir — no cross-test bleed.
	// 机器级 limits 落本 server 的一次性数据目录——不串测。
	wc.PATCH("/api/v1/limits", map[string]any{"timeout": map[string]any{"agentInvokeSec": 2}}).OK(t, nil)

	mock.Enqueue(agModel, harness.LLMTurn{Text: "sloooow answer", StallMS: 6000})
	res := agInvoke(t, wc, agID, nil)
	if res.OK || res.Status != "timeout" {
		t.Fatalf("wall-clock must trump the loop's own terminal: %+v", res)
	}

	var page struct {
		Executions []struct {
			Status string `json:"status"`
		} `json:"executions"`
	}
	wc.GET("/api/v1/agents/"+agID+"/executions").OK(t, &page)
	if len(page.Executions) != 1 || page.Executions[0].Status != "timeout" {
		t.Fatalf("durable execution row must record timeout: %+v", page.Executions)
	}
}

// TestContractEntities_AgentNestedHumanLoop —— B-ag-14。
// 嵌套人在环：chat 主 LLM 调 invoke_agent，agent 的挂载工具自报 dangerous → 经父对话
// broker 阻塞成 pending interaction（不冒泡、不静默跑）；用户 approve 后子运行续跑、
// 工具真执行、整链完成。
func TestContractEntities_AgentNestedHumanLoop(t *testing.T) {
	wc, mock := agentSetup(t)

	fnID := fnCreate(t, wc, "guarded_fn", "def guarded_fn() -> dict:\n    return {\"did\": \"it\"}\n")
	agID := agCreate(t, wc, map[string]any{
		"name": "Careful Worker", "description": "x", "prompt": "use your tool",
		"tools": []map[string]any{{"ref": fnID, "name": "guarded_fn"}},
	})
	mock.Enqueue(agModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "guarded_fn", Args: map[string]any{
			"summary": "run the guarded fn", "danger": "dangerous", "execution_group": 1,
		}}}},
		harness.LLMTurn{Text: "done after approval"},
	)
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{ID: "call_nest", Name: "invoke_agent",
			Args: fw(map[string]any{"agentId": agID, "input": map[string]any{}})}}},
		harness.LLMTurn{Text: "relayed"},
	)

	convID := convCreate(t, wc, "nested gate")
	mid := sendMsg(t, wc, convID, "go")

	// the nested dangerous call parks an interaction on the PARENT conversation.
	// 嵌套危险调用把 interaction 挂在父对话上。
	var pending []struct {
		ToolCallID string `json:"toolCallId"`
		Kind       string `json:"kind"`
		Tool       string `json:"tool"`
	}
	harness.Eventually(t, 20000, "nested danger interaction pends on the parent conversation", func() bool {
		pending = nil
		r := wc.GET("/api/v1/conversations/" + convID + "/interactions")
		if r.Status != 200 {
			return false
		}
		if err := json.Unmarshal(r.Data, &pending); err != nil {
			return false
		}
		return len(pending) == 1
	})
	if pending[0].Kind != "danger" || pending[0].Tool != "guarded_fn" {
		t.Fatalf("pending interaction wrong: %+v", pending[0])
	}
	// blocked means NOT executed. 阻塞 = 尚未执行。
	var fnPage struct {
		Aggregates struct {
			OKCount int `json:"okCount"`
		} `json:"aggregates"`
	}
	wc.GET("/api/v1/functions/"+fnID+"/executions").OK(t, &fnPage)
	if fnPage.Aggregates.OKCount != 0 {
		t.Fatalf("dangerous tool must not run before resolve: %+v", fnPage.Aggregates)
	}

	// approve → the nested run resumes and the whole chain completes.
	// approve → 子运行续跑、整链完成。
	wc.POST("/api/v1/conversations/"+convID+"/interactions/"+pending[0].ToolCallID,
		map[string]any{"action": "approve"}).OK(t, nil)
	if turn := waitTurn(t, wc, convID, mid, 30000); turn.Status != "completed" {
		t.Fatalf("turn must complete after approval, got %s %s", turn.Status, turn.ErrorMessage)
	}
	wc.GET("/api/v1/functions/"+fnID+"/executions").OK(t, &fnPage)
	if fnPage.Aggregates.OKCount != 1 {
		t.Fatalf("approved tool must actually run: %+v", fnPage.Aggregates)
	}
	var agPage struct {
		Executions []struct {
			Status      string `json:"status"`
			TriggeredBy string `json:"triggeredBy"`
		} `json:"executions"`
	}
	wc.GET("/api/v1/agents/"+agID+"/executions").OK(t, &agPage)
	if len(agPage.Executions) != 1 || agPage.Executions[0].Status != "ok" || agPage.Executions[0].TriggeredBy != "chat" {
		t.Fatalf("nested agent execution row wrong: %+v", agPage.Executions)
	}
}
