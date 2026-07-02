// contract_support_test.go — 全量重测战役 Phase 1，support 批（mcp / search / relation /
// notification 域）的契约回归。逐行把「未探测」场景行变成零 token 黑盒断言：分页 cursor 往返、
// 未知字段严格拒、错误面 wire code、relation 只读守卫与 diff-sync 终态幂等、MCP 调用超时。
//
// 断言一律取自 docs/references/backend/domains/{mcp,search,relation,support-services}.md +
// api.md + error-codes.md；不符即缺陷（就地注释断言 + // DEFECT 标注，绝不改后端）。
// 时序一律 harness.Eventually（异步涟漪：搜索索引、通知落库、relation diff-sync）。
package scenarios

import (
	"encoding/json"
	"net/url"
	"os"
	"path/filepath"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// supportC_ws spins a fresh workspace-bound client on the given server.
//
// supportC_ws 在给定 server 上开一个绑定新 workspace 的客户端。
func supportC_ws(t *testing.T, srv *harness.Server, name string) *harness.Client {
	t.Helper()
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": name}).OK(t, nil)
	return c.WS(ws.Field(t, "id"))
}

// supportC_slowMCP is a dependency-free python MCP stdio server whose single tool sleeps
// well past any sane call timeout — used to force the per-call MCP timeout deterministically
// (we shrink the machine limit to 1s rather than wait the 180s default).
//
// supportC_slowMCP 是零依赖 python MCP stdio server，唯一工具 sleep 远超任何合理调用超时——
// 用来确定性触发 per-call MCP 超时（把机器上限压到 1s，而非真等 180s 默认）。
const supportC_slowMCP = `import sys, json, time

def send(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    msg = json.loads(line)
    method = msg.get("method")
    mid = msg.get("id")
    if method == "initialize":
        send({"jsonrpc": "2.0", "id": mid, "result": {
            "protocolVersion": msg["params"]["protocolVersion"],
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "slow", "version": "1.0.0"}}})
    elif method == "tools/list":
        send({"jsonrpc": "2.0", "id": mid, "result": {"tools": [
            {"name": "slowtool", "description": "sleeps forever-ish",
             "inputSchema": {"type": "object", "properties": {}}},
        ]}})
    elif method == "tools/call":
        time.sleep(6)
        send({"jsonrpc": "2.0", "id": mid, "result": {"content": [{"type": "text", "text": "late"}]}})
    elif mid is not None:
        send({"jsonrpc": "2.0", "id": mid, "result": {}})
`

// ───────────────────────── MCP ─────────────────────────

// TestContractSupport_MCPCallsAndPut covers:
//   - A-mcp-3: mcp calls cursor 往返（多调用翻页；registry 列表即全量无分页）。
//   - A-mcp-8: mcp PUT 拒未知字段（DisallowUnknownFields → INVALID_REQUEST）。
func TestContractSupport_MCPCallsAndPut(t *testing.T) {
	srv := harness.Start(t)
	wc := supportC_ws(t, srv, "csup-mcp")
	script := writeScriptedMCP(t)

	var st mcpStatus
	wc.PUT("/api/v1/mcp-servers/callsrv", map[string]any{
		"command": "python3", "args": []string{script},
	}).OK(t, &st)
	if st.Status != "ready" {
		t.Fatalf("scripted server must connect ready, got %s lastError=%q", st.Status, st.LastError)
	}

	// A-mcp-3: seed 5 ok calls, then walk the call log with limit=2 → 3 pages, distinct ids,
	// nextCursor present until the last page (N4 keyset). 播 5 次成功调用，limit=2 翻窗。
	const nCalls = 5
	for i := 0; i < nCalls; i++ {
		wc.POST("/api/v1/mcp-servers/callsrv/tools/echo:invoke", map[string]any{
			"args": map[string]any{"text": "hi"},
		}).OK(t, nil)
	}
	seen := map[string]bool{}
	cursor := ""
	pages := 0
	for {
		params := "?limit=2"
		if cursor != "" {
			params += "&cursor=" + url.QueryEscape(cursor)
		}
		r := wc.GET("/api/v1/mcp-servers/callsrv/calls" + params)
		var page mcpCallsPage
		r.OK(t, &page)
		if len(page.Calls) > 2 {
			t.Fatalf("limit=2 must cap page size, got %d", len(page.Calls))
		}
		for _, cRow := range page.Calls {
			if seen[cRow.ID] {
				t.Fatalf("duplicate call across pages: %s", cRow.ID)
			}
			seen[cRow.ID] = true
		}
		pages++
		if r.NextCursor == "" {
			break
		}
		cursor = r.NextCursor
		if pages > 5 {
			t.Fatal("calls pagination never terminates")
		}
	}
	if len(seen) != nCalls || pages != 3 {
		t.Fatalf("want %d calls over 3 pages, got %d over %d", nCalls, len(seen), pages)
	}

	// registry 列表即全量无分页：GET /mcp-registry 走 Success（非 Paged），故 envelope 顶层无
	// nextCursor。市场是实时 GitHub 拉取——仅在真 200 时断言（不让网络抖动毒到本 cursor 用例）。
	if reg := wc.GET("/api/v1/mcp-registry"); reg.Status == 200 {
		if reg.NextCursor != "" || reg.HasMore {
			t.Fatalf("registry list must be un-paginated (full set), got nextCursor=%q hasMore=%v", reg.NextCursor, reg.HasMore)
		}
		var entries []json.RawMessage
		reg.OK(t, &entries) // 顶层 data 是数组，非分页对象
	}

	// A-mcp-8: PUT with a junk field is rejected strictly BEFORE any domain work
	// (decodeJSON DisallowUnknownFields → INVALID_REQUEST 400). 未知字段严格拒。
	wc.Do("PUT", "/api/v1/mcp-servers/junksrv", map[string]any{
		"command": "python3", "args": []string{script}, "bogusUnknownField": 123,
	}).Fail(t, 400, "INVALID_REQUEST")
	// 且被拒的 server 未落库（严格拒发生在 AddServer 之前）。
	wc.Do("GET", "/api/v1/mcp-servers/junksrv", nil).Fail(t, 404, "MCP_SERVER_NOT_FOUND")
}

// TestContractSupport_MCPCallTimeout covers B-mcp-14: 默认 call 超时 180s。
// 180s 真等不可接受——按任务授权用 PATCH /limits 把机器级 timeout.mcpCallSec 压到 1s
// （schema min=1，见 pkg/limits.Schema），再调 sleep(6s) 工具，验证 per-call 墙钟超时按
// MCP_TOOL_TIMEOUT(504) 拒（calltool.go:47 用 limitspkg.Current().Timeout.MCPCallSec 封顶；
// client.go:263 把 DeadlineExceeded 映射成 ErrToolCallTimeout）。
func TestContractSupport_MCPCallTimeout(t *testing.T) {
	srv := harness.Start(t)
	wc := supportC_ws(t, srv, "csup-mcp-timeout")

	p := supportC_writeSlowMCP(t)

	// Connect first (handshake uses the connect timeout, NOT mcpCallSec) so shrinking
	// the call limit afterward can't starve the initialize/tools-list round-trip.
	// 先连（握手走连接超时、非 mcpCallSec），再压 call 上限，免得饿死 initialize/tools-list。
	var st mcpStatus
	wc.PUT("/api/v1/mcp-servers/slowsrv", map[string]any{
		"command": "python3", "args": []string{p},
	}).OK(t, &st)
	if st.Status != "ready" || len(st.Tools) != 1 {
		t.Fatalf("slow server must connect ready with 1 tool, got %s tools=%d lastError=%q", st.Status, len(st.Tools), st.LastError)
	}

	// Machine-level limit is global + hot-swapped; next CallTool reads the new bound.
	// limits 机器级全局 + 热换；下次 CallTool 即读新上限。
	wc.PATCH("/api/v1/limits", map[string]any{"timeout": map[string]any{"mcpCallSec": 1}}).OK(t, nil)

	// The tool sleeps 6s; the 1s call bound must fire → 504 MCP_TOOL_TIMEOUT.
	// 工具 sleep 6s；1s 调用上限先炸 → 504 MCP_TOOL_TIMEOUT。
	wc.Do("POST", "/api/v1/mcp-servers/slowsrv/tools/slowtool:invoke", map[string]any{}).
		Fail(t, 504, "MCP_TOOL_TIMEOUT")

	// The timed-out call lands in the ledger as status=timeout (calltool.go recordCall maps
	// DeadlineExceeded → CallStatusTimeout). 超时调用以 status=timeout 落台账。
	harness.Eventually(t, 15000, "timed-out call recorded as timeout", func() bool {
		var page mcpCallsPage
		wc.GET("/api/v1/mcp-servers/slowsrv/calls").OK(t, &page)
		for _, c := range page.Calls {
			if c.Status == "timeout" {
				return true
			}
		}
		return false
	})
}

// supportC_writeSlowMCP drops the slow MCP server into a temp file and returns its path.
//
// supportC_writeSlowMCP 把 slow MCP server 落进临时文件并返路径。
func supportC_writeSlowMCP(t *testing.T) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "slow_mcp.py")
	if err := os.WriteFile(p, []byte(supportC_slowMCP), 0o644); err != nil {
		t.Fatalf("write slow mcp: %v", err)
	}
	return p
}

