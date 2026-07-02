// contract_chat_test.go — Phase 1 契约全扫 p1_chat 批次（COVERAGE 未探格逐行落测）。
//
// 覆盖：A-conv-8 / A-chat-8（未知字段 + interactions action 枚举）、A-todo-2/4 + A-tp-4/5 +
// B-tp-9（空看板形状 + 未知对话空页 + 跨 ws 隔离）、B-chat-3（收尾窗单槽缓冲）、B-chat-6（优雅
// 停机即时）、B-chat-8（LoadHistory 排除 subagent trace）、B-chat-10 + B-msg-7（kill -9 孤儿清扫）、
// B-chat-14（approve_always 生命周期）、B-msg-1（progress 一等持久块）、B-msg-3/5（append-only +
// 压缩不改写原文，直查 SQLite）、B-conv-1（ModelOverride 三态）、B-conv-5（activity 键稳定 +
// garbage sort）、B-conv-6（search 转义 + 异构游标）、B-conv-7（isGenerating 派生）、B-sub-4/5/6
// （subagent 白名单/轮上限/取消落终态/模型不承袭 override）、B-todo-3/5/6/7（reminder 抑制 +
// 独立作用域 + 64 上限 + 流信号）、B-tp-6/7/8（TouchEntity 自报 + subagent actor + 借名快照）。
// 断言 = docs/references/backend/ 契约文档；与行建议不符处以文档为准（见各测试注释）。
package scenarios

import (
	"encoding/json"
	"fmt"
	"net/url"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// chatC_setup 是 chatSetup 的加宽版：额外返回 Server（Kill9/Restart/DataDir 场景）、wsID、keyID
// （modelOverride / default-models 需要引用真实 key）。
func chatC_setup(t *testing.T, withUtility bool) (*harness.Server, *harness.Client, *harness.LLMMock, string, string) {
	t.Helper()
	srv := harness.Start(t)
	mock := harness.NewLLMMock(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "contract-chat-ws"}).Field(t, "id")
	wc := c.WS(wsID)
	keyID := wc.POST("/api/v1/api-keys", map[string]any{
		"provider": "openai", "displayName": "llmmock", "key": "sk-mock", "baseUrl": mock.URL(),
	}).Field(t, "id")
	wc.POST("/api/v1/api-keys/"+keyID+":test", nil).OK(t, nil)
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/dialogue",
		map[string]any{"apiKeyId": keyID, "modelId": dlgModel}).OK(t, nil)
	if withUtility {
		wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/utility",
			map[string]any{"apiKeyId": keyID, "modelId": utilModel}).OK(t, nil)
	}
	return srv, wc, mock, wsID, keyID
}

// chatC_sqlite 用系统 sqlite3 CLI 直查落盘真相（append-only / 原文不可变这类断言只有物理行能证明；
// WAL 模式下并发只读安全）。
func chatC_sqlite(t *testing.T, dataDir, query string) string {
	t.Helper()
	out, err := exec.Command("sqlite3", "-readonly", dataDir+"/anselm.db", query).CombinedOutput()
	if err != nil {
		t.Fatalf("sqlite3 %q: %v\n%s", query, err, out)
	}
	return strings.TrimRight(string(out), "\n")
}

// chatC_pidOnPort 用 lsof 找监听该端口的 backend 进程（harness 不暴露 cmd——优雅停机场景在
// 黑盒边界上只能按端口定位进程）。
// chatC_processExited reports whether pid has terminated — treating a ZOMBIE (defunct) as exited.
// The harness only reaps the backend at t.Cleanup, so a promptly-exited backend lingers as a
// zombie whose pid entry still exists; syscall.Kill(pid,0) returns nil for it (would falsely read
// as "alive"). So "exited" = the pid is gone OR its process state is Z.
//
// chatC_processExited 判 pid 是否已终止——把**僵尸**(defunct)视为已退出。harness 只在 t.Cleanup 回收
// 后端,故迅速退出的后端会滞留为僵尸(pid 表项仍在),syscall.Kill(pid,0) 对它返 nil(会被误读为「存活」)。
// 故「已退出」= pid 不存在 或 进程状态为 Z。
func chatC_processExited(pid int) bool {
	if syscall.Kill(pid, syscall.Signal(0)) != nil {
		return true // pid gone
	}
	out, err := exec.Command("ps", "-o", "stat=", "-p", strconv.Itoa(pid)).Output()
	return err == nil && strings.HasPrefix(strings.TrimSpace(string(out)), "Z")
}

func chatC_pidOnPort(t *testing.T, baseURL string) int {
	t.Helper()
	port := baseURL[strings.LastIndex(baseURL, ":")+1:]
	out, err := exec.Command("lsof", "-nP", "-t", "-iTCP:"+port, "-sTCP:LISTEN").Output()
	if err != nil {
		t.Fatalf("lsof port %s: %v", port, err)
	}
	pid, err := strconv.Atoi(strings.TrimSpace(strings.Split(strings.TrimSpace(string(out)), "\n")[0]))
	if err != nil {
		t.Fatalf("lsof output not a pid: %q", out)
	}
	return pid
}

// chatC_subDumps 过滤发给 dialogue 队列、system prompt 含给定标记的请求（= 某类型 subagent 的
// 模型视角请求；subagent 恒跑 workspace dialogue 模型）。
func chatC_subDumps(mock *harness.LLMMock, marker string) []harness.PromptDump {
	var out []harness.PromptDump
	for _, d := range mock.DumpsFor(dlgModel) {
		if strings.Contains(d.System, marker) {
			out = append(out, d)
		}
	}
	return out
}

// chatC_idxOf 返回对话在列表里的下标（-1 = 不在）——相对序断言对同服务器其他测试段落免疫。
func chatC_idxOf(rows []convRow, id string) int {
	for i, r := range rows {
		if r.ID == id {
			return i
		}
	}
	return -1
}

// chatC_dangerCall 构造一次自报 dangerous 的 run_function 调用。
func chatC_dangerCall(id, fnID string) harness.MockToolCall {
	return harness.MockToolCall{ID: id, Name: "run_function", Args: map[string]any{
		"functionId": fnID, "args": map[string]any{},
		"summary": "run the gated probe", "danger": "dangerous", "execution_group": 1,
	}}
}

// TestContractChat_UnknownFieldsAndActionEnum:
// A-chat-8 —— Send / interactions resolve 的未知字段被严格解码拒绝（decode.go DisallowUnknownFields
// → 400 INVALID_REQUEST，error-codes.md L54）；action 枚举（api.md：approve|approve_always|deny|
// accept|decline）外的值按契约应被拒。
// A-conv-8 —— conversation PATCH 同理拒未知字段（custom UnmarshalJSON 现保持 DisallowUnknownFields）。
// 两处已同批修复：conversation/limits PATCH 转严格解码；interactions resolve 校验 action 枚举
// （枚举外 → 422 INTERACTION_INVALID_ACTION，不再静默当 deny）。
func TestContractChat_UnknownFieldsAndActionEnum(t *testing.T) {
	wc, mock := chatSetup(t, false)
	convID := convCreate(t, wc, "strict decode")

	// Send 带杂字段 → 400 INVALID_REQUEST（严格解码契约的正控）。
	wc.Do("POST", "/api/v1/conversations/"+convID+"/messages",
		map[string]any{"content": "hi", "bogusField": 1}).Fail(t, 400, "INVALID_REQUEST")
	// interactions resolve 带杂字段 → 同样 400。
	wc.Do("POST", "/api/v1/conversations/"+convID+"/interactions/call_x",
		map[string]any{"action": "approve", "bogusField": true}).Fail(t, 400, "INVALID_REQUEST")
	// 对话 Create 带杂字段 → 400（同一 decodeJSON 路径的资源内正控）。
	wc.Do("POST", "/api/v1/conversations",
		map[string]any{"title": "x", "bogusField": "y"}).Fail(t, 400, "INVALID_REQUEST")

	// A-conv-8：PATCH 带杂字段 → 400 INVALID_REQUEST。custom UnmarshalJSON 现保持严格
	// （DisallowUnknownFields），与其余 PATCH 一致——拼错字段不再静默 no-op。
	wc.Do("PATCH", "/api/v1/conversations/"+convID, map[string]any{"bogusField": 123}).
		Fail(t, 400, "INVALID_REQUEST")

	// action 枚举外值 → 422 INTERACTION_INVALID_ACTION（validate-input-before-lookup:请求本身畸形,
	// 先于 broker 查找就拒;garbage action 无论有无待决交互都 422，不再静默按 deny 解读）。
	wc.Do("POST", "/api/v1/conversations/"+convID+"/interactions/call_none",
		map[string]any{"action": "whatever"}).Fail(t, 422, "INTERACTION_INVALID_ACTION")

	// action 枚举外值 + 有待决 danger 交互：契约枚举 5 动作，枚举外应被拒；实测 204 且被当 deny
	// 静默解读（loop 危险门只认 approve/approve_always、其余一律走拒绝路）——用户 typo 会被无声
	// 当成拒绝且模型被告知「用户拒绝」。
	fnID := fnCreate(t, wc, "enum_probe", "def go() -> dict:\n    return {\"ok\": True}\n")
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{chatC_dangerCall("call_enum", fnID)}},
		harness.LLMTurn{Text: "acknowledged"},
	)
	conv2 := convCreate(t, wc, "enum probe")
	mid := sendMsg(t, wc, conv2, "do the gated thing")
	var pending []struct {
		ToolCallID string `json:"toolCallId"`
	}
	harness.Eventually(t, 15000, "danger interaction pends", func() bool {
		pending = nil
		wc.GET("/api/v1/conversations/"+conv2+"/interactions").OK(t, &pending)
		return len(pending) == 1
	})
	// 枚举外 action 于**有待决** danger 交互 → 422 INTERACTION_INVALID_ACTION，且交互仍挂着（未被
	// 静默当 deny 消费）——用户 typo 不再无声拒掉一个危险工具。
	wc.Do("POST", "/api/v1/conversations/"+conv2+"/interactions/"+pending[0].ToolCallID,
		map[string]any{"action": "whatever"}).Fail(t, 422, "INTERACTION_INVALID_ACTION")

	// 收尾：garbage 被拒后交互仍挂着，显式 deny 放行——回合以 deny 收尾、工具不跑。断言不变量。
	_, _ = wc.Try("POST", "/api/v1/conversations/"+conv2+"/interactions/"+pending[0].ToolCallID,
		map[string]any{"action": "deny"})
	if turn := waitTurn(t, wc, conv2, mid, 20000); turn.Status != "completed" {
		t.Fatalf("denied turn must still complete, got %s", turn.Status)
	}
	var page struct {
		Aggregates struct {
			OKCount int `json:"okCount"`
		} `json:"aggregates"`
	}
	wc.GET("/api/v1/functions/"+fnID+"/executions").OK(t, &page)
	if page.Aggregates.OKCount != 0 {
		t.Fatalf("a non-approve action must never run the tool, executions=%+v", page.Aggregates)
	}
}

