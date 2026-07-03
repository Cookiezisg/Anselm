// contract_p4b_mcp_test.go — Phase 4b E1-mcp lane: MCP deep face at the AGENT + CHAT seats.
//
// The existing mcp_test.go / agent_test.go lock the HTTP :invoke lifecycle, the registry
// import/env-gate at the HTTP layer, and the three-kind agent mount. This file fills the
// LLM-seat vacuum with deterministic llmmock scripts (zero token):
//   - F141: an MCP server that goes OFFLINE after an agent already mounts it surfaces
//     MCP_SERVER_DOWN ("not connected") — NOT "tool not found on server" — on BOTH the
//     mount-health precheck and the invoke path; reconnect (PUT-replace back to a live
//     command) restores mount-health AND makes the tool callable end-to-end.
//   - namespace disambiguation: a function and an MCP tool sharing the bare name "echo"
//     never collide — the MCP tool lives in the mcp__<server>__<tool> namespace, is the
//     thing search_tools surfaces, and its call routes to the MCP server (not the function).
//   - F169 / registry install error faces reaching the chat LLM via install_mcp_server:
//     a missing REQUIRED env names the exact key in the tool result (Details survive), and
//     an unknown registry entry says "registry entry not found" — both without any install.
//
// contract_p4b_mcp_test.go —— Phase 4b E1-mcp 道：MCP 深面在 agent + chat 席。既有测锁了 HTTP
// :invoke 生命周期、registry 导入/env 门、三类 agent 挂载；本文件用确定性 llmmock（零 token）补
// LLM 席真空（F141 离线 server 报 server-down 非 tool-not-found + reconnect 恢复；mcp__ 命名空间
// 与同名 function 消歧；install_mcp_server 的 F169 缺必填 env 具名 + 未知条目 not-found 错误面）。
package scenarios

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// anyToolMsgContains reports whether any captured tool-role message (a tool result fed back to
// the model) contains sub — the model's-eye proof that a tool's output/error actually reached it.
//
// anyToolMsgContains 报告任一捕获的 tool-role 消息（回喂模型的工具结果）是否含 sub——模型视角
// 证明某工具的输出/错误真到了它眼前。
func anyToolMsgContains(dumps []harness.PromptDump, sub string) bool {
	for _, d := range dumps {
		for _, m := range d.Messages {
			if m.Role == "tool" && strings.Contains(m.Content, sub) {
				return true
			}
		}
	}
	return false
}