// ───────────────────────── search ─────────────────────────

// TestContractSupport_SearchSettingsValidation covers A-srch-8: search PATCH settings 拒未知字段。
//
// B-srch-10（换 embedder 逐行记账重嵌 + fts_schema_version 不匹配 boot 重建）标 needs_unit：
// 两个子机制均为内部、无黑盒观测点也无 HTTP 触发面——
//   ① 逐行记账重嵌按 search_embeddings.model 列失效/补算（search.md §换 embedder），观测它需读
//      向量 BLOB 或让语义搜索命中变化，而后者要真嵌入引擎（builtin 600MB 下载 or ollama，二者
//      黑盒不可达；仅 TestSearch_SemanticRAGBuiltin 用真下载覆盖语义面）。换 embedder 的触发路径
//      本身（PATCH embedder 往返 + 词法搜存活）已由 TestSearch_ReindexAndSettings 覆盖。
//   ② fts_schema_version 不匹配 → boot 清空全量重建（search.md 关键不变量 #3），只在 schema 版本
//      常量 bump 时发生，须改后端常量（禁）或直改 SQLite search_meta（白盒、脆），无 HTTP 触发。
// 故 B-srch-10 归 needs_unit（属 app/infra search 单测面）。
func TestContractSupport_SearchSettingsValidation(t *testing.T) {
	srv := harness.Start(t)
	wc := supportC_ws(t, srv, "csup-search")

	// PATCH /search/settings 带杂字段 → decodeJSON DisallowUnknownFields → INVALID_REQUEST 400。
	wc.Do("PATCH", "/api/v1/search/settings", map[string]any{
		"embedder": "builtin", "bogusUnknownField": true,
	}).Fail(t, 400, "INVALID_REQUEST")

	// 合法子集仍照常（证明拒的是「未知字段」而非「有多字段」）。
	var s struct {
		Embedder string `json:"embedder"`
	}
	wc.PATCH("/api/v1/search/settings", map[string]any{"embedder": "builtin"}).OK(t, &s)
	if s.Embedder != "builtin" {
		t.Fatalf("known-field PATCH must succeed, got embedder=%q", s.Embedder)
	}
}

