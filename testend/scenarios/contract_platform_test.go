// contract_platform_test.go — Phase 1 契约全扫 · p1_platform 批次（A-ws/A-key/A-model/A-lim/
// A-sbx/A-free/A-sys + B-sup-4/6/10 的 unprobed 格）。
//
// 断言 = docs/references/backend/ 契约文档说的，不是「代码碰巧做的」：N1 envelope（空列表 []）、
// N4 分页（cursor 往返不重不漏 + limit 边界 400）、严格拒未知字段（decodeJSON DisallowUnknownFields
// → 400 INVALID_REQUEST）、apikey 软删名可重用 + keyMasked 永不漏明文、旋转自动重探（失败不挡
// PATCH）、受管行 API_KEY_IMMUTABLE、limits :reset 恢复服务端默认、sandbox envs 机器级（无 ws 列，
// foundation/sandbox.md）、freetier 无受管行 404、loopback 双门（坏 Host 403 / 坏 token 401 /
// webhook·OPTIONS 豁免 / health 不豁免）、WebSearch BYOK 真后端席。
//
// 契约缺口已在同批修复:limits/conversation PATCH 转严格解码、N4 对有界资源(workspaces/sandbox)登记豁免。
package scenarios

import (
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

// ── 本批次共享 helper（platformC_ 前缀，绝不碰既有 helper）──────────────────────

// platformC_ws 建一个 workspace 并返回 (id, 绑定客户端)。
func platformC_ws(t *testing.T, c *harness.Client, name string) (string, *harness.Client) {
	t.Helper()
	id := c.POST("/api/v1/workspaces", map[string]any{"name": name}).Field(t, "id")
	return id, c.WS(id)
}

// platformC_keyRow 是 apikey 实体的线缆投影（契约字段：keyMasked 脱敏、无明文 key 字段）。
type platformC_keyRow struct {
	ID          string `json:"id"`
	Provider    string `json:"provider"`
	DisplayName string `json:"displayName"`
	KeyMasked   string `json:"keyMasked"`
	TestStatus  string `json:"testStatus"`
}

// platformC_deleteKeys 删掉 ws 里指定 provider（空=全部）的所有**非受管** key，返回删除数。
// 受管 anselm 行自 S-1 起 DELETE 422 不可删——「无受管行」态只在 provisioner 未落行（离线/网关不可达）
// 时天然存在，测试须按「有无受管行」分支断言而非强造。
func platformC_deleteKeys(t *testing.T, wc *harness.Client, provider string) int {
	t.Helper()
	path := "/api/v1/api-keys?limit=200"
	if provider != "" {
		path += "&provider=" + provider
	}
	var rows []platformC_keyRow
	wc.GET(path).OK(t, &rows)
	n := 0
	for _, k := range rows {
		if k.Provider == "anselm" {
			continue // managed — immutable (S-1) 受管行不可删
		}
		if r := wc.Do("DELETE", "/api/v1/api-keys/"+k.ID, nil); r.Status == 204 {
			n++
		}
	}
	return n
}

// ── A-ws-3 + A-ws-8：workspace 列表分页 + 严格拒未知字段 ───────────────────────

// TestContractPlatform_WorkspaceListAndStrictFields:
// ① 列表基线：建 3 个 ws 全部现身、恰一次（不重不漏的非分页底线）。
// ② N4 豁免：workspaces 是有界可枚举资源,api.md 登记「返全集不分页」——分页参数被忽略、无 nextCursor。
// ③ 未知字段：POST/PATCH 带杂字段 → 400 INVALID_REQUEST（decodeJSON DisallowUnknownFields）。
func TestContractPlatform_WorkspaceListAndStrictFields(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)

	want := map[string]string{}
	for _, n := range []string{"pg-ws-a", "pg-ws-b", "pg-ws-c"} {
		want[n] = c.POST("/api/v1/workspaces", map[string]any{"name": n}).Field(t, "id")
	}

	// ① 全量列表：3 个各现身恰一次。
	var all []struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	}
	c.GET("/api/v1/workspaces").OK(t, &all)
	seen := map[string]int{}
	for _, w := range all {
		seen[w.ID]++
	}
	for n, id := range want {
		if seen[id] != 1 {
			t.Fatalf("workspace %s(%s) must appear exactly once in list, got %d", n, id, seen[id])
		}
	}

	// ② N4 豁免：workspaces 是有界可枚举资源（单用户少量），api.md 明示不分页、返全集。分页参数被
	//    忽略（标准 HTTP：不适用的 query 参数忽略而非 400），故 limit=1 仍返全部 3 行、无 nextCursor。
	r := c.GET("/api/v1/workspaces?limit=1&cursor=bogus")
	r.OK(t, nil)
	var limited []struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(r.Data, &limited)
	if len(limited) < 3 || r.NextCursor != "" {
		t.Fatalf("bounded-list exemption: workspaces returns the full set ignoring pagination params, got %d rows cursor=%q", len(limited), r.NextCursor)
	}

	// ③ 未知字段严格拒收（transport 统一 decodeJSON）。
	c.Do("POST", "/api/v1/workspaces", map[string]any{"name": "strict-ws", "bogusField": 1}).
		Fail(t, 400, "INVALID_REQUEST")
	c.Do("PATCH", "/api/v1/workspaces/"+want["pg-ws-a"], map[string]any{"name": "renamed", "wizard": true}).
		Fail(t, 400, "INVALID_REQUEST")
	// 拒收即原子：合法字段也不得被半吞。
	var after struct {
		Name string `json:"name"`
	}
	c.GET("/api/v1/workspaces/" + want["pg-ws-a"]).OK(t, &after)
	if after.Name != "pg-ws-a" {
		t.Fatalf("rejected PATCH must not half-apply: name became %q", after.Name)
	}
}

// ── A-key-3 + A-key-4 + A-key-6 + A-key-8：apikey 分页/N1/软删/严格字段 ─────────