// TestContractChat_EmptyBoardsAndCrossWorkspace:
// A-todo-4 —— 零 todo 的看板返 `todos: []`（非 null，todo.md + N1）。
// A-todo-2 —— 未知 conversationId 的 todos 返 200 空页（touchpoint.md：「未知对话返回空页（同
// todos——无台账非错误）」；行建议的 404 与契约不符，以文档为准）。
// A-tp-4 —— 新对话零触点返 data []（非 null）。
// B-tp-9 —— 未知对话 GET touchpoints 返 200 空页非错。
// A-tp-5 —— 跨 workspace 读：D2 隔离下对话不可见——GET 对话 404；touchpoints/todos 端点按「未知
// 对话=空页」契约返 200 空且绝不泄漏他 ws 的行（行建议的 404 与该端点契约不符）。
func TestContractChat_EmptyBoardsAndCrossWorkspace(t *testing.T) {
	srv, wc, _, _, _ := chatC_setup(t, false)
	convID := convCreate(t, wc, "empty boards")

	assertEmptyTodos := func(id string) {
		t.Helper()
		resp := wc.GET("/api/v1/conversations/" + id + "/todos")
		var m map[string]json.RawMessage
		resp.OK(t, &m)
		if string(m["todos"]) != "[]" {
			t.Fatalf("todos of %s must be [] (not null/missing), got %s", id, resp.Data)
		}
	}
	assertEmptyTodos(convID)                 // A-todo-4
	assertEmptyTodos("cv_0000000000000000") // A-todo-2（契约=空页非 404）

	if r := wc.GET("/api/v1/conversations/" + convID + "/touchpoints"); string(r.Data) != "[]" {
		t.Fatalf("fresh conversation ledger must be [], got %s", r.Data) // A-tp-4
	}
	if r := wc.GET("/api/v1/conversations/cv_0000000000000000/touchpoints"); r.Status != 200 || string(r.Data) != "[]" {
		t.Fatalf("unknown conversation ledger must be a 200 empty page, got %d %s", r.Status, r.Raw) // B-tp-9
	}

	// 在 ws1 给对话记一笔真实触点（附件 → attached 行），作为跨 ws 不泄漏断言的前提。
	attID := uploadAtt(t, wc, "iso.txt", "text/plain", []byte("isolation payload"))
	mid := sendWith(t, wc, convID, map[string]any{"content": "hold this", "attachmentIds": []string{attID}})
	if turn := waitTurn(t, wc, convID, mid, 30000); turn.Status != "completed" {
		t.Fatalf("attachment turn must complete, got %s %s", turn.Status, turn.ErrorMessage)
	}
	harness.Eventually(t, 10000, "attached touchpoint lands in ws1", func() bool {
		return findRow(listTouchpoints(t, wc, convID, ""), "attached", attID) != nil
	})

	// 第二个 workspace 看同一对话：对话本体 404（D2），台账/看板端点空页且零行泄漏。
	ws2 := srv.Client(t).POST("/api/v1/workspaces", map[string]any{"name": "other-ws"}).Field(t, "id")
	wc2 := srv.Client(t).WS(ws2)
	wc2.Do("GET", "/api/v1/conversations/"+convID, nil).Fail(t, 404, "CONVERSATION_NOT_FOUND")
	if r := wc2.GET("/api/v1/conversations/" + convID + "/touchpoints"); r.Status != 200 || string(r.Data) != "[]" {
		t.Fatalf("cross-ws ledger read must be a 200 empty page (no leak), got %d %s", r.Status, r.Raw) // A-tp-5
	}
	var m map[string]json.RawMessage
	wc2.GET("/api/v1/conversations/" + convID + "/todos").OK(t, &m)
	if string(m["todos"]) != "[]" {
		t.Fatalf("cross-ws todos read must be empty, got %s", m["todos"])
	}
}

// TestContractChat_ModelOverrideTristateAndActivityOrder:
// B-conv-1 —— PATCH ModelOverride 指针三态（conversation.md：缺=不变 / null=清除 / 对象=设置）+
// 写时校验（部分对象 422 CONVERSATION_INVALID_MODEL_OVERRIDE；不存在 key 404 API_KEY_NOT_FOUND）。
// B-conv-5 —— activity 排序键 last_message_at 只随用户回合刷新：改名/systemPrompt/换模型不重排；
// 未知/空 sort 静默落 activity 不 400。
func TestContractChat_ModelOverrideTristateAndActivityOrder(t *testing.T) {
	_, wc, _, _, keyID := chatC_setup(t, false)

	// --- B-conv-1: 三态矩阵 ---
	convID := convCreate(t, wc, "tristate")
	type convDetail struct {
		Title         string `json:"title"`
		ModelOverride *struct {
			APIKeyID string `json:"apiKeyId"`
			ModelID  string `json:"modelId"`
		} `json:"modelOverride"`
	}
	var d convDetail

	// 对象 = 设置。d 每次 GET 前重置——一个 nil override 在响应里被 omitempty 省略，复用旧 d
	// 会让上次的非 nil 指针残留（json.Unmarshal 不碰缺席字段），把「已清除」误读成「未清除」。
	d = convDetail{}
	wc.PATCH("/api/v1/conversations/"+convID,
		map[string]any{"modelOverride": map[string]any{"apiKeyId": keyID, "modelId": dlgModel}}).OK(t, nil)
	wc.GET("/api/v1/conversations/" + convID).OK(t, &d)
	if d.ModelOverride == nil || d.ModelOverride.APIKeyID != keyID || d.ModelOverride.ModelID != dlgModel {
		t.Fatalf("set must persist the override, got %+v", d.ModelOverride)
	}
	// 缺 = 不变（PATCH 只动 title）。
	d = convDetail{}
	wc.PATCH("/api/v1/conversations/"+convID, map[string]any{"title": "renamed tristate"}).OK(t, nil)
	wc.GET("/api/v1/conversations/" + convID).OK(t, &d)
	if d.Title != "renamed tristate" || d.ModelOverride == nil || d.ModelOverride.ModelID != dlgModel {
		t.Fatalf("absent key must leave the override untouched, got title=%q override=%+v", d.Title, d.ModelOverride)
	}
	// null = 清除。
	d = convDetail{}
	wc.PATCH("/api/v1/conversations/"+convID, map[string]any{"modelOverride": nil}).OK(t, nil)
	wc.GET("/api/v1/conversations/" + convID).OK(t, &d)
	if d.ModelOverride != nil {
		t.Fatalf("explicit null must clear the override, got %+v", d.ModelOverride)
	}
	// 写时校验：部分对象（缺 modelId）→ 422；引用不存在 key → 404 API_KEY_NOT_FOUND（F153）。
	wc.Do("PATCH", "/api/v1/conversations/"+convID,
		map[string]any{"modelOverride": map[string]any{"apiKeyId": keyID}}).
		Fail(t, 422, "CONVERSATION_INVALID_MODEL_OVERRIDE")
	wc.Do("PATCH", "/api/v1/conversations/"+convID,
		map[string]any{"modelOverride": map[string]any{"apiKeyId": "aki_0000000000000000", "modelId": "x"}}).
		Fail(t, 404, "API_KEY_NOT_FOUND")

	// --- B-conv-5: activity 键稳定性 ---
	convA := convCreate(t, wc, "act alpha")
	convB := convCreate(t, wc, "act beta")
	// 给 A 发一个用户回合 → last_message_at 刷新 → A 必须排在 B 前。
	waitTurn(t, wc, convA, sendMsg(t, wc, convA, "bump A"), 30000)
	harness.Eventually(t, 10000, "A rises above B after a user turn", func() bool {
		rows := listConvs(t, wc)
		return chatC_idxOf(rows, convA) >= 0 && chatC_idxOf(rows, convA) < chatC_idxOf(rows, convB)
	})
	// 元数据 PATCH（改名 + systemPrompt + 换模型）不得重排。
	wc.PATCH("/api/v1/conversations/"+convB, map[string]any{
		"title": "act beta renamed", "systemPrompt": "be brief",
		"modelOverride": map[string]any{"apiKeyId": keyID, "modelId": dlgModel},
	}).OK(t, nil)
	rows := listConvs(t, wc)
	if !(chatC_idxOf(rows, convA) < chatC_idxOf(rows, convB)) {
		t.Fatalf("metadata PATCH must not reorder the activity list: A@%d B@%d",
			chatC_idxOf(rows, convA), chatC_idxOf(rows, convB))
	}
	// 未知 / 空 sort 静默落 activity（不 400、同序）。
	for _, q := range []string{"?sort=garbage&limit=50", "?sort=&limit=50"} {
		var got []convRow
		r := wc.Do("GET", "/api/v1/conversations"+q, nil)
		if r.Status != 200 {
			t.Fatalf("unknown/blank sort must fall back to activity (200), got %d on %s", r.Status, q)
		}
		r.OK(t, &got)
		if !(chatC_idxOf(got, convA) < chatC_idxOf(got, convB)) {
			t.Fatalf("fallback sort must keep the activity order on %s", q)
		}
	}
	// 用户回合刷新 B → B 上浮（正控收尾）。
	waitTurn(t, wc, convB, sendMsg(t, wc, convB, "bump B"), 30000)
	harness.Eventually(t, 10000, "B rises after its own user turn", func() bool {
		rows := listConvs(t, wc)
		return chatC_idxOf(rows, convB) < chatC_idxOf(rows, convA)
	})
}