// ───────────────────────── notification ─────────────────────────

// TestContractSupport_Notifications covers:
//   - A-ntf-2: notification 错误面——未知 id mark-read → 404 NOTIFICATION_NOT_FOUND；
//     未知 action → 404 NOT_FOUND。
//   - A-ntf-3: notification 列表 cursor 往返（entity.created 涟漪播满，limit 翻窗）。
func TestContractSupport_Notifications(t *testing.T) {
	srv := harness.Start(t)
	wc := supportC_ws(t, srv, "csup-ntf")

	// 空 workspace 列表 = [] 非 null（N1；Paged emptySliceIfNil 保证）。
	if empty := wc.GET("/api/v1/notifications"); string(empty.Data) != "[]" {
		t.Fatalf("empty notification list must be [] not null, got %s", empty.Data)
	}

	// A-ntf-2: unknown id → NOTIFICATION_NOT_FOUND(404); unknown action → NOT_FOUND(404).
	wc.Do("POST", "/api/v1/notifications/noti_deadbeefdeadbeef:mark-read", nil).
		Fail(t, 404, "NOTIFICATION_NOT_FOUND")
	wc.Do("POST", "/api/v1/notifications/noti_deadbeefdeadbeef:bogusaction", nil).
		Fail(t, 404, "NOT_FOUND")

	// A-ntf-3: create N functions → N function.created notifications (async ripple). 播 N 条通知。
	const nNotif = 12
	for i := 0; i < nNotif; i++ {
		fnCreate(t, wc, "ntf_probe_"+itoa(i), "def f() -> dict:\n    return {}\n")
	}
	harness.Eventually(t, 20000, "all entity.created notifications land", func() bool {
		var uc struct {
			Unread int `json:"unread"`
		}
		wc.GET("/api/v1/notifications/unread-count").OK(t, &uc)
		return uc.Unread >= nNotif
	})

	// Walk newest-first with limit=5, keyset cursor; ids distinct, nextCursor terminates.
	// limit=5 最新优先翻窗；id 不重、nextCursor 收敛。
	seen := map[string]bool{}
	cursor := ""
	pages := 0
	for {
		params := "?limit=5"
		if cursor != "" {
			params += "&cursor=" + url.QueryEscape(cursor)
		}
		r := wc.GET("/api/v1/notifications" + params)
		var rows []struct {
			ID   string `json:"id"`
			Type string `json:"type"`
		}
		r.OK(t, &rows)
		if len(rows) > 5 {
			t.Fatalf("limit=5 must cap page size, got %d", len(rows))
		}
		for _, n := range rows {
			if seen[n.ID] {
				t.Fatalf("duplicate notification across pages: %s", n.ID)
			}
			seen[n.ID] = true
		}
		pages++
		if r.NextCursor == "" {
			break
		}
		cursor = r.NextCursor
		if pages > 12 {
			t.Fatal("notification pagination never terminates")
		}
	}
	if len(seen) < nNotif {
		t.Fatalf("cursor walk must cover >= %d notifications, got %d over %d pages", nNotif, len(seen), pages)
	}
	if pages < 3 {
		t.Fatalf("want >= 3 pages at limit=5 for %d notifications, got %d", nNotif, pages)
	}
}