// TestContractPlatform_APIKeyListEnvelopeAndSoftDelete:
// ① N1 空列表：零 key（provider 过滤面）→ {"data":[]} 非 null。
// ② 未知字段：POST/PATCH 带杂字段 → 400 INVALID_REQUEST。
// ③ 掩码回显：keyMasked = 头部+…+末4，全响应绝不漏明文。
// ④ N4 分页：5 key limit=2 走 cursor 不重不漏收口；limit=0/abc → 400 INVALID_REQUEST；
//    垃圾 cursor → 400 MALFORMED_CURSOR。
// ⑤ 软删：DELETE 204 空体 → 列表过滤 → 同名重建 201 新 id、列表只见新行。
func TestContractPlatform_APIKeyListEnvelopeAndSoftDelete(t *testing.T) {
	srv := harness.Start(t)
	mock := harness.NewLLMMock(t)
	c := srv.Client(t)
	_, wc := platformC_ws(t, c, "key-contract-ws")

	// ① 空列表形状（provider=openai 过滤面恒为空，免受异步落地的受管 anselm 行干扰）。
	r := wc.GET("/api/v1/api-keys?provider=openai")
	r.OK(t, nil)
	if strings.TrimSpace(string(r.Data)) != "[]" {
		t.Fatalf("N1: empty key list must be data:[] (never null), got %s", r.Raw)
	}
	if r.HasMore {
		t.Fatalf("empty list must have hasMore=false: %s", r.Raw)
	}

	// ② 未知字段严格拒收。
	wc.Do("POST", "/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "x", "key": "sk-x", "bogus": 1,
	}).Fail(t, 400, "INVALID_REQUEST")

	// ③ 掩码：长 key 取 头7+"..."+末4；任何响应不含明文。
	plaintext := "sk-contract-0123456789abcdef"
	var first platformC_keyRow
	wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "pg-key-1", "key": plaintext, "baseUrl": mock.URL(),
	}).OK(t, &first)
	if first.KeyMasked != "sk-cont...cdef" {
		t.Fatalf("keyMasked shape drifted: %q (want head7...last4)", first.KeyMasked)
	}
	for i := 2; i <= 5; i++ {
		wc.POST("/api/v1/api-keys", map[string]any{
			"provider": "openai", "displayName": fmt.Sprintf("pg-key-%d", i),
			"key": fmt.Sprintf("sk-page-%d-0123456789", i), "baseUrl": mock.URL(),
		}).OK(t, nil)
	}
	full := wc.GET("/api/v1/api-keys?provider=openai&limit=200")
	full.OK(t, nil)
	if strings.Contains(string(full.Raw), plaintext) {
		t.Fatal("plaintext key leaked into list response")
	}

	// PATCH 带未知字段同样拒收（A-key-8 的 PATCH 面）。
	wc.Do("PATCH", "/api/v1/api-keys/"+first.ID, map[string]any{"displayName": "y", "wizard": 1}).
		Fail(t, 400, "INVALID_REQUEST")

	// ④ 分页往返：limit=2 逐页收集，5 个 id 不重不漏。
	collected := map[string]bool{}
	cursor := ""
	for page := 0; ; page++ {
		if page > 10 {
			t.Fatal("pagination never terminated")
		}
		path := "/api/v1/api-keys?provider=openai&limit=2"
		if cursor != "" {
			path += "&cursor=" + url.QueryEscape(cursor)
		}
		pr := wc.GET(path)
		pr.OK(t, nil)
		var rows []platformC_keyRow
		if err := json.Unmarshal(pr.Data, &rows); err != nil {
			t.Fatalf("page decode: %v", err)
		}
		if len(rows) > 2 {
			t.Fatalf("limit=2 page returned %d rows", len(rows))
		}
		for _, k := range rows {
			if collected[k.ID] {
				t.Fatalf("cursor walk repeated id %s", k.ID)
			}
			collected[k.ID] = true
		}
		if pr.NextCursor == "" {
			if pr.HasMore {
				t.Fatalf("last page must have hasMore=false: %s", pr.Raw)
			}
			break
		}
		if !pr.HasMore {
			t.Fatalf("non-last page must have hasMore=true: %s", pr.Raw)
		}
		cursor = pr.NextCursor
	}
	if len(collected) != 5 {
		t.Fatalf("cursor walk must cover exactly 5 keys, got %d", len(collected))
	}

	// limit 边界 + 垃圾 cursor 的精确码。
	wc.Do("GET", "/api/v1/api-keys?limit=0", nil).Fail(t, 400, "INVALID_REQUEST")
	wc.Do("GET", "/api/v1/api-keys?limit=abc", nil).Fail(t, 400, "INVALID_REQUEST")
	wc.Do("GET", "/api/v1/api-keys?cursor=%21%21%21not-a-cursor", nil).Fail(t, 400, "MALFORMED_CURSOR")

	// ⑤ 软删 + 同名重建。
	dr := wc.Do("DELETE", "/api/v1/api-keys/"+first.ID, nil)
	if dr.Status != 204 || len(dr.Raw) != 0 {
		t.Fatalf("DELETE must be 204 No Content with empty body, got %d %q", dr.Status, dr.Raw)
	}
	var afterDel []platformC_keyRow
	wc.GET("/api/v1/api-keys?provider=openai&limit=200").OK(t, &afterDel)
	if len(afterDel) != 4 {
		t.Fatalf("soft-deleted key must leave the list: %d rows", len(afterDel))
	}
	for _, k := range afterDel {
		if k.ID == first.ID {
			t.Fatal("soft-deleted key still listed")
		}
	}
	var reborn platformC_keyRow
	wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "pg-key-1", "key": "sk-reborn-0123456789", "baseUrl": mock.URL(),
	}).OK(t, &reborn) // 软删后名字必须可重用（partial UNIQUE 仅活跃行）
	if reborn.ID == first.ID {
		t.Fatal("recreate must mint a new id")
	}
	var final []platformC_keyRow
	wc.GET("/api/v1/api-keys?provider=openai&limit=200").OK(t, &final)
	dupCount := 0
	for _, k := range final {
		if k.DisplayName == "pg-key-1" {
			dupCount++
			if k.ID != reborn.ID {
				t.Fatalf("list shows stale pg-key-1 row %s (want only %s)", k.ID, reborn.ID)
			}
		}
	}
	if dupCount != 1 {
		t.Fatalf("exactly one pg-key-1 row must remain, got %d", dupCount)
	}
}