// TestContractChat_SearchEscapeAndStaleCursor: B-conv-6 —— ?search= 对 title 大小写不敏感子串、
// %/_ 通配转义（orm WhereLike，conversation.md）、不改排序键；跨 sort / 跨 search 复用旧游标
// 不 500（契约只要求客户端丢弃游标，服务端不得炸）。
func TestContractChat_SearchEscapeAndStaleCursor(t *testing.T) {
	wc, _ := chatSetup(t, false)

	qa1 := convCreate(t, wc, "Query Alpha One")
	qa2 := convCreate(t, wc, "query alpha two")
	pctLit := convCreate(t, wc, "promo 50% off")
	pctTrap := convCreate(t, wc, "promo 50x off")
	usLit := convCreate(t, wc, "score under_score")
	usTrap := convCreate(t, wc, "score under-score")

	search := func(term string) []convRow {
		t.Helper()
		var rows []convRow
		wc.GET("/api/v1/conversations?limit=50&search=" + url.QueryEscape(term)).OK(t, &rows)
		return rows
	}
	// 大小写不敏感子串：大写 term 命中两条小写/混写标题。
	got := search("ALPHA")
	if len(got) != 2 || chatC_idxOf(got, qa1) < 0 || chatC_idxOf(got, qa2) < 0 {
		t.Fatalf("search=ALPHA must match exactly the two alpha rows, got %+v", got)
	}
	// % 转义：字面 "50%" 只命中真含百分号的行；若 % 未转义为通配，陷阱行 "50x off" 也会中。
	got = search("50%")
	if len(got) != 1 || got[0].ID != pctLit {
		t.Fatalf("search=50%% must be a literal match (escape %%), got %+v (trap=%s)", got, pctTrap)
	}
	// _ 转义：字面 "under_s" 只命中下划线行；若 _ 未转义为单字符通配，"under-score" 也会中。
	got = search("under_s")
	if len(got) != 1 || got[0].ID != usLit {
		t.Fatalf("search=under_s must be a literal match (escape _), got %+v (trap=%s)", got, usTrap)
	}
	// 空 term = 不过滤。
	if got = search(""); len(got) != 6 {
		t.Fatalf("blank search must list all 6, got %d", len(got))
	}

	// 异构旧游标：name 序游标拿去 activity 序 / 带 search 复用 / 纯垃圾游标——一律不得 500。
	first := wc.GET("/api/v1/conversations?sort=name&limit=2")
	if first.NextCursor == "" {
		t.Fatalf("name page 1 must yield a cursor, got %s", first.Raw)
	}
	for _, probe := range []string{
		"/api/v1/conversations?limit=2&cursor=" + url.QueryEscape(first.NextCursor),                             // name 游标 → activity 序
		"/api/v1/conversations?sort=created&limit=2&cursor=" + url.QueryEscape(first.NextCursor),                // name 游标 → created 序
		"/api/v1/conversations?search=alpha&limit=2&cursor=" + url.QueryEscape(first.NextCursor),                // 换 search 复用
		"/api/v1/conversations?limit=2&cursor=not-a-cursor",                                                     // 纯垃圾
		"/api/v1/conversations?sort=name&search=zzz&limit=2&cursor=" + url.QueryEscape(first.NextCursor) + "xx", // 篡改尾巴
	} {
		if r := wc.Do("GET", probe, nil); r.Status >= 500 {
			t.Fatalf("stale/foreign cursor must never 500: %s → %d %s", probe, r.Status, r.Raw)
		}
	}
}

// TestContractChat_GeneratingFlagAndFinalizeWindow:
// B-conv-7 —— isGenerating 派生只读：在途生成时 List/Get 冷启动即 true、完后 false（conversation.md）。
// B-chat-3 —— 回合收尾活（同步压缩检查，真 utility 调用拖秒级）期间的 Send 落单槽缓冲（202）、
// 紧随其后被服务；槽满仍 409（chat.md §2）。
func TestContractChat_GeneratingFlagAndFinalizeWindow(t *testing.T) {
	wc, mock := chatSetup(t, true)

	// --- B-conv-7 ---
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "slow generating stream......", StallMS: 6000})
	convG := convCreate(t, wc, "generating probe")
	midG := sendMsg(t, wc, convG, "talk slowly")
	harness.Eventually(t, 5000, "list row isGenerating=true while streaming", func() bool {
		row, ok := findConv(listConvs(t, wc), convG)
		return ok && row.IsGenerating
	})
	var detail struct {
		IsGenerating bool `json:"isGenerating"`
	}
	wc.GET("/api/v1/conversations/" + convG).OK(t, &detail)
	if !detail.IsGenerating {
		t.Fatal("Get must also derive isGenerating=true while streaming")
	}
	waitTurn(t, wc, convG, midG, 20000)
	harness.Eventually(t, 15000, "isGenerating clears after the turn", func() bool {
		row, ok := findConv(listConvs(t, wc), convG)
		if !ok || row.IsGenerating {
			return false
		}
		wc.GET("/api/v1/conversations/" + convG).OK(t, &detail)
		return !detail.IsGenerating
	})

	// --- B-chat-3 ---
	// 压低触发线使第 4 回合的真实 input token 触发压缩；utility 摘要帧带 8s stall 撑开收尾窗。
	wc.PATCH("/api/v1/limits", map[string]any{"context": map[string]any{"triggerRatio": 0.1}}).OK(t, nil)
	mock.Enqueue(utilModel, harness.LLMTurn{Text: "WINDOW-SUMMARY-MARK", StallMS: 8000})
	filler := strings.Repeat("finalize window filler words. ", 800)
	mock.Enqueue(dlgModel,
		harness.LLMTurn{Text: "noted 1"},
		harness.LLMTurn{Text: "noted 2"},
		harness.LLMTurn{Text: "noted 3"},
		harness.LLMTurn{Text: "noted 4", PromptTokens: 60000},
		harness.LLMTurn{Text: "served from the slot", StallMS: 2000},
	)
	convW := convCreate(t, wc, "finalize window") // 有标题 → utility 队列只出压缩摘要。
	var mid string
	for i := 1; i <= 4; i++ {
		mid = sendMsg(t, wc, convW, fmt.Sprintf("TURN%d %s", i, filler))
		if turn := waitTurn(t, wc, convW, mid, 30000); turn.Status != "completed" {
			t.Fatalf("turn %d must complete, got %s %s", i, turn.Status, turn.ErrorMessage)
		}
	}
	// 回合 4 已终态 = 收尾窗开启（q.running 已放行、抽取 goroutine 卡在压缩的 utility stall 里）。
	// Send #5 落单槽缓冲 → 202；Send #6 槽满 → 409。
	slot := wc.Do("POST", "/api/v1/conversations/"+convW+"/messages", map[string]any{"content": "buffered in the slot"})
	if slot.Status != 202 {
		t.Fatalf("the finalize-window Send must be accepted into the slot (202), got %d %s", slot.Status, slot.Raw)
	}
	var slotID struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(slot.Data, &slotID); err != nil || slotID.ID == "" {
		t.Fatalf("slot send must return the assistant id, got %s", slot.Data)
	}
	wc.Do("POST", "/api/v1/conversations/"+convW+"/messages",
		map[string]any{"content": "slot already full"}).Fail(t, 409, "STREAM_IN_PROGRESS")

	// 缓冲的 Send 紧随其后被服务到终态；压缩摘要真实落盘（证明窗口确为压缩收尾、非碰巧）。
	if turn := waitTurn(t, wc, convW, slotID.ID, 40000); turn.Status != "completed" {
		t.Fatalf("the buffered send must be served right after the tail, got %s %s", turn.Status, turn.ErrorMessage)
	}
	harness.Eventually(t, 20000, "the rolling summary persists", func() bool {
		var conv struct {
			Summary string `json:"summary"`
		}
		wc.GET("/api/v1/conversations/" + convW).OK(t, &conv)
		return strings.Contains(conv.Summary, "WINDOW-SUMMARY-MARK")
	})
}