// ───────────────────────── relation ─────────────────────────

// TestContractSupport_RelationReadFaces covers:
//   - A-rel-2: neighborhood 未知中心 id → 200 空图（[]），非错误（validateEntityRef 只校 kind+id 形状，
//     不校存在性；BFS 收集空集）。
//   - A-rel-4: relation N1——空图形状（relations 列表 [] 非 null；relgraph {nodes:[],edges:[]}）。
//   - B-rel-6: relation 只读守卫按 REL_* 码拒（depth 越界 / 坏 ref / 坏 edge kind / 半拉 filter）。
//     自环守卫（REL_SELF_LOOP）是 diff-sync 写侧守卫、无 HTTP 触发面 → needs_unit（见返回）。
func TestContractSupport_RelationReadFaces(t *testing.T) {
	srv := harness.Start(t)
	wc := supportC_ws(t, srv, "csup-rel-read")

	// A-rel-4: empty relgraph shape — nodes/edges are [] not null (make([],0) + emptySliceIfNil).
	var snap struct {
		Nodes []json.RawMessage `json:"nodes"`
		Edges []json.RawMessage `json:"edges"`
	}
	rg := wc.GET("/api/v1/relgraph")
	rg.OK(t, &snap)
	if snap.Nodes == nil || snap.Edges == nil {
		t.Fatalf("empty relgraph must carry [] nodes/edges (not null), got %s", rg.Data)
	}
	if len(snap.Nodes) != 0 || len(snap.Edges) != 0 {
		t.Fatalf("fresh workspace relgraph must be empty, got %d nodes %d edges", len(snap.Nodes), len(snap.Edges))
	}
	if listEmpty := wc.GET("/api/v1/relations"); string(listEmpty.Data) != "[]" {
		t.Fatalf("empty relations list must be [] not null, got %s", listEmpty.Data)
	}

	// A-rel-2: neighborhood of an unknown-but-well-formed center → 200 with empty [] (no error).
	nb := wc.GET("/api/v1/relations/neighborhood?kind=agent&id=ag_deadbeefdeadbeef&depth=1")
	nb.OK(t, nil)
	if string(nb.Data) != "[]" {
		t.Fatalf("unknown center neighborhood must be [] (200), got %d %s", nb.Status, nb.Data)
	}
	// depth 1..3 all valid on the same unknown center (200 []). depth 1-3 全合法。
	for _, d := range []string{"1", "2", "3"} {
		r := wc.GET("/api/v1/relations/neighborhood?kind=agent&id=ag_deadbeefdeadbeef&depth=" + d)
		if r.Status != 200 {
			t.Fatalf("depth=%s must be accepted (1..3), got %d %s", d, r.Status, r.Raw)
		}
	}

	// B-rel-6 read-side guards:
	// depth out of [1,3] → REL_DEPTH_LIMIT.
	wc.Do("GET", "/api/v1/relations/neighborhood?kind=agent&id=ag_x&depth=0", nil).
		Fail(t, 400, "REL_DEPTH_LIMIT")
	wc.Do("GET", "/api/v1/relations/neighborhood?kind=agent&id=ag_x&depth=4", nil).
		Fail(t, 400, "REL_DEPTH_LIMIT")
	// unknown entity kind → REL_INVALID_REF.
	wc.Do("GET", "/api/v1/relations/neighborhood?kind=spaceship&id=x&depth=1", nil).
		Fail(t, 400, "REL_INVALID_REF")
	// empty id → REL_INVALID_REF.
	wc.Do("GET", "/api/v1/relations/neighborhood?kind=agent&id=&depth=1", nil).
		Fail(t, 400, "REL_INVALID_REF")
	// List filter: kind without id → REL_INCOMPLETE_FILTER.
	wc.Do("GET", "/api/v1/relations?fromKind=agent", nil).
		Fail(t, 400, "REL_INCOMPLETE_FILTER")
	// List filter: bad entity kind → REL_INVALID_REF.
	wc.Do("GET", "/api/v1/relations?fromKind=spaceship&fromId=x", nil).
		Fail(t, 400, "REL_INVALID_REF")
	// List filter: bad EDGE kind (not one of create/edit/equip/link) → REL_INVALID_KIND.
	wc.Do("GET", "/api/v1/relations?kind=bogusverb", nil).
		Fail(t, 400, "REL_INVALID_KIND")
}