// ── B-sup-4：旋转自动重探 / 受管行不可编辑 / apiFormat 白名单 ───────────────────

// TestContractPlatform_APIKeyRotationManagedAPIFormat:
// ① 旋转（PATCH 带新 key）自动重探：探活成功 → 200 且 testStatus=ok（非静默 pending）；
//   探针失败不挡 PATCH → 200 且 testStatus=error（旋转本身成功，脑裂取舍 G7）。
// ② 受管 provider（anselm）行 Update → 422 API_KEY_IMMUTABLE；删除（无引用）放行。
// ③ custom provider apiFormat 白名单：缺 → 400 API_KEY_API_FORMAT_REQUIRED；
//   白名单外 → 400 API_KEY_API_FORMAT_INVALID；合法二选一 → 201。
func TestContractPlatform_APIKeyRotationManagedAPIFormat(t *testing.T) {
	srv := harness.Start(t)
	mock := harness.NewLLMMock(t)
	c := srv.Client(t)
	_, wc := platformC_ws(t, c, "rotate-ws")

	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "rotator", "key": "sk-original-123456", "baseUrl": mock.URL(),
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)

	// ① 旋转到活 baseUrl：自动重探 → 响应即带 ok（不留 pending）。
	var rotated platformC_keyRow
	wc.PATCH("/api/v1/api-keys/"+keyID, map[string]any{"key": "sk-rotated-123456"}).OK(t, &rotated)
	if rotated.TestStatus != "ok" {
		t.Fatalf("rotation with live tester must auto-reprobe to ok, got testStatus=%q", rotated.TestStatus)
	}
	if rotated.KeyMasked == "" || strings.Contains(rotated.KeyMasked, "sk-rotated-123456") {
		t.Fatalf("rotated keyMasked must re-mask: %q", rotated.KeyMasked)
	}

	// 旋转指向死端口：重探失败必须不挡 PATCH（200），状态诚实落 error。
	var dead platformC_keyRow
	wc.PATCH("/api/v1/api-keys/"+keyID, map[string]any{
		"key": "sk-dead-123456", "baseUrl": "http://127.0.0.1:1",
	}).OK(t, &dead)
	if dead.TestStatus != "error" {
		t.Fatalf("failed auto-reprobe must not block PATCH and must persist error, got %q", dead.TestStatus)
	}

	// ② 受管 provider 行不可编辑（Managed 按 provider meta 判定）。
	managedID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "anselm", "displayName": "manual-anselm", "key": "gwk_fake_0123456789",
	}).Field(t, "id")
	wc.Do("PATCH", "/api/v1/api-keys/"+managedID, map[string]any{"displayName": "hijack"}).
		Fail(t, 422, "API_KEY_IMMUTABLE")
	// 零引用也不可删（WRK-062 S-1：DELETE 与 PATCH 对称守卫——受管 gwk_ 凭证无用户侧重开通入口）。
	wc.Do("DELETE", "/api/v1/api-keys/"+managedID, nil).Fail(t, 422, "API_KEY_IMMUTABLE")

	// ③ apiFormat 白名单（仅 custom provider 强制）。
	wc.Do("POST", "/api/v1/api-keys", map[string]any{
		"provider": "custom", "displayName": "fmt-missing", "key": "sk-c", "baseUrl": mock.URL(),
	}).Fail(t, 400, "API_KEY_API_FORMAT_REQUIRED")
	wc.Do("POST", "/api/v1/api-keys", map[string]any{
		"provider": "custom", "displayName": "fmt-bad", "key": "sk-c", "baseUrl": mock.URL(),
		"apiFormat": "carrier-pigeon",
	}).Fail(t, 400, "API_KEY_API_FORMAT_INVALID")
	wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "custom", "displayName": "fmt-good", "key": "sk-c", "baseUrl": mock.URL(),
		"apiFormat": "openai-compatible",
	}).OK(t, nil)
}

// ── A-model-4 + A-model-5：capabilities 空态形状 + 跨 ws 不串 ───────────────────

// TestContractPlatform_ModelCapabilitiesEmptyAndIsolation:
// ① 零 key 空态：删尽 ws 的 key（含异步落地的受管 anselm 行）→ data:[]（非 null）。
// ② 跨 ws 聚合独立：wsA 配 mock key 并探测 → wsA capabilities 现 gpt-4o；wsB 恒不见。
func TestContractPlatform_ModelCapabilitiesEmptyAndIsolation(t *testing.T) {
	srv := harness.Start(t)
	mock := harness.NewLLMMock(t)
	c := srv.Client(t)
	_, wa := platformC_ws(t, c, "caps-a")
	_, wb := platformC_ws(t, c, "caps-b")

	// ① wsB 删尽非受管 key 后：无受管行→恰 []；受管行落了（在线网关）→只可能剩 anselm 目录项。
	//   （受管行自 S-1 不可删,「零 key」态不再可强造——按有无受管行分支断言。）
	harness.Eventually(t, 30000, "capabilities settle to baseline once wsB has no BYOK keys", func() bool {
		platformC_deleteKeys(t, wb, "")
		var rows []platformC_keyRow
		wb.GET("/api/v1/api-keys?limit=200").OK(t, &rows)
		r := wb.Do("GET", "/api/v1/model-capabilities", nil)
		if r.Status != 200 {
			return false
		}
		if len(rows) == 0 {
			return strings.TrimSpace(string(r.Data)) == "[]"
		}
		// Managed row present — the only capabilities allowed are the anselm ones. 只许 anselm 项。
		return !strings.Contains(string(r.Raw), "gpt-4o")
	})

	// ② wsA 配 mock key + 探测 → 目录现身；wsB 不串。
	keyID := wa.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "caps-key", "key": "sk-caps", "baseUrl": mock.URL(),
	}).Field(t, "id")
	wa.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	capsA := wa.GET("/api/v1/model-capabilities")
	capsA.OK(t, nil)
	if !strings.Contains(string(capsA.Raw), "gpt-4o") {
		t.Fatalf("wsA capabilities must surface probed gpt-4o: %s", capsA.Raw)
	}
	capsB := wb.GET("/api/v1/model-capabilities")
	capsB.OK(t, nil)
	if strings.Contains(string(capsB.Raw), "gpt-4o") {
		t.Fatalf("wsB must NOT see wsA's probed models (per-workspace aggregation): %s", capsB.Raw)
	}
}