// TestContractChat_GracefulShutdownImmediate: B-chat-6 —— Shutdown 即时（chat.md §2）：SIGTERM
// 到达时 cancel 全部在跑回合 + stop 信号短路队列（不等 5 分钟 idle timer）——流式中优雅停机须
// 秒级退出，回合以 cancelled 终态落盘（重启后可见、无 streaming 残留）。
func TestContractChat_GracefulShutdownImmediate(t *testing.T) {
	srv, wc, mock, wsID, _ := chatC_setup(t, false)

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "very long stalled answer......", StallMS: 60000})
	convID := convCreate(t, wc, "shutdown probe")
	mid := sendMsg(t, wc, convID, "talk forever")
	mock.WaitDumps(t, dlgModel, 1, 10000) // 生成确已在飞（LLM 请求已到假供应商并 stall 住）。

	pid := chatC_pidOnPort(t, srv.BaseURL)
	if err := syscall.Kill(pid, syscall.SIGTERM); err != nil {
		t.Fatalf("SIGTERM: %v", err)
	}
	// 在跑回合 stall 60s、idle timer 5min——20s 内退出即证明 shutdown 短路了两者。
	harness.Eventually(t, 20000, "backend exits promptly after SIGTERM", func() bool {
		return chatC_processExited(pid)
	})

	srv.Restart(t)
	wc2 := srv.Client(t).WS(wsID)
	harness.Eventually(t, 15000, "the interrupted turn persists as cancelled", func() bool {
		for _, m := range listMsgs(t, wc2, convID) {
			if m.ID == mid {
				return m.Status == "cancelled"
			}
		}
		return false
	})
}

// TestContractChat_CrashSweepOrphans: B-chat-10 + B-msg-7 —— 硬崩溃（kill -9）留下的 pending/
// streaming 孤儿由 boot 对账 SweepOrphans/SweepNonTerminal 扫成 cancelled（chat.md §3 +
// messages.md §2）：同目录重启后无任何非终态行残留。
func TestContractChat_CrashSweepOrphans(t *testing.T) {
	srv, wc, mock, wsID, _ := chatC_setup(t, false)

	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "doomed stalled stream......", StallMS: 60000})
	convID := convCreate(t, wc, "crash probe")
	mid := sendMsg(t, wc, convID, "stall then die")
	mock.WaitDumps(t, dlgModel, 1, 10000) // 回合确在流式中（非终态行已落盘）。

	srv.Kill9(t)
	srv.Restart(t)
	wc2 := srv.Client(t).WS(wsID)
	harness.Eventually(t, 15000, "boot reconciliation sweeps the orphan to cancelled", func() bool {
		for _, m := range listMsgs(t, wc2, convID) {
			if m.ID == mid {
				return m.Status == "cancelled"
			}
		}
		return false
	})
	// 整段历史无 streaming/pending 残留（清扫是 workspace 级、非单行）。
	for _, m := range listMsgs(t, wc2, convID) {
		if m.Status == "streaming" || m.Status == "pending" {
			t.Fatalf("no non-terminal row may survive a crash+boot, got %s on %s", m.Status, m.ID)
		}
	}
}

// TestContractChat_ApproveAlwaysLifecycle: B-chat-14 —— approve_always 的对话级会话白名单
// （chat.md §4）：同对话同工具此后免确认直跑；:cancel 只停在途生成、保留白名单；对话删除
// ForgetConversation 整批清授权——新对话同工具重新要确认（授权不越过删除）。
func TestContractChat_ApproveAlwaysLifecycle(t *testing.T) {
	wc, mock := chatSetup(t, false)
	fnID := fnCreate(t, wc, "always_probe", "def go() -> dict:\n    return {\"ran\": True}\n")

	okCount := func() int {
		t.Helper()
		var page struct {
			Aggregates struct {
				OKCount int `json:"okCount"`
			} `json:"aggregates"`
		}
		wc.GET("/api/v1/functions/"+fnID+"/executions").OK(t, &page)
		return page.Aggregates.OKCount
	}

	// 回合 1：danger 阻塞 → approve_always → 真跑。
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{chatC_dangerCall("call_aa1", fnID)}},
		harness.LLMTurn{Text: "ran with always"},
	)
	conv1 := convCreate(t, wc, "always probe")
	mid1 := sendMsg(t, wc, conv1, "run it, always allow")
	var pending []struct {
		ToolCallID string `json:"toolCallId"`
	}
	harness.Eventually(t, 15000, "first danger pends", func() bool {
		pending = nil
		wc.GET("/api/v1/conversations/"+conv1+"/interactions").OK(t, &pending)
		return len(pending) == 1
	})
	wc.POST("/api/v1/conversations/"+conv1+"/interactions/"+pending[0].ToolCallID,
		map[string]any{"action": "approve_always"}).OK(t, nil)
	if turn := waitTurn(t, wc, conv1, mid1, 60000); turn.Status != "completed" {
		t.Fatalf("approved turn must complete, got %s %s", turn.Status, turn.ErrorMessage)
	}
	if okCount() != 1 {
		t.Fatalf("approve_always must run the tool once, got %d", okCount())
	}

	// 回合 2（同对话同工具）：白名单免确认直跑——若误挂交互，waitTurn 会超时失败。
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{chatC_dangerCall("call_aa2", fnID)}},
		harness.LLMTurn{Text: "ran silently"},
	)
	mid2 := sendMsg(t, wc, conv1, "again")
	if turn := waitTurn(t, wc, conv1, mid2, 30000); turn.Status != "completed" {
		t.Fatalf("whitelisted turn must complete without asking, got %s %s", turn.Status, turn.ErrorMessage)
	}
	if okCount() != 2 {
		t.Fatalf("whitelisted call must have run (no gate), got %d", okCount())
	}

	// 回合 3：:cancel 在途生成——白名单必须幸存（Cancel 只停生成、对话仍活）。
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "stalling before cancel......", StallMS: 15000})
	mid3 := sendMsg(t, wc, conv1, "stall")
	sse := wc.Subscribe(t, "messages")
	// llmmock 把 text 对半切:先 flush 前半→stall→再发后半。等前半子串("stalling",在 Text[:half]
	// 内)确认流已起,别等完整短语("stalling before cancel"要 15s stall 后才拼全,10s 内必超时)。
	sse.WaitFor(t, 10000, "stalled stream starts", "stalling")
	wc.POST("/api/v1/conversations/"+conv1+":cancel", nil)
	if turn := waitTurn(t, wc, conv1, mid3, 15000); turn.Status != "cancelled" {
		t.Fatalf("cancelled turn must persist cancelled, got %s", turn.Status)
	}
	mock.Clear(dlgModel)
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{chatC_dangerCall("call_aa3", fnID)}},
		harness.LLMTurn{Text: "still whitelisted after cancel"},
	)
	mid4 := sendMsg(t, wc, conv1, "after the cancel, run again")
	if turn := waitTurn(t, wc, conv1, mid4, 30000); turn.Status != "completed" {
		t.Fatalf(":cancel must keep the whitelist, got %s %s", turn.Status, turn.ErrorMessage)
	}
	if okCount() != 3 {
		t.Fatalf("post-cancel whitelisted call must run, got %d", okCount())
	}

	// 删除对话 → ForgetConversation 清授权 → 新对话同工具重新要确认。
	wc.DELETE("/api/v1/conversations/" + conv1).OK(t, nil)
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{chatC_dangerCall("call_aa4", fnID)}},
		harness.LLMTurn{Text: "asked again"},
	)
	conv2 := convCreate(t, wc, "fresh after delete")
	mid5 := sendMsg(t, wc, conv2, "run it once more")
	harness.Eventually(t, 15000, "a fresh conversation must re-ask", func() bool {
		pending = nil
		wc.GET("/api/v1/conversations/"+conv2+"/interactions").OK(t, &pending)
		return len(pending) == 1
	})
	wc.POST("/api/v1/conversations/"+conv2+"/interactions/"+pending[0].ToolCallID,
		map[string]any{"action": "deny"}).OK(t, nil)
	if turn := waitTurn(t, wc, conv2, mid5, 20000); turn.Status != "completed" {
		t.Fatalf("denied turn must complete, got %s", turn.Status)
	}
	if okCount() != 3 {
		t.Fatalf("the denied re-ask must not run the tool, got %d", okCount())
	}
}