// TestContractSupport_RelationListAndDiffSync covers:
//   - A-rel-3: relation list cursor 往返（agent 挂 N function → N 条 equip 出边，limit 翻窗）。
//   - B-rel-2: diff-sync 终态幂等——edit 换挂载后旧边消失、同集重 edit 不增边（边 id 稳定）。
func TestContractSupport_RelationListAndDiffSync(t *testing.T) {
	srv := harness.Start(t)
	wc := supportC_ws(t, srv, "csup-rel-sync")

	// --- A-rel-3: 6 equip edges from one agent → 3 pages at limit=2 ---
	const nTools = 6
	tools := make([]map[string]any, 0, nTools)
	for i := 0; i < nTools; i++ {
		fnID := fnCreate(t, wc, "relpg_fn_"+itoa(i), "def f() -> dict:\n    return {}\n")
		tools = append(tools, map[string]any{"ref": fnID, "name": "t" + itoa(i)})
	}
	agID := agCreate(t, wc, map[string]any{
		"name": "Rel Pager", "description": "d", "prompt": "p", "tools": tools,
	})

	// equip diff-sync is best-effort/async → poll until all 6 outgoing edges exist. 轮询等 6 条出边。
	harness.Eventually(t, 20000, "agent equip edges all synced", func() bool {
		return len(relEdges(t, wc, agID)) == nTools
	})

	seen := map[string]bool{}
	cursor := ""
	pages := 0
	for {
		params := "?fromKind=agent&fromId=" + url.QueryEscape(agID) + "&limit=2"
		if cursor != "" {
			params += "&cursor=" + url.QueryEscape(cursor)
		}
		r := wc.GET("/api/v1/relations" + params)
		var rows []struct {
			ID   string `json:"id"`
			Kind string `json:"kind"`
		}
		r.OK(t, &rows)
		if len(rows) > 2 {
			t.Fatalf("limit=2 must cap page size, got %d", len(rows))
		}
		for _, e := range rows {
			if seen[e.ID] {
				t.Fatalf("duplicate relation across pages: %s", e.ID)
			}
			seen[e.ID] = true
		}
		pages++
		if r.NextCursor == "" {
			break
		}
		cursor = r.NextCursor
		if pages > 6 {
			t.Fatal("relation pagination never terminates")
		}
	}
	if len(seen) != nTools || pages != 3 {
		t.Fatalf("want %d equip edges over 3 pages, got %d over %d", nTools, len(seen), pages)
	}

	// --- B-rel-2: diff-sync terminal idempotence ---
	fnA := fnCreate(t, wc, "diffsync_a", "def f() -> dict:\n    return {}\n")
	fnB := fnCreate(t, wc, "diffsync_b", "def f() -> dict:\n    return {}\n")
	agD := agCreate(t, wc, map[string]any{
		"name": "DiffSync", "description": "d", "prompt": "p",
		"tools": []map[string]any{{"ref": fnA, "name": "a"}},
	})
	// mount fnA → exactly one equip edge agent→fnA.
	harness.Eventually(t, 20000, "initial mount edge to fnA", func() bool {
		e := relEdges(t, wc, agD)
		return len(e) == 1 && e[0].ToID == fnA
	})

	// edit to mount fnB instead → old edge to fnA vanishes, new edge to fnB appears
	// (SyncOutgoing diff-sync deletes vanished edges — the terminal set is exactly {fnB}).
	// edit 换挂 fnB → 旧 fnA 边消失、新 fnB 边出现（终态恰 {fnB}）。
	wc.POST("/api/v1/agents/"+agD+":edit", map[string]any{
		"prompt": "p", "tools": []map[string]any{{"ref": fnB, "name": "b"}},
	}).OK(t, nil)
	var edgeIDafterB string
	harness.Eventually(t, 20000, "diff-sync swaps edge to fnB, drops fnA", func() bool {
		e := relEdges(t, wc, agD)
		if len(e) != 1 || e[0].ToID != fnB {
			return false
		}
		edgeIDafterB = e[0].ID
		return true
	})

	// re-edit with the SAME terminal set {fnB} → idempotent: still exactly one edge, same id
	// (diff-sync keeps the matching edge, no insert/delete/churn).
	// 同集重 edit → 幂等：仍恰一条边、同 id（diff-sync 保留匹配边，不增删不搅动）。
	wc.POST("/api/v1/agents/"+agD+":edit", map[string]any{
		"prompt": "p", "tools": []map[string]any{{"ref": fnB, "name": "b"}},
	}).OK(t, nil)
	// give the async sync a beat, then assert stability holds (never flips to >1 or a new id).
	harness.Eventually(t, 10000, "idempotent re-edit keeps one stable edge", func() bool {
		e := relEdges(t, wc, agD)
		return len(e) == 1 && e[0].ToID == fnB && e[0].ID == edgeIDafterB
	})
	// and fnA edge stays gone.
	if e := relEdges(t, wc, agD); len(e) != 1 || e[0].ToID != fnB {
		t.Fatalf("terminal edge set must be exactly {fnB}, got %+v", e)
	}
}

// relEdge is the slim view of an agent's outgoing relation edge.
//
// relEdge 是 agent 出边的精简视图。
type relEdge struct {
	ID   string `json:"id"`
	Kind string `json:"kind"`
	ToID string `json:"toId"`
}

// relEdges lists an agent's outgoing edges (fromKind=agent&fromId=agID), draining all pages.
//
// relEdges 列一个 agent 的全部出边（翻完所有分页）。
func relEdges(t *testing.T, wc *harness.Client, agID string) []relEdge {
	t.Helper()
	var out []relEdge
	cursor := ""
	for i := 0; i < 20; i++ {
		params := "?fromKind=agent&fromId=" + url.QueryEscape(agID) + "&limit=50"
		if cursor != "" {
			params += "&cursor=" + url.QueryEscape(cursor)
		}
		r := wc.GET("/api/v1/relations" + params)
		var rows []relEdge
		r.OK(t, &rows)
		out = append(out, rows...)
		if r.NextCursor == "" {
			break
		}
		cursor = r.NextCursor
	}
	return out
}

// itoa is a tiny int→string without importing strconv into a test-only helper file.
//
// itoa 是不引 strconv 的小 int→string。
func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var buf [20]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	return string(buf[i:])
}