// ── A-lim-7 + A-lim-8：limits :reset 恢复默认 + PATCH 未知字段行为 ──────────────

// TestContractPlatform_LimitsResetAndPatchEdges:
// ① /limits/schema 携带逐字段 default → PATCH 改 agent.maxSteps → GET 回读 → POST :reset
//   （无 body）→ 响应与 GET 均回到 schema 默认（服务端持有默认、客户端不硬编）。
//   （PATCH 热换的消费方行为已由 TestPlatform_LimitsHotSwap/R4 钉死；:reset 走同一 install 热换路径。）
// ② PATCH 未知键 → 400 SETTINGS_LIMITS_INVALID（PatchLimits 转严格解码,与全平台一致）;
//   已知键错型 → 400 SETTINGS_LIMITS_INVALID；显式越界 0 → 400 SETTINGS_LIMITS_INVALID。
func TestContractPlatform_LimitsResetAndPatchEdges(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	_, wc := platformC_ws(t, c, "limits-ws")

	// schema：逐字段元数据必须带 key/default，取 agent.maxSteps 的服务端默认。
	var schema []struct {
		Key     string  `json:"key"`
		Default float64 `json:"default"`
		Min     float64 `json:"min"`
	}
	wc.GET("/api/v1/limits/schema").OK(t, &schema)
	defaultMaxSteps := -1
	for _, f := range schema {
		if f.Key == "agent.maxSteps" {
			defaultMaxSteps = int(f.Default)
		}
	}
	if defaultMaxSteps <= 0 {
		t.Fatalf("limits/schema must carry agent.maxSteps default, got %+v", schema)
	}

	// PATCH → 回读。
	patched := defaultMaxSteps + 7
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": patched}}).OK(t, nil)
	var lim wireLimits
	wc.GET("/api/v1/limits").OK(t, &lim)
	if lim.Agent.MaxSteps != patched {
		t.Fatalf("PATCH not persisted: maxSteps=%d want %d", lim.Agent.MaxSteps, patched)
	}

	// :reset（无 body）→ 响应即（现为默认的）活动值，形与 GET 同；GET 复核。
	rr := wc.POST("/api/v1/limits:reset", nil)
	rr.OK(t, nil)
	var groups map[string]json.RawMessage
	if err := json.Unmarshal(rr.Data, &groups); err != nil {
		t.Fatalf(":reset data not an object: %s", rr.Data)
	}
	for _, g := range []string{"agent", "context", "timeout", "tools", "guards"} {
		if _, ok := groups[g]; !ok {
			t.Fatalf(":reset response must be the full limits shape, missing %q: %s", g, rr.Data)
		}
	}
	var resetLim wireLimits
	_ = json.Unmarshal(rr.Data, &resetLim)
	if resetLim.Agent.MaxSteps != defaultMaxSteps {
		t.Fatalf(":reset must restore schema default %d, got %d", defaultMaxSteps, resetLim.Agent.MaxSteps)
	}
	wc.GET("/api/v1/limits").OK(t, &lim)
	if lim.Agent.MaxSteps != defaultMaxSteps {
		t.Fatalf(":reset not persisted/hot-swapped: GET shows %d", lim.Agent.MaxSteps)
	}

	// ② 未知键：当前 200 静默吞（值不动）。
	before := lim.Agent.MaxSteps
	// PATCH /limits 严格拒未知键（与全平台 decodeJSON 一致）：未知组、拼错字段名（maxStep 应为 maxStepS）
	// 都 400 SETTINGS_LIMITS_INVALID,不再静默吞返 200——typo 有反馈。
	wc.Do("PATCH", "/api/v1/limits", map[string]any{"quantumFlux": map[string]any{"x": 9}}).
		Fail(t, 400, "SETTINGS_LIMITS_INVALID")
	wc.Do("PATCH", "/api/v1/limits", map[string]any{"agent": map[string]any{"maxStep": 2}}).
		Fail(t, 400, "SETTINGS_LIMITS_INVALID")
	// 拒收即原子：合法值不被半吞。
	wc.GET("/api/v1/limits").OK(t, &lim)
	if lim.Agent.MaxSteps != before {
		t.Fatalf("rejected PATCH must not corrupt values: %d → %d", before, lim.Agent.MaxSteps)
	}

	// 已知键错型 / 显式越界 0 → 精确 400。
	wc.Do("PATCH", "/api/v1/limits", map[string]any{"agent": 5}).
		Fail(t, 400, "SETTINGS_LIMITS_INVALID")
	wc.Do("PATCH", "/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 0}}).
		Fail(t, 400, "SETTINGS_LIMITS_INVALID")
}

// ── A-sbx-3 + A-sbx-5 + A-sbx-7 + A-sbx-8：sandbox 列表/隔离/动作/严格字段 ──────

// TestContractPlatform_SandboxGovernanceEdges:
// ① runtimes/envs 是有界系统级资源,api.md 登记 N4 豁免:忽略分页参数、返全集无 nextCursor。
// ② envs 机器级可见（foundation/sandbox.md：sandbox_envs 系统级、无 ws 列——批次行描述
//   「跨 ws 互不见」与契约不符，以契约为准断两 ws 同见）。
// ③ :retry-bootstrap 带内返回 {ok}（失败是 degraded 非 HTTP 错）；对话 scratch
//   {kind}:reset 幂等 204、:reset-all 返 {removed}。
// ④ POST /sandbox/runtimes 拒未知字段 → 400 INVALID_REQUEST（在触发任何下载之前）。
func TestContractPlatform_SandboxGovernanceEdges(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	_, wa := platformC_ws(t, c, "sbx-a")
	_, wb := platformC_ws(t, c, "sbx-b")

	// wsA 物化一个 function env，让列表面有真实内容。
	fnCreate(t, wa, "sbx_probe_fn", "def sbx_probe_fn() -> dict:\n    return {}\n")

	var envs []struct {
		ID        string `json:"id"`
		OwnerKind string `json:"ownerKind"`
	}
	wa.GET("/api/v1/sandbox/envs?ownerKind=function").OK(t, &envs)
	if len(envs) == 0 {
		t.Fatal("function env must be listed after materialization")
	}

	// ① N4 分页缺口现场：limit=1 被忽略、垃圾 limit 不 400。
	lr := wa.GET("/api/v1/sandbox/runtimes?limit=1")
	lr.OK(t, nil)
	var runtimes []struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(lr.Data, &runtimes)
	// N4 豁免：sandbox runtimes（≤4 种）/envs 是有界系统级资源,api.md 明示不分页返全集;分页参数忽略,
	// 无 nextCursor（管理/磁盘面本就要全集）。
	if lr.NextCursor != "" {
		t.Fatalf("bounded-list exemption: sandbox runtimes returns full set, no cursor, got cursor=%q", lr.NextCursor)
	}

	// ② envs 机器级：wsB 同见 wsA 物化的 env（表无 workspace 列，系统级审计面）。
	var envsB []struct {
		ID string `json:"id"`
	}
	wb.GET("/api/v1/sandbox/envs?ownerKind=function").OK(t, &envsB)
	found := false
	for _, e := range envsB {
		if e.ID == envs[0].ID {
			found = true
		}
	}
	if !found {
		t.Fatalf("sandbox envs are machine-level (no ws column) — wsB must see env %s, got %+v", envs[0].ID, envsB)
	}
	wb.GET("/api/v1/sandbox/envs/" + envs[0].ID).OK(t, nil) // 单读同理机器级可达

	// ③ :retry-bootstrap 带内状态。
	rb := wa.POST("/api/v1/sandbox:retry-bootstrap", nil)
	rb.OK(t, nil)
	var boot map[string]json.RawMessage
	if err := json.Unmarshal(rb.Data, &boot); err != nil {
		t.Fatalf(":retry-bootstrap data not object: %s", rb.Data)
	}
	if _, ok := boot["ok"]; !ok {
		t.Fatalf(":retry-bootstrap must report {ok} in-band: %s", rb.Data)
	}

	// 对话 scratch env 面：列表 []（当前无生产者写 conversation scratch）→ reset 幂等 204 →
	// reset-all 返 {removed:0}。
	convID := convCreate(t, wa, "scratch probe")
	sr := wa.GET("/api/v1/conversations/" + convID + "/sandbox-envs")
	sr.OK(t, nil)
	if strings.TrimSpace(string(sr.Data)) != "[]" {
		t.Fatalf("conversation scratch env list must be [] (N1, never null): %s", sr.Raw)
	}
	if rst := wa.Do("POST", "/api/v1/conversations/"+convID+"/sandbox-envs/python:reset", nil); rst.Status != 204 {
		t.Fatalf("scratch {kind}:reset must be idempotent 204, got %d %s", rst.Status, rst.Raw)
	}
	var removed struct {
		Removed int `json:"removed"`
	}
	wa.POST("/api/v1/conversations/"+convID+"/sandbox-envs:reset-all", nil).OK(t, &removed)
	if removed.Removed != 0 {
		t.Fatalf(":reset-all on a scratchless conversation must remove 0, got %d", removed.Removed)
	}

	// ④ 装 runtime 拒未知字段（decode 在 EnsureRuntime 之前，绝不触发下载）。
	wa.Do("POST", "/api/v1/sandbox/runtimes", map[string]any{
		"kind": "python", "version": "3.12", "bogus": true,
	}).Fail(t, 400, "INVALID_REQUEST")
}

// ── A-free-2 + A-free-4 + A-free-5 + B-sup-6：freetier 配额代理 REST 面 ─────────

// TestContractPlatform_FreetierQuota:
// ① NotProvisioned：受管行自 S-1 不可删——404 态只在 provisioner 未落行（离线/网关不可达）时天然
//   存在，按「有无受管行」分支断言：无行→404 FREETIER_NOT_PROVISIONED；有行→跳过（404 面不可造）。
// ② QuotaShape：等 provisioner 落行后打 quota——200 时 data 必须五字段全在
//   {limit,used,remaining,resetAt,available} 且 remaining≥0；网关自身失败必须按
//   LLM_AUTH_FAILED/LLM_RATE_LIMITED/LLM_PROVIDER_ERROR 分类冒泡（绝不本地翻行）。
//   注：remaining 钳≥0 与 available 折日预算由网关计算、后端原样转发；分类与代理逻辑的
//   脚本化分支已有单测（backend/internal/app/freetier/quota_test.go + infra/llm/quota_test.go）。
//   只读 REST 面，绝不用受管 key 跑 chat/agent。
func TestContractPlatform_FreetierQuota(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	_, wa := platformC_ws(t, c, "free-a")
	_, wb := platformC_ws(t, c, "free-b")

	t.Run("NotProvisioned404", func(t *testing.T) {
		// 受管行不可删（S-1）→ 404 态不可强造。给 provisioner 一个短窗:窗内落了行=在线环境,
		// 断言该行 DELETE 422(守卫)并跳过 404 分支;窗尽无行=离线环境,404 必现。
		deadline := time.Now().Add(10 * time.Second)
		for time.Now().Before(deadline) {
			var rows []platformC_keyRow
			wb.GET("/api/v1/api-keys?provider=anselm&limit=1").OK(t, &rows)
			if len(rows) > 0 {
				wb.Do("DELETE", "/api/v1/api-keys/"+rows[0].ID, nil).Fail(t, 422, "API_KEY_IMMUTABLE")
				t.Skip("managed row provisioned (gateway reachable) — the 404 face is not constructible by design (S-1)")
			}
			r := wb.Do("GET", "/api/v1/freetier/quota", nil)
			if r.Status == 404 && r.Code == "FREETIER_NOT_PROVISIONED" {
				return // offline path pinned 离线面钉死
			}
			time.Sleep(300 * time.Millisecond)
		}
		t.Fatal("neither a managed row nor FREETIER_NOT_PROVISIONED within the window")
	})

	t.Run("QuotaShapeOrClassifiedError", func(t *testing.T) {
		// 等 wsA 的受管行落地（真网关 install，网络依赖；不可达则跳过本分支——404 面已在上面钉死）。
		provisioned := false
		deadline := time.Now().Add(30 * time.Second)
		for time.Now().Before(deadline) {
			var rows []platformC_keyRow
			wa.GET("/api/v1/api-keys?provider=anselm&limit=1").OK(t, &rows)
			if len(rows) > 0 {
				provisioned = true
				break
			}
			time.Sleep(300 * time.Millisecond)
		}
		if !provisioned {
			t.Skip("free-tier provisioner did not land a managed row (offline/gateway unreachable) — quota shape branch not exercisable")
		}
		r := wa.Do("GET", "/api/v1/freetier/quota", nil)
		switch {
		case r.Status == 200:
			var q map[string]json.RawMessage
			if err := json.Unmarshal(r.Data, &q); err != nil {
				t.Fatalf("quota data not object: %s", r.Raw)
			}
			for _, f := range []string{"limit", "used", "remaining", "resetAt", "available"} {
				if _, ok := q[f]; !ok {
					t.Fatalf("quota data must carry %q inside N1 envelope: %s", f, r.Raw)
				}
			}
			var typed struct {
				Remaining int64 `json:"remaining"`
			}
			_ = json.Unmarshal(r.Data, &typed)
			if typed.Remaining < 0 {
				t.Fatalf("remaining must be clamped >= 0, got %d", typed.Remaining)
			}
		case r.Code == "LLM_AUTH_FAILED" || r.Code == "LLM_RATE_LIMITED" || r.Code == "LLM_PROVIDER_ERROR":
			// 网关自身失败原样按 LLM_* 分类冒泡——同样是契约面（error-codes.md FREETIER 注）。
			t.Logf("gateway error classified as %s (%d) — classification face verified", r.Code, r.Status)
		default:
			t.Fatalf("quota must be 200 shape or a classified LLM_* error, got %d/%s %s", r.Status, r.Code, r.Raw)
		}
	})
}

// ── A-sys-4：health / data-dir 的 N1 形状 ───────────────────────────────────────

// TestContractPlatform_SystemEnvelopes:
// ① GET /health：N1 envelope {"data":{"status":"ok"}}，免 workspace 头。
// ② GET /system/data-dir：guarded（无 ws 头 → 401 UNAUTH_NO_WORKSPACE）；有头 → {dataDir}
//   = 启动时 ANSELM_DATA_DIR 的解析值。
func TestContractPlatform_SystemEnvelopes(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)

	var health struct {
		Status string `json:"status"`
	}
	c.GET("/api/v1/health").OK(t, &health) // 无 ws 头即可
	if health.Status != "ok" {
		t.Fatalf(`health must be N1 {"data":{"status":"ok"}}, got %+v`, health)
	}

	c.Do("GET", "/api/v1/system/data-dir", nil).Fail(t, 401, "UNAUTH_NO_WORKSPACE")

	_, wc := platformC_ws(t, c, "sys-ws")
	var dd struct {
		DataDir string `json:"dataDir"`
	}
	wc.GET("/api/v1/system/data-dir").OK(t, &dd)
	if dd.DataDir != srv.DataDir {
		t.Fatalf("data-dir must echo the resolved ANSELM_DATA_DIR: got %q want %q", dd.DataDir, srv.DataDir)
	}
}