// TestContractChat_SubagentTraceIsolation: B-chat-8 —— LoadHistory 排除 subagent 子消息
// （chat.md §3：subagent_id≠'' 下推 SQL）：sub run 的内部 trace（reasoning）绝不进父模型
// 视角的后续请求；最终答案作为 tool_result 合法留存。
func TestContractChat_SubagentTraceIsolation(t *testing.T) {
	wc, mock := chatSetup(t, false)

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "Subagent",
			Args: fw(map[string]any{"subagent_type": "general-purpose", "prompt": "Answer 42."})}}},
		// sub run 的回合：内部 reasoning 标记 + 最终答案（同队列顺序消费）。
		harness.LLMTurn{Reasoning: "SUBTRACE-INTERNAL-MARKER-9Q", Text: "SUBFINAL-ANSWER-42"},
		harness.LLMTurn{Text: "the delegate said 42"},
	)
	convID := convCreate(t, wc, "trace isolation")
	mid := sendMsg(t, wc, convID, "delegate the question")
	if turn := waitTurn(t, wc, convID, mid, 60000); turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s %s", turn.Status, turn.ErrorMessage)
	}

	// 前提守卫：内部 trace 确实作为 sub-message 落了库（否则下面的否定断言空转）。
	var msgs []struct {
		SubagentID string `json:"subagentId"`
		Blocks     []struct {
			Type    string `json:"type"`
			Content string `json:"content"`
		} `json:"blocks"`
	}
	wc.GET("/api/v1/conversations/"+convID+"/messages?limit=50").OK(t, &msgs)
	traced := false
	for _, m := range msgs {
		if m.SubagentID == "" {
			continue
		}
		for _, b := range m.Blocks {
			if strings.Contains(b.Content, "SUBTRACE-INTERNAL-MARKER-9Q") {
				traced = true
			}
		}
	}
	if !traced {
		t.Fatal("premise: the sub-message must persist the internal reasoning trace")
	}

	// 第二个用户回合：LoadHistory 重建历史——sub trace 必须缺席、tool_result 的最终答案在场。
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "second turn done"})
	mid2 := sendMsg(t, wc, convID, "and now a follow-up")
	if turn := waitTurn(t, wc, convID, mid2, 30000); turn.Status != "completed" {
		t.Fatalf("second turn must complete, got %s", turn.Status)
	}
	dumps := mock.DumpsFor(dlgModel)
	raw := string(dumps[len(dumps)-1].Raw)
	if strings.Contains(raw, "SUBTRACE-INTERNAL-MARKER-9Q") {
		t.Fatal("subagent internal trace must never pollute the parent model view")
	}
	if !strings.Contains(raw, "SUBFINAL-ANSWER-42") {
		t.Fatal("the subagent's final answer legitimately stays as the tool_result")
	}
}

// TestContractChat_ProgressBlockLifecycle: B-msg-1 —— progress 一等持久块（messages.md）：
// run_function 的 print()（driver 引至 stderr）实时流成 tool_call 下的 progress 块并随回合落盘；
// 但 LLM 历史投影是类型白名单——progress 永不回喂模型（同回合回喂请求与下一回合请求都不含）。
func TestContractChat_ProgressBlockLifecycle(t *testing.T) {
	wc, mock := chatSetup(t, false)
	fnID := fnCreate(t, wc, "loud_probe",
		"def loud() -> dict:\n    print(\"PROGRESS-STDERR-MARK-7788\")\n    return {\"done\": True}\n")

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "run_function",
			Args: fw(map[string]any{"functionId": fnID, "args": map[string]any{}})}}},
		harness.LLMTurn{Text: "ran the loud probe"},
	)
	convID := convCreate(t, wc, "progress probe")
	mid := sendMsg(t, wc, convID, "run the loud one")
	turn := waitTurn(t, wc, convID, mid, 120000) // 首跑可能要装 python runtime。
	if turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s %s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	// 落盘：回合 blocks 里有承载 stderr 的 progress 块。
	prog, ok := blockOfType(turn, "progress")
	if !ok || !strings.Contains(prog, "PROGRESS-STDERR-MARK-7788") {
		t.Fatalf("the print output must persist as a progress block, blocks=%+v", turn.Blocks)
	}

	// 白名单：progress 块不进 LLM 历史投影,但 run_function 的 tool_result 的 `logs` 字段**合法**
	// 携带函数 print 输出(run.go:21 契约)——同一 marker 双通道。故不能用「存在」判泄漏,改「计数」:
	// 该回合的回喂请求(请求 2)里 marker 应恰出现 1 次(仅 tool_result.logs);若 progress 块被额外
	// 投影则会出现 ≥2 次。
	dumps := mock.DumpsFor(dlgModel)
	if n := strings.Count(string(dumps[len(dumps)-1].Raw), "PROGRESS-STDERR-MARK-7788"); n != 1 {
		t.Fatalf("marker must appear once (tool_result.logs only) in same-turn request, got %d — progress block leaked into projection", n)
	}
	// 下一回合的 LoadHistory 投影：tool_result 作为历史合法留存(1 次),progress 块不额外投影。
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "next"})
	mid2 := sendMsg(t, wc, convID, "next turn please")
	if turn := waitTurn(t, wc, convID, mid2, 30000); turn.Status != "completed" {
		t.Fatalf("next turn must complete, got %s", turn.Status)
	}
	dumps = mock.DumpsFor(dlgModel)
	if n := strings.Count(string(dumps[len(dumps)-1].Raw), "PROGRESS-STDERR-MARK-7788"); n != 1 {
		t.Fatalf("next-turn history must carry the marker once (tool_result), not double-fed by a progress block, got %d", n)
	}
}

// TestContractChat_MessagesPhysicalTruth:
// B-msg-5 —— ContextRole 是压缩器对块的投影变更，落库 Content 永不改写（messages.md）：压缩后
// 直读 SQLite 断原文逐字未变。
// B-msg-3 —— 两表 append-only（D1）：删对话后 messages / message_blocks 行物理留存。
func TestContractChat_MessagesPhysicalTruth(t *testing.T) {
	srv, wc, mock, _, _ := chatC_setup(t, true)
	wc.PATCH("/api/v1/limits", map[string]any{"context": map[string]any{"triggerRatio": 0.1}}).OK(t, nil)

	mock.Enqueue(utilModel, harness.LLMTurn{Text: "IMMUTABLE-SUMMARY-MARK"})
	filler := strings.Repeat("immutability filler words. ", 800)
	mock.Enqueue(dlgModel,
		harness.LLMTurn{Text: "noted 1"},
		harness.LLMTurn{Text: "noted 2"},
		harness.LLMTurn{Text: "noted 3"},
		harness.LLMTurn{Text: "noted 4", PromptTokens: 60000},
	)
	convID := convCreate(t, wc, "physical truth")
	turn1Content := "IMMUTABLE-TURN1-MARKER " + filler
	waitTurn(t, wc, convID, sendMsg(t, wc, convID, turn1Content), 30000)
	for i := 2; i <= 4; i++ {
		waitTurn(t, wc, convID, sendMsg(t, wc, convID, fmt.Sprintf("TURN%d %s", i, filler)), 30000)
	}
	harness.Eventually(t, 20000, "compaction persists the rolling summary + watermark", func() bool {
		var conv struct {
			Summary              string `json:"summary"`
			SummaryCoversUpToSeq int64  `json:"summaryCoversUpToSeq"`
		}
		wc.GET("/api/v1/conversations/" + convID).OK(t, &conv)
		return strings.Contains(conv.Summary, "IMMUTABLE-SUMMARY-MARK") && conv.SummaryCoversUpToSeq > 0
	})

	// B-msg-5：被折叠回合的 text 块在盘上逐字等于发送原文（投影动的是 context_role/水位，不是 Content）。
	stored := chatC_sqlite(t, srv.DataDir,
		"SELECT content FROM message_blocks WHERE conversation_id='"+convID+"' AND content LIKE 'IMMUTABLE-TURN1-MARKER%'")
	if stored != strings.TrimSpace(turn1Content) && stored != turn1Content {
		t.Fatalf("compaction must never rewrite persisted content:\n want %d bytes, got %d bytes\n got: %.120s",
			len(turn1Content), len(stored), stored)
	}

	// B-msg-3：删对话（204、随后 404），两表行物理留存（D1 内容日志永不删）。
	msgCount := chatC_sqlite(t, srv.DataDir,
		"SELECT COUNT(*) FROM messages WHERE conversation_id='"+convID+"'")
	blkCount := chatC_sqlite(t, srv.DataDir,
		"SELECT COUNT(*) FROM message_blocks WHERE conversation_id='"+convID+"'")
	wc.DELETE("/api/v1/conversations/" + convID).OK(t, nil)
	wc.Do("GET", "/api/v1/conversations/"+convID, nil).Fail(t, 404, "CONVERSATION_NOT_FOUND")
	if after := chatC_sqlite(t, srv.DataDir,
		"SELECT COUNT(*) FROM messages WHERE conversation_id='"+convID+"'"); after != msgCount || after == "0" {
		t.Fatalf("messages rows must physically survive a conversation delete: before=%s after=%s", msgCount, after)
	}
	if after := chatC_sqlite(t, srv.DataDir,
		"SELECT COUNT(*) FROM message_blocks WHERE conversation_id='"+convID+"'"); after != blkCount || after == "0" {
		t.Fatalf("message_blocks rows must physically survive: before=%s after=%s", blkCount, after)
	}
}