// TestP4bMcp_OfflineServerAgentSeatAndRecovery (E1-mcp-1): F141 at the agent seat. An MCP server
// that was READY when the agent mounted it, then goes OFFLINE (PUT-replaced with a dead command),
// must report MCP_SERVER_DOWN ("not connected") — NOT ErrToolNotFound's "not found on server" —
// on BOTH the mount-health precheck and the fail-fast invoke. The fix is to reconnect the server,
// not to hunt a renamed tool; reconnect (PUT-replaced back to the live command) restores
// mount-health AND makes mcp__recover__echo callable end-to-end with the agent-triggered ledger.
func TestP4bMcp_OfflineServerAgentSeatAndRecovery(t *testing.T) {
	wc, mock := agentSetup(t)
	script := writeScriptedMCP(t)
	deadArg := filepath.Join(t.TempDir(), "gone.py") // never written → python3 exits → connect fails

	// Phase 1 — server READY: mount resolves, agent creates cleanly, precheck is green.
	// 阶段 1——server 就绪：挂载可解析、agent 干净创建、预检绿。
	var st mcpStatus
	wc.PUT("/api/v1/mcp-servers/recover", map[string]any{
		"description": "offline-face probe", "command": "python3", "args": []string{script},
	}).OK(t, &st)
	if st.Status != "ready" || len(st.Tools) != 2 {
		t.Fatalf("phase1: recover must be ready with echo+boom, got %s tools=%d lastError=%q", st.Status, len(st.Tools), st.LastError)
	}
	agID := agCreate(t, wc, map[string]any{
		"name": "Recover Worker", "description": "calls a flaky mcp tool", "prompt": "Use your tool.",
		"tools": []map[string]any{{"ref": "mcp:recover/echo", "name": "recover echo"}},
	})
	assertMountHealth(t, wc, agID, true, "")

	// Phase 2 — server OFFLINE after the mount already exists (PUT-replace to a dead command).
	// The tool "echo" genuinely lives on this (now offline) server, so blaming "tool not found"
	// would misdirect the fix; F141 requires "not connected" on both faces.
	// 阶段 2——挂载已存在后 server 转离线（PUT 换成坏命令）。工具 echo 真在这台（现离线）server 上，
	// 怪「工具找不到」会引错修复方向；F141 要求两面都报「not connected」。
	wc.PUT("/api/v1/mcp-servers/recover", map[string]any{
		"command": "python3", "args": []string{deadArg},
	}).OK(t, &st)
	if st.Status != "failed" {
		t.Fatalf("phase2: dead command must leave recover failed, got %s lastError=%q", st.Status, st.LastError)
	}

	// mount-health precheck face.
	offErr := assertMountHealth(t, wc, agID, false, "mcp:recover/echo")
	if !strings.Contains(offErr, "not connected") {
		t.Fatalf("F141 mount-health: offline server must report 'not connected', got %q", offErr)
	}
	if strings.Contains(offErr, "not found on server") || strings.Contains(offErr, "tool not found") {
		// DEFECT: F141 regression — offline server misreported as a missing tool on the mount-health path.
		t.Fatalf("F141 mount-health regression: offline server misreported as tool-not-found, got %q", offErr)
	}

	// invoke face — fail-fast at mount resolution BEFORE the model is ever called (no scripted turn).
	// invoke 面——mount 解析处 fail-fast，模型从未被调（不需脚本 turn）。
	off := agInvoke(t, wc, agID, map[string]any{})
	if off.OK || off.Status != "failed" {
		t.Fatalf("F141 invoke: offline mount must fail the run, got %+v", off)
	}
	if !strings.Contains(off.ErrorMsg, "not connected") {
		t.Fatalf("F141 invoke: run error must say 'not connected', got %q", off.ErrorMsg)
	}
	if strings.Contains(off.ErrorMsg, "not found on server") || strings.Contains(off.ErrorMsg, "tool not found") {
		// DEFECT: F141 regression on the invoke path.
		t.Fatalf("F141 invoke regression: offline mount misreported as tool-not-found, got %q", off.ErrorMsg)
	}
	if n := len(mock.DumpsFor(agModel)); n != 0 {
		t.Fatalf("offline mount must fail-fast BEFORE the model is called, got %d requests", n)
	}

	// Phase 3 — RECONNECT via PUT-replace back to the live command: mount-health goes green and the
	// tool is callable end-to-end (agent-triggered ledger row).
	// 阶段 3——PUT 换回活命令即 reconnect：预检回绿、工具端到端可调（台账记 agent 触发）。
	wc.PUT("/api/v1/mcp-servers/recover", map[string]any{
		"command": "python3", "args": []string{script},
	}).OK(t, &st)
	if st.Status != "ready" {
		t.Fatalf("phase3: reconnect must restore ready, got %s lastError=%q", st.Status, st.LastError)
	}
	assertMountHealth(t, wc, agID, true, "")

	mock.Enqueue(agModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "mcp__recover__echo", Args: fw(map[string]any{"text": "revive"})}}},
		harness.LLMTurn{Text: "recovered"},
	)
	res := agInvoke(t, wc, agID, map[string]any{})
	if !res.OK || res.Status != "ok" {
		t.Fatalf("phase3: reconnected mount must invoke ok, got %+v", res)
	}
	if !anyToolMsgContains(mock.DumpsFor(agModel), "echo:revive") {
		t.Fatalf("phase3: mcp echo result must feed back to the agent, dumps=%d", len(mock.DumpsFor(agModel)))
	}
	var page mcpCallsPage
	wc.GET("/api/v1/mcp-servers/recover/calls").OK(t, &page)
	if len(page.Calls) != 1 || page.Calls[0].Tool != "echo" || page.Calls[0].Status != "ok" || page.Calls[0].TriggeredBy != "agent" {
		t.Fatalf("phase3: ledger must hold one agent-triggered ok echo call, got %+v", page.Calls)
	}
}