// ── A-sys-2：loopback 双门（Host 门 + Bearer 门）────────────────────────────────

// platformC_tokenBin 独立编译 cmd/server（harness.Start 不支持注入额外 env——token 门
// 在 testend 恒关。harness gap 已上报；此处自建最小 boot 以覆盖 bearer 面）。
var (
	platformC_buildOnce sync.Once
	platformC_buildErr  error
	platformC_binPath   string
)

func platformC_binary(t *testing.T) string {
	t.Helper()
	platformC_buildOnce.Do(func() {
		dir, err := os.MkdirTemp("", "contract-platform-bin-*")
		if err != nil {
			platformC_buildErr = err
			return
		}
		platformC_binPath = filepath.Join(dir, "anselm-server")
		wd, _ := os.Getwd()
		backend := ""
		for d := wd; d != "/"; d = filepath.Dir(d) {
			if _, err := os.Stat(filepath.Join(d, "backend", "cmd", "server")); err == nil {
				backend = filepath.Join(d, "backend")
				break
			}
		}
		if backend == "" {
			platformC_buildErr = fmt.Errorf("backend dir not found above %s", wd)
			return
		}
		cmd := exec.Command("go", "build", "-o", platformC_binPath, "./cmd/server")
		cmd.Dir = backend
		if out, err := cmd.CombinedOutput(); err != nil {
			platformC_buildErr = fmt.Errorf("build backend: %v\n%s", err, out)
		}
	})
	if platformC_buildErr != nil {
		t.Fatalf("platformC binary: %v", platformC_buildErr)
	}
	return platformC_binPath
}