// TestContractChat_SubagentTypesAndRoundCap: B-sub-4 —— 内置三类型白名单 + 轮上限
// （subagent.md：Explore=Read/LS/Glob/Grep·30 轮；Plan=+WebFetch/WebSearch·25 轮；
// general-purpose=父全集减 Subagent[及 get_subagent_trace]·25 轮）。Explore 用恰 30 个
// tool-call 帧耗尽轮上限：sub 恰发 30 个请求、sub-message 落 max_steps 终态、父 tool_result
// 带「did not finish cleanly」截断前缀（F150）。
func TestContractChat_SubagentTypesAndRoundCap(t *testing.T) {
	wc, mock := chatSetup(t, false)

	globCall := harness.MockToolCall{Name: "Glob",
		Args: fw(map[string]any{"pattern": "*.zzz-noexist", "path": "~"})}

	// --- Explore：白名单 + 轮上限一并压 ---
	mock.Enqueue(dlgModel, harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "Subagent",
		Args: fw(map[string]any{"subagent_type": "Explore", "prompt": "loop forever"})}}})
	for i := 0; i < 30; i++ {
		mock.Enqueue(dlgModel, harness.LLMTurn{ToolCalls: []harness.MockToolCall{globCall}})
	}
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "explore phase done"})
	convE := convCreate(t, wc, "explore cap")
	midE := sendMsg(t, wc, convE, "explore and loop")
	if turn := waitTurn(t, wc, convE, midE, 120000); turn.Status != "completed" {
		t.Fatalf("parent turn must complete, got %s %s", turn.Status, turn.ErrorMessage)
	}
	exp := chatC_subDumps(mock, "code-reconnaissance")
	if len(exp) != 30 {
		t.Fatalf("Explore is capped at 30 turns — want exactly 30 sub requests, got %d", len(exp))
	}
	wantExplore := map[string]bool{"Read": true, "LS": true, "Glob": true, "Grep": true}
	if len(exp[0].Tools) != len(wantExplore) {
		t.Fatalf("Explore toolset must be exactly Read/LS/Glob/Grep, got %v", exp[0].Tools)
	}
	for _, n := range exp[0].Tools {
		if !wantExplore[n] {
			t.Fatalf("tool %s leaked into the Explore whitelist %v", n, exp[0].Tools)
		}
	}
	// sub-message 的诚实终态 + 父视角的截断前缀。
	var msgs []struct {
		SubagentID string `json:"subagentId"`
		StopReason string `json:"stopReason"`
		ErrorCode  string `json:"errorCode"`
	}
	wc.GET("/api/v1/conversations/"+convE+"/messages?limit=50").OK(t, &msgs)
	capped := false
	for _, m := range msgs {
		if m.SubagentID != "" && strings.Contains(strings.ToLower(m.StopReason+m.ErrorCode), "max_steps") {
			capped = true
		}
	}
	if !capped {
		t.Fatalf("the exhausted sub-message must carry a max_steps terminal, got %+v", msgs)
	}
	dumps := mock.DumpsFor(dlgModel)
	parentLast := dumps[len(dumps)-1]
	annotated := false
	for _, m := range parentLast.Messages {
		if m.Role == "tool" && strings.Contains(m.Content, "did not finish cleanly") {
			annotated = true
		}
	}
	if !annotated {
		t.Fatal("the parent tool_result must be annotated with the cutoff (F150)")
	}

	// --- Plan：白名单含 WebFetch/WebSearch、不含系统工具 ---
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "Subagent",
			Args: fw(map[string]any{"subagent_type": "Plan", "prompt": "plan briefly"})}}},
		harness.LLMTurn{Text: "PLAN-DONE"},
		harness.LLMTurn{Text: "plan phase done"},
	)
	convP := convCreate(t, wc, "plan toolset")
	if turn := waitTurn(t, wc, convP, sendMsg(t, wc, convP, "plan it"), 60000); turn.Status != "completed" {
		t.Fatalf("plan turn must complete, got %s %s", turn.Status, turn.ErrorMessage)
	}
	plans := chatC_subDumps(mock, "architectural-planning")
	if len(plans) == 0 {
		t.Fatal("the Plan sub run must have hit the dialogue queue")
	}
	for _, want := range []string{"Read", "LS", "Glob", "Grep", "WebFetch", "WebSearch"} {
		if !hasTool(plans[0].Tools, want) {
			t.Fatalf("Plan whitelist must carry %s, got %v", want, plans[0].Tools)
		}
	}
	for _, deny := range []string{"run_function", "todo_write", "Subagent", "get_subagent_trace"} {
		if hasTool(plans[0].Tools, deny) {
			t.Fatalf("%s must not leak into the Plan whitelist %v", deny, plans[0].Tools)
		}
	}

	// --- general-purpose：父全集减 Subagent + get_subagent_trace ---
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "Subagent",
			Args: fw(map[string]any{"subagent_type": "general-purpose", "prompt": "do the thing"})}}},
		harness.LLMTurn{Text: "GP-DONE"},
		harness.LLMTurn{Text: "gp phase done"},
	)
	convG := convCreate(t, wc, "gp toolset")
	if turn := waitTurn(t, wc, convG, sendMsg(t, wc, convG, "delegate it"), 60000); turn.Status != "completed" {
		t.Fatalf("gp turn must complete, got %s %s", turn.Status, turn.ErrorMessage)
	}
	gps := chatC_subDumps(mock, "general-purpose subagent")
	if len(gps) == 0 {
		t.Fatal("the general-purpose sub run must have hit the dialogue queue")
	}
	if !hasTool(gps[0].Tools, "todo_write") {
		t.Fatalf("general-purpose must inherit the parent's tools (todo_write), got %v", gps[0].Tools)
	}
	for _, deny := range []string{"Subagent", "get_subagent_trace"} {
		if hasTool(gps[0].Tools, deny) {
			t.Fatalf("%s must always be stripped from a subagent (recursion/isolation guard), got %v", deny, gps[0].Tools)
		}
	}
}

// TestContractChat_SubagentCancelTerminal: B-sub-5 —— 被取消的 subagent 仍落终态 sub-message
// 防孤儿（subagent.md：chatHost 系 Detached 落盘）：父 :cancel 中断在跑 sub run 后，父回合与
// sub-message 都以终态（cancelled）可查、无 streaming 残留。
func TestContractChat_SubagentCancelTerminal(t *testing.T) {
	wc, mock := chatSetup(t, false)

	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "Subagent",
			Args: fw(map[string]any{"subagent_type": "general-purpose", "prompt": "stall a while"})}}},
		// sub run 的回合：长 stall，等着被父 :cancel 腰斩。
		harness.LLMTurn{Text: "sub stalling......", StallMS: 30000},
	)
	convID := convCreate(t, wc, "sub cancel")
	mid := sendMsg(t, wc, convID, "delegate then cancel")
	mock.WaitDumps(t, dlgModel, 2, 20000) // 请求 2 = sub run 已在飞。
	wc.POST("/api/v1/conversations/"+convID+":cancel", nil)

	harness.Eventually(t, 20000, "parent turn and sub-message both reach terminal states", func() bool {
		var msgs []struct {
			ID         string `json:"id"`
			SubagentID string `json:"subagentId"`
			Status     string `json:"status"`
		}
		wc.GET("/api/v1/conversations/"+convID+"/messages?limit=50").OK(t, &msgs)
		parentDone, subSeen, subDone := false, false, false
		for _, m := range msgs {
			if m.ID == mid {
				parentDone = m.Status == "cancelled"
			}
			if m.SubagentID != "" {
				subSeen = true
				subDone = m.Status != "streaming" && m.Status != "pending"
			}
		}
		return parentDone && subSeen && subDone
	})
}