// assertMountHealth GETs /agents/{id}/mount-health, asserts allHealthy, and (when a ref is given)
// returns that mount's error string for the caller to inspect.
//
// assertMountHealth 拉 mount-health、断言 allHealthy，并（给了 ref 时）返回该挂载的 error 供调用方查。
func assertMountHealth(t *testing.T, wc *harness.Client, agID string, wantAllHealthy bool, ref string) string {
	t.Helper()
	var mh struct {
		Mounts []struct {
			Ref     string `json:"ref"`
			Healthy bool   `json:"healthy"`
			Error   string `json:"error"`
		} `json:"mounts"`
		AllHealthy bool `json:"allHealthy"`
	}
	wc.GET("/api/v1/agents/" + agID + "/mount-health").OK(t, &mh)
	if mh.AllHealthy != wantAllHealthy {
		t.Fatalf("mount-health allHealthy=%v want %v: %+v", mh.AllHealthy, wantAllHealthy, mh.Mounts)
	}
	if ref == "" {
		return ""
	}
	for _, m := range mh.Mounts {
		if m.Ref == ref {
			return m.Error
		}
	}
	t.Fatalf("mount-health missing ref %q: %+v", ref, mh.Mounts)
	return ""
}

// TestP4bMcp_ChatNamespaceDisambiguation (E1-mcp-3): a workspace function and an MCP tool both
// named "echo" coexist without collision. In chat the function is an ENTITY (run via run_function),
// never a bare "echo" tool; the MCP tool is the mcp__<server>__<tool> namespaced tool search_tools
// surfaces, and calling it routes to the MCP server (returns "echo:…", not the function's output).
func TestP4bMcp_ChatNamespaceDisambiguation(t *testing.T) {
	wc, mock := chatSetup(t, false)

	// A real function literally named "echo" — the collision the namespace must survive.
	// 一个真名为 "echo" 的 function——命名空间须扛住的撞名。
	fnID := fnCreate(t, wc, "echo",
		"def echo(text: str) -> dict:\n    return {\"src\": \"function-echo\", \"text\": text}\n")

	// A scripted MCP server whose "echo" tool returns "echo:<text>" (distinct from the function).
	// 脚本 MCP server，其 echo 工具返回 "echo:<text>"（与 function 判然不同）。
	wc.PUT("/api/v1/mcp-servers/nsmcp", map[string]any{
		"description": "namespace probe", "command": "python3", "args": []string{writeScriptedMCP(t)},
	}).OK(t, nil)

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "search_tools", Args: fw(map[string]any{"query": "echo"})}}},
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "mcp__nsmcp__echo", Args: fw(map[string]any{"text": "hi"})}}},
		harness.LLMTurn{Text: "done"},
	)
	convID := convCreate(t, wc, "namespace")
	mid := sendMsg(t, wc, convID, "echo hi via mcp")
	turn := waitTurn(t, wc, convID, mid, 30000)
	if turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s %s", turn.Status, turn.ErrorMessage)
	}

	dumps := mock.WaitDumps(t, dlgModel, 3, 10000)

	// The 2nd request is after search_tools ran: the discovered MCP tool is offered under its
	// NAMESPACED name, and no bare "echo" tool exists (the function is not a chat tool).
	// 第 2 个请求在 search_tools 跑后：discovered 的 MCP 工具以**命名空间**名 offer，且无裸 "echo"
	// 工具（function 不是 chat 工具）。
	if !hasTool(dumps[1].Tools, "mcp__nsmcp__echo") {
		t.Fatalf("namespaced mcp tool must be offered after discovery, got %v", dumps[1].Tools)
	}
	if hasTool(dumps[1].Tools, "echo") {
		t.Fatalf("a same-named function must NOT leak a bare 'echo' chat tool (namespace isolation), got %v", dumps[1].Tools)
	}
	// search_tools surfaced the namespaced name in its result (the catalog disambiguation face).
	// search_tools 的结果里浮出命名空间名（目录消歧面）。
	if !anyToolMsgContains(dumps, "mcp__nsmcp__echo") {
		t.Fatalf("search_tools result must surface mcp__nsmcp__echo")
	}
	// The mcp__nsmcp__echo call ROUTED to the MCP server (its "echo:hi" reached the model).
	// mcp__nsmcp__echo 的调用路由到了 MCP server（其 "echo:hi" 到了模型）。
	if !anyToolMsgContains(dumps, "echo:hi") {
		t.Fatalf("mcp echo result 'echo:hi' must feed back to the model")
	}

	// Ledger: the call went to the MCP server as a chat-triggered echo.
	// 台账：调用作为 chat 触发的 echo 落在 MCP server 上。
	var page mcpCallsPage
	wc.GET("/api/v1/mcp-servers/nsmcp/calls").OK(t, &page)
	if len(page.Calls) != 1 || page.Calls[0].Tool != "echo" || page.Calls[0].TriggeredBy != "chat" {
		t.Fatalf("mcp ledger must record one chat-triggered echo, got %+v", page.Calls)
	}

	// The same-named function is independently addressable and returns its OWN distinct output —
	// nothing about the MCP tool shadowed it.
	// 同名 function 独立可寻址、返回自己判然不同的输出——MCP 工具没遮蔽它。
	var run struct {
		OK     bool           `json:"ok"`
		Output map[string]any `json:"output"`
	}
	wc.POST("/api/v1/functions/"+fnID+":run", map[string]any{"args": map[string]any{"text": "z"}}).OK(t, &run)
	if !run.OK || run.Output["src"] != "function-echo" {
		t.Fatalf("function 'echo' must remain independently runnable with its own output, got %+v", run)
	}
}