// platformC_startTokenServer 以 ANSELM_AUTH_TOKEN 启动一个真实 backend，等 health（带 bearer）。
func platformC_startTokenServer(t *testing.T, token string) string {
	t.Helper()
	bin := platformC_binary(t)
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("free port: %v", err)
	}
	addr := l.Addr().String()
	_ = l.Close()
	cmd := exec.Command(bin)
	cmd.Env = append(os.Environ(),
		"ANSELM_DATA_DIR="+t.TempDir(),
		"ANSELM_ADDR="+addr,
		"ANSELM_AUTH_TOKEN="+token,
	)
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		t.Fatalf("start token server: %v", err)
	}
	t.Cleanup(func() {
		_ = cmd.Process.Kill()
		_, _ = cmd.Process.Wait()
	})
	base := "http://" + addr
	deadline := time.Now().Add(30 * time.Second)
	for time.Now().Before(deadline) {
		st, _ := platformC_raw(t, "GET", base+"/api/v1/health", map[string]string{"Authorization": "Bearer " + token}, "")
		if st == 200 {
			return base
		}
		time.Sleep(150 * time.Millisecond)
	}
	t.Fatalf("token server never became healthy at %s", base)
	return ""
}

// platformC_raw 发一个裸 HTTP 请求（可覆盖 Host 头），返回 (status, error.code)。
func platformC_raw(t *testing.T, method, rawURL string, hdr map[string]string, hostOverride string) (int, string) {
	t.Helper()
	req, err := http.NewRequest(method, rawURL, nil)
	if err != nil {
		t.Fatalf("raw request: %v", err)
	}
	for k, v := range hdr {
		req.Header.Set(k, v)
	}
	if hostOverride != "" {
		req.Host = hostOverride
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return 0, "" // 连接失败（等 health 的轮询会重试）
	}
	defer resp.Body.Close()
	var env struct {
		Error *struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&env)
	code := ""
	if env.Error != nil {
		code = env.Error.Code
	}
	return resp.StatusCode, code
}