// TestContractChat_SubagentModelNotOverridden: B-sub-6 —— subagent 模型 = workspace dialogue
// 默认、刻意不承袭 per-conversation override（subagent.md）：对话 override 指向 mock-agent 后，
// 父回合走 mock-agent 队列，sub run 仍落 dialogue 默认（gpt-4o）队列。
func TestContractChat_SubagentModelNotOverridden(t *testing.T) {
	_, wc, mock, _, keyID := chatC_setup(t, false)

	convID := convCreate(t, wc, "override probe")
	wc.PATCH("/api/v1/conversations/"+convID,
		map[string]any{"modelOverride": map[string]any{"apiKeyId": keyID, "modelId": "mock-agent"}}).OK(t, nil)

	mock.Enqueue("mock-agent",
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "Subagent",
			Args: fw(map[string]any{"subagent_type": "general-purpose", "prompt": "answer once"})}}},
		harness.LLMTurn{Text: "relayed the sub answer"},
	)
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "SUB-ON-DIALOGUE-QUEUE"})

	mid := sendMsg(t, wc, convID, "delegate under override")
	if turn := waitTurn(t, wc, convID, mid, 60000); turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s %s", turn.Status, turn.ErrorMessage)
	}
	// sub 请求恰好 1 个、落 dialogue 默认队列，且确为 subagent 视角。
	subDumps := mock.DumpsFor(dlgModel)
	if len(subDumps) != 1 || !strings.Contains(subDumps[0].System, "subagent") {
		t.Fatalf("the sub run must land on the workspace dialogue model exactly once, got %d dumps", len(subDumps))
	}
	// 父回合的两个请求都在 override 队列。
	if n := len(mock.DumpsFor("mock-agent")); n != 2 {
		t.Fatalf("the parent turn must ride the conversation override queue (2 requests), got %d", n)
	}
	// sub 的答案回喂父对话。
	parentDumps := mock.DumpsFor("mock-agent")
	fed := false
	for _, m := range parentDumps[len(parentDumps)-1].Messages {
		if m.Role == "tool" && strings.Contains(m.Content, "SUB-ON-DIALOGUE-QUEUE") {
			fed = true
		}
	}
	if !fed {
		t.Fatal("the sub answer must feed back to the parent")
	}
}

// TestContractChat_TodoScopesRemindersAndLimits:
// B-todo-7 —— 写入即推 messages 流 todo 信号（todo.md：前端实时面板）。
// B-todo-3 —— reminder 0-open 抑制：全完成清单不再逐轮注入（render.reminder open==0 → false）。
// B-todo-6 —— ≤64 项上限：65 项 todo_write 按 TODO_TOO_MANY_ITEMS 拒、清单不变。
// B-todo-5 —— subagent run 独立作用域（scope=subagent id）：sub 的 todo_write 不动父清单，
// 看板 ?subagentId= 可读回 sub 清单。
func TestContractChat_TodoScopesRemindersAndLimits(t *testing.T) {
	wc, mock := chatSetup(t, false)

	// --- conv1: 信号 + reminder 正/负控 + 上限 ---
	sse := wc.Subscribe(t, "messages")
	conv1 := convCreate(t, wc, "todo lifecycle")

	// 回合 1：写两条开放项。
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "todo_write", Args: fw(map[string]any{
			"items": []map[string]any{
				{"content": "plan step one", "status": "in_progress", "activeForm": "Doing plan step one"},
				{"content": "plan step two", "status": "pending"},
			}})}}},
		harness.LLMTurn{Text: "planned"},
	)
	mid1 := sendMsg(t, wc, conv1, "make the plan")
	if turn := waitTurn(t, wc, conv1, mid1, 30000); turn.Status != "completed" {
		t.Fatalf("turn 1 must complete, got %s %s", turn.Status, turn.ErrorMessage)
	}
	// B-todo-7：写入即推 durable 面板信号（node.type=todo + 载荷条目）。
	sse.WaitFor(t, 10000, "todo signal on the messages stream", `"type":"todo"`, "plan step one")

	// 回合 2：正控——开放清单以 <system-reminder> 逐轮注入；随后全部写成 completed。
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "todo_write", Args: fw(map[string]any{
			"items": []map[string]any{
				{"content": "plan step one", "status": "completed"},
				{"content": "plan step two", "status": "completed"},
			}})}}},
		harness.LLMTurn{Text: "all done"},
	)
	mid2 := sendMsg(t, wc, conv1, "finish everything")
	if turn := waitTurn(t, wc, conv1, mid2, 30000); turn.Status != "completed" {
		t.Fatalf("turn 2 must complete, got %s", turn.Status)
	}
	dumps := mock.DumpsFor(dlgModel)
	// 回合 2 的首请求：清单仍开放 → reminder 在场（正控，钉住标记串）。
	turn2First := dumps[len(dumps)-2]
	if !strings.Contains(string(turn2First.Raw), "Current todo list (") {
		t.Fatal("premise: an open checklist must ride each step as the live reminder")
	}
	// 回合 3：全完成 → reminder 抑制（B-todo-3）。
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "nothing left"})
	mid3 := sendMsg(t, wc, conv1, "anything left?")
	if turn := waitTurn(t, wc, conv1, mid3, 30000); turn.Status != "completed" {
		t.Fatalf("turn 3 must complete, got %s", turn.Status)
	}
	dumps = mock.DumpsFor(dlgModel)
	if strings.Contains(string(dumps[len(dumps)-1].Raw), "Current todo list (") {
		t.Fatal("a fully-completed checklist must not be injected turn after turn (0-open suppression)")
	}

	// 回合 4：65 项超限——工具按 TODO_TOO_MANY_ITEMS 拒、错误回喂模型、清单保持原样（B-todo-6）。
	over := make([]map[string]any, 65)
	for i := range over {
		over[i] = map[string]any{"content": fmt.Sprintf("overflow item %d", i+1), "status": "pending"}
	}
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "todo_write", Args: fw(map[string]any{"items": over})}}},
		harness.LLMTurn{Text: "acknowledged the limit"},
	)
	mid4 := sendMsg(t, wc, conv1, "write a huge list")
	if turn := waitTurn(t, wc, conv1, mid4, 30000); turn.Status != "completed" {
		t.Fatalf("turn 4 must complete, got %s", turn.Status)
	}
	dumps = mock.DumpsFor(dlgModel)
	rejected := false
	for _, m := range dumps[len(dumps)-1].Messages {
		if m.Role == "tool" && strings.Contains(strings.ToLower(m.Content), "too many") {
			rejected = true
		}
	}
	if !rejected {
		t.Fatal("the 65-item write must be rejected loudly back to the model")
	}
	var board struct {
		Todos []struct {
			Content string `json:"content"`
			Status  string `json:"status"`
		} `json:"todos"`
	}
	wc.GET("/api/v1/conversations/"+conv1+"/todos").OK(t, &board)
	if len(board.Todos) != 2 || board.Todos[0].Status != "completed" {
		t.Fatalf("a rejected write must leave the checklist untouched, got %+v", board.Todos)
	}

	// --- conv2: subagent 独立作用域（B-todo-5）---
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "todo_write", Args: fw(map[string]any{
			"items": []map[string]any{{"content": "parent scope item", "status": "in_progress", "activeForm": "Parenting"}}})}}},
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "Subagent",
			Args: fw(map[string]any{"subagent_type": "general-purpose", "prompt": "track your own work"})}}},
		// sub run：写自己的清单，然后收尾。
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "todo_write", Args: fw(map[string]any{
			"items": []map[string]any{{"content": "sub scope item", "status": "pending"}}})}}},
		harness.LLMTurn{Text: "sub done"},
		harness.LLMTurn{Text: "parent done"},
	)
	conv2 := convCreate(t, wc, "todo scopes")
	mid5 := sendMsg(t, wc, conv2, "plan, then delegate")
	if turn := waitTurn(t, wc, conv2, mid5, 60000); turn.Status != "completed" {
		t.Fatalf("scope turn must complete, got %s %s", turn.Status, turn.ErrorMessage)
	}
	// 父清单只有父项（sub 的写没串台）。
	wc.GET("/api/v1/conversations/"+conv2+"/todos").OK(t, &board)
	if len(board.Todos) != 1 || board.Todos[0].Content != "parent scope item" {
		t.Fatalf("the parent checklist must hold exactly the parent item, got %+v", board.Todos)
	}
	// 用 sub-message 的 subagentId 读回 sub 作用域清单。
	var msgs []struct {
		SubagentID string `json:"subagentId"`
	}
	wc.GET("/api/v1/conversations/"+conv2+"/messages?limit=50").OK(t, &msgs)
	subID := ""
	for _, m := range msgs {
		if m.SubagentID != "" {
			subID = m.SubagentID
		}
	}
	if subID == "" {
		t.Fatal("premise: the sub run must persist a sub-message with its run id")
	}
	wc.GET("/api/v1/conversations/"+conv2+"/todos?subagentId="+subID).OK(t, &board)
	if len(board.Todos) != 1 || board.Todos[0].Content != "sub scope item" {
		t.Fatalf("?subagentId= must read back the sub scope, got %+v", board.Todos)
	}
}