// TestP4bMcp_ChatInstallErrorFaces (E1-mcp-2 + E1-mcp-4 deterministic slice): the two install_mcp_server
// error faces the chat LLM must see, without any actual install.
//   - F169: installing an env-gated registry entry (stripe: required header token STRIPE_API_KEY)
//     with no env names the EXACT missing required key in the tool result (Details survive Surface),
//     so the agent asks for the right key instead of "required environment variables missing" with
//     no clue which. The required-env NAME is pinned by the embedded catalog overlay (deterministic).
//   - an unknown registry name says "registry entry not found" (MCP_REGISTRY_NOT_FOUND) — resolved
//     from the local whitelist with no network at all.
//
// The successful registry search→install→invoke full chain (E1-mcp-4) needs a live GitHub registry
// fetch + a real runtime download and is exempt here (covered by TestMCP_OfficialFilesystemServer /
// TestMCP_ImportAndRegistry); the "install then immediately callable in one conversation" essence is
// covered deterministically by the discover-then-invoke path in TestP4bMcp_ChatNamespaceDisambiguation.
func TestP4bMcp_ChatInstallErrorFaces(t *testing.T) {
	wc, mock := chatSetup(t, false)

	mock.Enqueue(dlgModel,
		// env-gated entry, no env supplied → MCP_ENV_MISSING naming STRIPE_API_KEY.
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "install_mcp_server",
			Args: fw(map[string]any{"name": "com.stripe/mcp"})}}},
		// non-whitelisted slug → MCP_REGISTRY_NOT_FOUND (no network).
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "install_mcp_server",
			Args: fw(map[string]any{"name": "definitely/not-a-real-server"})}}},
		harness.LLMTurn{Text: "understood"},
	)
	convID := convCreate(t, wc, "install faces")
	mid := sendMsg(t, wc, convID, "install stripe and a bogus one")
	turn := waitTurn(t, wc, convID, mid, 30000)
	if turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s %s", turn.Status, turn.ErrorMessage)
	}

	dumps := mock.WaitDumps(t, dlgModel, 3, 15000)

	// F169: the exact missing REQUIRED key names itself to the model (Details survived into the tool text).
	// F169：缺的那个必填键把自己的名字报给模型（Details 穿进了工具文本）。
	if !anyToolMsgContains(dumps, "STRIPE_API_KEY") {
		t.Fatalf("F169: env-missing tool result must NAME the required key STRIPE_API_KEY")
	}
	if !anyToolMsgContains(dumps, "required environment variables missing") {
		t.Fatalf("F169: env-missing tool result must carry the MCP_ENV_MISSING message")
	}
	// Unknown registry entry → a clean not-found face (not a spurious env or connect error).
	// 未知条目 → 干净的 not-found 面（非虚假 env/连接错）。
	if !anyToolMsgContains(dumps, "registry entry not found") {
		t.Fatalf("unknown install must report 'registry entry not found' to the model")
	}

	// Neither attempt actually installed a server (env-gate + not-found both precede any install).
	// 两次尝试都没真装 server（env 门 + not-found 都先于任何安装）。
	wc.Do("GET", "/api/v1/mcp-servers/stripe", nil).Fail(t, 404, "MCP_SERVER_NOT_FOUND")
}