// TestContractPlatform_LoopbackDoors: loopback 加固两道门。
// ① Host 门常开（token 无关）：伪 Host → 403 FORBIDDEN_BAD_HOST；无 token 时 bearer 关、health 裸通。
// ② Bearer 门（设 ANSELM_AUTH_TOKEN 的独立 server）：缺/错 token → 401 UNAUTH_BAD_TOKEN；
//   /health 不豁免；OPTIONS 与 /webhooks/ 豁免；Host 门先于 token 判定（好 token+坏 Host 仍 403）。
func TestContractPlatform_LoopbackDoors(t *testing.T) {
	t.Run("HostDoorAlwaysOn", func(t *testing.T) {
		srv := harness.Start(t)
		// 无 token：health 裸通（bearer 关）。
		if st, code := platformC_raw(t, "GET", srv.BaseURL+"/api/v1/health", nil, ""); st != 200 {
			t.Fatalf("tokenless server must serve health bare, got %d/%s", st, code)
		}
		// 伪 Host（DNS rebinding 姿态）→ 403 FORBIDDEN_BAD_HOST。
		if st, code := platformC_raw(t, "GET", srv.BaseURL+"/api/v1/health", nil, "evil.example.com"); st != 403 || code != "FORBIDDEN_BAD_HOST" {
			t.Fatalf("bad Host must 403 FORBIDDEN_BAD_HOST, got %d/%s", st, code)
		}
		// localhost 名放行（合法别名不误伤）。
		if st, _ := platformC_raw(t, "GET", srv.BaseURL+"/api/v1/health", nil, "localhost:9"); st != 200 {
			t.Fatalf("Host localhost must pass the door, got %d", st)
		}
	})

	t.Run("BearerDoorWithToken", func(t *testing.T) {
		const token = "contract-loopback-token"
		base := platformC_startTokenServer(t, token)
		auth := map[string]string{"Authorization": "Bearer " + token}

		// health 不豁免 bearer：缺 token 401。
		if st, code := platformC_raw(t, "GET", base+"/api/v1/health", nil, ""); st != 401 || code != "UNAUTH_BAD_TOKEN" {
			t.Fatalf("health without token must 401 UNAUTH_BAD_TOKEN, got %d/%s", st, code)
		}
		// 错 token 401。
		if st, code := platformC_raw(t, "GET", base+"/api/v1/health",
			map[string]string{"Authorization": "Bearer wrong-token"}, ""); st != 401 || code != "UNAUTH_BAD_TOKEN" {
			t.Fatalf("wrong token must 401 UNAUTH_BAD_TOKEN, got %d/%s", st, code)
		}
		// 对 token 200。
		if st, _ := platformC_raw(t, "GET", base+"/api/v1/health", auth, ""); st != 200 {
			t.Fatalf("correct token must pass, got %d", st)
		}
		// 业务面同受门控（不只 health）。
		if st, code := platformC_raw(t, "GET", base+"/api/v1/workspaces", nil, ""); st != 401 || code != "UNAUTH_BAD_TOKEN" {
			t.Fatalf("business route without token must 401, got %d/%s", st, code)
		}
		// OPTIONS 豁免（CORS 预检无 Authorization）。
		if st, code := platformC_raw(t, "OPTIONS", base+"/api/v1/workspaces", nil, ""); st == 401 || code == "UNAUTH_BAD_TOKEN" {
			t.Fatalf("OPTIONS must be exempt from bearer, got %d/%s", st, code)
		}
		// /webhooks/ 豁免（外部调用方自带 HMAC）——不 401（404 无此 trigger 是预期）。
		if st, code := platformC_raw(t, "POST", base+"/api/v1/webhooks/trg_nonexistent/nope", nil, ""); st == 401 || code == "UNAUTH_BAD_TOKEN" {
			t.Fatalf("webhook inbound must be exempt from bearer, got %d/%s", st, code)
		}
		// Host 门在 bearer 之前：好 token + 坏 Host 仍 403。
		if st, code := platformC_raw(t, "GET", base+"/api/v1/health", auth, "evil.example.com"); st != 403 || code != "FORBIDDEN_BAD_HOST" {
			t.Fatalf("good token + bad Host must still 403 FORBIDDEN_BAD_HOST, got %d/%s", st, code)
		}
	})
}