// TestContractChat_TouchpointSelfReportAndNameBorrow:
// B-tp-6 —— TouchEntity 自报路（touchpoint.md）：agent 挂载的 function 以实体名运行、自报
// {kind,id,name} 记 executed、完全绕过目录——实体名撞目录键名（"get_function"）且 args 里带
// "functionId" 诱饵也不误提取。
// B-tp-8 —— deleted 行兄弟借名快照：先 executed 再 delete_function → deleted 行仍诚实带名；
// 对话没碰过就删的孤儿行诚实空名。
func TestContractChat_TouchpointSelfReportAndNameBorrow(t *testing.T) {
	_, wc, mock, wsID, keyID := chatC_setup(t, false)
	wc.PUT("/api/v1/workspaces/"+wsID+"/default-models/agent",
		map[string]any{"apiKeyId": keyID, "modelId": "mock-agent"}).OK(t, nil)

	// --- B-tp-6：撞目录键名的挂载函数 ---
	fnID := fnCreate(t, wc, "get_function",
		"def get_function(functionId: str) -> dict:\n    return {\"echo\": functionId}\n")
	agID := agCreate(t, wc, map[string]any{
		"name": "Ledger Worker", "description": "runs the colliding mount", "prompt": "Use your tool.",
		"tools": []map[string]any{{"ref": fnID, "name": "get_function"}},
	})
	mock.Enqueue("mock-agent",
		// 挂载工具以实体名 "get_function" 运行；args 的 "functionId" 是目录提取的诱饵——
		// 若目录路误跑，会长出 fn_bogus 的 viewed 幽灵行。
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "get_function",
			Args: fw(map[string]any{"functionId": "fn_0000000000009999"})}}},
		harness.LLMTurn{Text: "mount ran"},
	)
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "invoke_agent",
			Args: fw(map[string]any{"agentId": agID, "input": map[string]any{"q": "go"}})}}},
		harness.LLMTurn{Text: "agent finished"},
	)
	conv1 := convCreate(t, wc, "self report")
	mid := sendMsg(t, wc, conv1, "have the worker run its tool")
	if turn := waitTurn(t, wc, conv1, mid, 120000); turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s %s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	var rows []touchpointRow
	harness.Eventually(t, 10000, "the self-reported executed row lands", func() bool {
		rows = listTouchpoints(t, wc, conv1, "")
		return findRow(rows, "executed", fnID) != nil
	})
	ex := findRow(rows, "executed", fnID)
	if ex.ItemKind != "function" || ex.ItemName != "get_function" {
		t.Fatalf("self-report must book the ENTITY {kind,id,name}, got %+v", ex)
	}
	for _, r := range rows {
		if r.ItemID == "fn_0000000000009999" {
			t.Fatalf("the catalog decoy arg must never be extracted for a marker tool: %+v", r)
		}
	}
	if v := findRow(rows, "viewed", fnID); v != nil {
		t.Fatalf("a mounted entity tool must bypass the catalog (no viewed row), got %+v", v)
	}

	// --- B-tp-8：借名快照 + 孤儿空名 ---
	fnB := fnCreate(t, wc, "borrow_probe", "def borrow_probe() -> dict:\n    return {\"ok\": True}\n")
	fnO := fnCreate(t, wc, "orphan_probe", "def orphan_probe() -> dict:\n    return {\"ok\": True}\n")
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "run_function",
			Args: fw(map[string]any{"functionId": fnB, "args": map[string]any{}})}}},
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "delete_function",
			Args: fw(map[string]any{"functionId": fnB})}}},
		// orphan_probe 在本对话零前科，直接删。
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "delete_function",
			Args: fw(map[string]any{"functionId": fnO})}}},
		harness.LLMTurn{Text: "both deleted"},
	)
	conv2 := convCreate(t, wc, "name borrow")
	mid2 := sendMsg(t, wc, conv2, "run one, then delete both")
	if turn := waitTurn(t, wc, conv2, mid2, 120000); turn.Status != "completed" {
		t.Fatalf("borrow turn must complete, got %s %s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	harness.Eventually(t, 10000, "both deleted rows land", func() bool {
		rows = listTouchpoints(t, wc, conv2, "?verb=deleted")
		return findRow(rows, "deleted", fnB) != nil && findRow(rows, "deleted", fnO) != nil
	})
	if d := findRow(rows, "deleted", fnB); d.ItemName != "borrow_probe" {
		t.Fatalf("the deleted row must borrow its sibling's name snapshot, got %q", d.ItemName)
	}
	if d := findRow(rows, "deleted", fnO); d.ItemName != "" {
		t.Fatalf("an untouched-then-deleted orphan row must carry an honest empty name, got %q", d.ItemName)
	}
}

// TestContractChat_TouchpointSubagentActorAndFailures: B-tp-7 —— subagent 内触碰记到父对话
// 名下且 actor=subagent（database.md CHECK user/assistant/subagent + loop touches actor 判定）；
// 失败的调用不记（失败的触碰不是触碰）。
func TestContractChat_TouchpointSubagentActorAndFailures(t *testing.T) {
	wc, mock := chatSetup(t, false)
	fnV := fnCreate(t, wc, "sub_viewed_probe", "def sv() -> dict:\n    return {\"ok\": True}\n")
	fnF := fnCreate(t, wc, "always_fails", "def af() -> dict:\n    raise RuntimeError(\"scripted failure\")\n")

	// 回合 1：sub run 里 get_function（目录 viewed 路）→ 记到父台账、actor=subagent。
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "Subagent",
			Args: fw(map[string]any{"subagent_type": "general-purpose", "prompt": "inspect the probe"})}}},
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "get_function",
			Args: fw(map[string]any{"functionId": fnV})}}},
		harness.LLMTurn{Text: "inspected"},
		harness.LLMTurn{Text: "delegated inspection done"},
	)
	convID := convCreate(t, wc, "sub actor")
	mid := sendMsg(t, wc, convID, "delegate the inspection")
	if turn := waitTurn(t, wc, convID, mid, 60000); turn.Status != "completed" {
		t.Fatalf("turn 1 must complete, got %s %s", turn.Status, turn.ErrorMessage)
	}
	var rows []touchpointRow
	harness.Eventually(t, 10000, "the sub touch lands on the PARENT ledger", func() bool {
		rows = listTouchpoints(t, wc, convID, "?verb=viewed")
		return findRow(rows, "viewed", fnV) != nil
	})
	if v := findRow(rows, "viewed", fnV); v.LastActor != "subagent" {
		t.Fatalf("a sub run's touch must book actor=subagent, got %+v", v)
	}

	// 回合 2：run_function 跑一个会 raise 的真函数——工具**成功执行**(把函数失败格式化成 tool_result
	// 给 LLM),故 recordTouches 门控 ok&&executed=true → 记 executed 台账。台账答「对话碰过哪些实体」:
	// 该实体真被执行了(跑了、raise 了)就是碰过,与 viewed/created 一样无条件记(一致性+事实记录)。
	// 「失败的调用不记」指**工具层**失败(坏 ref→工具 error、danger 拒),由单测 TestRecordTouches_SilentSkips
	// + TestChat_HumanLoopDangerGate「deny 零触点」覆盖;语义失败(函数内部 raise)不属此列。
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "run_function",
			Args: fw(map[string]any{"functionId": fnF, "args": map[string]any{}})}}},
		harness.LLMTurn{Text: "it failed, noted"},
	)
	mid2 := sendMsg(t, wc, convID, "run the failing one")
	if turn := waitTurn(t, wc, convID, mid2, 120000); turn.Status != "completed" {
		t.Fatalf("turn 2 must complete, got %s %s", turn.Status, turn.ErrorMessage)
	}
	var exec *touchpointRow
	harness.Eventually(t, 10000, "an executed-but-raised function still books an executed touch", func() bool {
		exec = findRow(listTouchpoints(t, wc, convID, "?verb=executed"), "executed", fnF)
		return exec != nil
	})
	if exec.ItemName != "always_fails" || exec.LastActor != "assistant" {
		t.Fatalf("executed touch must snapshot the entity name + assistant actor, got %+v", exec)
	}
}