// ── B-sup-10：WebSearch 真后端席 + webFetchMode 矩阵 ───────────────────────────

// TestContractPlatform_WebSearchBackendAndWebFetchMode:
// ① 未配搜索 backend：WebSearch 工具收敛为可操作引导文本（非错误、非空）。
// ② 配真搜索 backend（serper 形伪 server + default-search key）后：请求真达 backend
//   （X-API-KEY 携 key、q 携查询），结果以 {query,source:"serper",results[]} JSON 喂回模型。
// ③ webFetchMode PATCH 矩阵：local/jina 回显、白名单外 400 WORKSPACE_WEB_FETCH_MODE_INVALID。
//   （「读不到收敛 local」是 Service 内部兜底、无线缆面——见 rows note。）
func TestContractPlatform_WebSearchBackendAndWebFetchMode(t *testing.T) {
	wc, mock := chatSetup(t, false)
	wsID := wsOf(t, wc)

	// serper 形伪搜索后端。
	var mu sync.Mutex
	var gotKey, gotQuery string
	hits := 0
	fake := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/search" {
			http.NotFound(w, r)
			return
		}
		var body struct {
			Q   string `json:"q"`
			Num int    `json:"num"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		mu.Lock()
		gotKey, gotQuery = r.Header.Get("X-API-KEY"), body.Q
		hits++
		mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"organic":[{"title":"Contract Probe Result","link":"https://example.com/probe","snippet":"probe snippet body"}]}`))
	}))
	t.Cleanup(fake.Close)

	// ① 无搜索 backend：工具结果 = 引导文本。
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "WebSearch",
			Args: fw(map[string]any{"query": "noseat probe"})}}},
		harness.LLMTurn{Text: "guidance received"},
	)
	conv1 := convCreate(t, wc, "websearch no backend")
	msg1 := sendMsg(t, wc, conv1, "search something")
	if turn := waitTurn(t, wc, conv1, msg1, 30000); turn.Status != "completed" {
		t.Fatalf("no-backend WebSearch turn must complete, got %s err=%s", turn.Status, turn.ErrorMessage)
	}
	guidanceSeen := false
	for _, d := range mock.DumpsFor(dlgModel) {
		for _, m := range d.Messages {
			if m.Role == "tool" && strings.Contains(m.Content, "No search backend configured") {
				guidanceSeen = true
			}
		}
	}
	if !guidanceSeen {
		t.Fatal("without a search key the tool result must be the actionable guidance text")
	}

	// ② 配 serper key + default-search → 真达伪 backend、结果喂回模型。
	searchKey := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "serper", "displayName": "serper-fake", "key": "sk-serp-contract", "baseUrl": fake.URL,
	}).Field(t, "id")
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-search", map[string]any{"apiKeyId": searchKey}).OK(t, nil)

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "WebSearch",
			Args: fw(map[string]any{"query": "anselm contract probe"})}}},
		harness.LLMTurn{Text: "results received"},
	)
	conv2 := convCreate(t, wc, "websearch real backend")
	msg2 := sendMsg(t, wc, conv2, "search again")
	if turn := waitTurn(t, wc, conv2, msg2, 30000); turn.Status != "completed" {
		t.Fatalf("backend WebSearch turn must complete, got %s err=%s", turn.Status, turn.ErrorMessage)
	}
	mu.Lock()
	if hits < 1 || gotKey != "sk-serp-contract" || gotQuery != "anselm contract probe" {
		mu.Unlock()
		t.Fatalf("search backend must receive the real query with the BYOK key: hits=%d key=%q q=%q", hits, gotKey, gotQuery)
	}
	mu.Unlock()
	resultSeen := false
	for _, d := range mock.DumpsFor(dlgModel) {
		for _, m := range d.Messages {
			if m.Role == "tool" && strings.Contains(m.Content, "Contract Probe Result") &&
				strings.Contains(m.Content, `"source": "serper"`) {
				resultSeen = true
			}
		}
	}
	if !resultSeen {
		t.Fatal("backend results must be fed to the model as {query,source,results[]} JSON")
	}

	// ③ webFetchMode 矩阵。
	var ws struct {
		WebFetchMode string `json:"webFetchMode"`
	}
	wc.PATCH("/api/v1/workspaces/"+wsID, map[string]any{"webFetchMode": "jina"}).OK(t, &ws)
	if ws.WebFetchMode != "jina" {
		t.Fatalf("webFetchMode jina not echoed: %q", ws.WebFetchMode)
	}
	wc.PATCH("/api/v1/workspaces/"+wsID, map[string]any{"webFetchMode": "local"}).OK(t, &ws)
	if ws.WebFetchMode != "local" {
		t.Fatalf("webFetchMode local not echoed: %q", ws.WebFetchMode)
	}
	wc.Do("PATCH", "/api/v1/workspaces/"+wsID, map[string]any{"webFetchMode": "telepathy"}).
		Fail(t, 400, "WORKSPACE_WEB_FETCH_MODE_INVALID")
}
