// platform_r4_test.go — R4（A9 平台高标准补全，首轮缺格的补课）。
//
// PLAN A9 逐格：SSE 协议面（durable 重连 fromSeq 续传 / 环淘汰 410 SEQ_TOO_OLD / entities
// 流 build 镜像与 run 终端真到达）；limits **每字段** PATCH→对应行为真变（invokeMaxTurns /
// llmIdleSec / bashDefaultTimeoutSec / bashOutputCapKB / attachmentMaxMB / webhookBodyMaxMB
// ——maxSteps/triggerRatio/toolResultCapKB 已在 W4/W5 钉死）；通知分径全域普查（events.md
// 的 ⊞ 落行 / ⤳ 仅帧两档逐事件钉死，两个方向都会红 + 未读/已读）；sandbox runtime 装/删/gc/
// disk-usage；workspace 级联删除逐资产残留（12 类全建再删，索引/可达性全清）。
package scenarios

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestPlatformR4_SSEProtocolFaces: 三流协议面——notifications durable 续传重放、
// 环淘汰（256）后 fromSeq 太老 → 410 SEQ_TOO_OLD、entities 流 build 镜像 + run 终端帧真到达。
func TestPlatformR4_SSEProtocolFaces(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "sse-ws"}).Field(t, "id")
	wc := c.WS(wsID)

	// entities 流：function 构建镜像 + 执行 print 的 run 终端帧。
	es := wc.Subscribe(t, "entities")
	fnID := fnCreate(t, wc, "sse_probe_fn",
		"def sse_probe_fn() -> dict:\n    print(\"TERMLINE from run\")\n    return {}\n")
	es.WaitFor(t, 10000, "build mirror frames on entities stream", fnID)
	wc.POST("/api/v1/functions/"+fnID+":run", map[string]any{"args": map[string]any{}}).OK(t, nil)
	es.WaitFor(t, 15000, "run terminal stderr frame on entities stream", "TERMLINE")

	// notifications durable 续传：取一帧 seq、重连 fromSeq → 之后的帧重放。
	ns := wc.Subscribe(t, "notifications")
	wc.PUT("/api/v1/memories/replay-a", map[string]any{
		"description": "a", "content": "first durable", "source": "user",
	}).OK(t, nil)
	first := ns.WaitFor(t, 8000, "first notification frame", "memory.")
	var env struct {
		Seq int64 `json:"seq"`
	}
	if json.Unmarshal(first.Data, &env) != nil || env.Seq <= 0 {
		t.Fatalf("notification frame must be durable (seq>0): %s", first.Data)
	}
	wc.PUT("/api/v1/memories/replay-b", map[string]any{
		"description": "b", "content": "second durable", "source": "user",
	}).OK(t, nil)
	replay := wc.SubscribeFrom(t, "notifications", env.Seq)
	replay.WaitFor(t, 8000, "post-cursor durable frame replays", "replay-b")

	// 环淘汰：>256 条 durable 后 fromSeq=1 已被挤出 → 410 SEQ_TOO_OLD（错误走 Envelope）。
	for i := 0; i < 260; i++ {
		wc.PUT("/api/v1/memories/evict", map[string]any{
			"description": "evict", "content": fmt.Sprintf("spin %d", i), "source": "user",
		}).OK(t, nil)
	}
	wc.Do("GET", "/api/v1/notifications/stream?fromSeq=1", nil).Fail(t, 410, "SEQ_TOO_OLD")
}

// TestPlatformR4_LimitsEveryField: limits 逐字段热换→行为真变。
func TestPlatformR4_LimitsEveryField(t *testing.T) {
	wc, mock := chatSetup(t, false)

	// guards.attachmentMaxMB：默认 50MB 下 1.5MB 可传；调到 1MB 后同载荷被拒。
	big := make([]byte, 1500*1024)
	uploadAtt(t, wc, "ok.bin", "text/plain", big)
	wc.PATCH("/api/v1/limits", map[string]any{"guards": map[string]any{"attachmentMaxMB": 1}}).OK(t, nil)
	if r := wc.Upload(t, "/api/v1/attachments", "big.bin", "text/plain", big); r.Status < 400 {
		t.Fatalf("1.5MB upload must reject under attachmentMaxMB=1, got %d", r.Status)
	}

	// guards.webhookBodyMaxMB：1.5MB 正签 body 在默认 10MB 下放行、调到 1 后 413。
	// （入站路由按 trigger id：/api/v1/webhooks/{trgID}/incoming，监听需 activate。）
	secret := "limitsecret"
	trgID := trgCreate(t, wc, "limit_hook", "webhook", map[string]any{
		"path": "limit-in", "secret": secret, "signatureAlgo": "hmac-sha256-hex",
	})
	wfWithTrigger(t, wc, "limit_hook_wf", trgID)
	bigBody := []byte(`{"pad":"` + strings.Repeat("x", 1500*1024) + `"}`)
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(bigBody)
	sig := "sha256=" + hex.EncodeToString(mac.Sum(nil))
	post := func() int {
		req, _ := http.NewRequest("POST", wc.BaseURL()+"/api/v1/webhooks/"+trgID+"/limit-in",
			strings.NewReader(string(bigBody)))
		req.Header.Set("X-Hub-Signature-256", sig)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatalf("webhook post: %v", err)
		}
		defer resp.Body.Close()
		return resp.StatusCode
	}
	if code := post(); code >= 300 {
		t.Fatalf("1.5MB webhook body must pass under the 10MB default, got %d", code)
	}
	wc.PATCH("/api/v1/limits", map[string]any{"guards": map[string]any{"webhookBodyMaxMB": 1}}).OK(t, nil)
	if code := post(); code != 413 {
		t.Fatalf("oversized webhook body must 413 under webhookBodyMaxMB=1, got %d", code)
	}

	// timeout.bashDefaultTimeoutSec + tools.bashOutputCapKB：LLM 跑 Bash——超时真切、输出真截。
	wc.PATCH("/api/v1/limits", map[string]any{
		"timeout": map[string]any{"bashDefaultTimeoutSec": 1},
		"tools":   map[string]any{"bashOutputCapKB": 1},
	}).OK(t, nil)
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "Bash",
			Args: fw(map[string]any{"command": "sleep 5 && echo never"})}}},
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "Bash",
			Args: fw(map[string]any{"command": "yes flood | head -c 200000"})}}},
		harness.LLMTurn{Text: "bash probes done"},
	)
	convID := convCreate(t, wc, "limits bash")
	mid := sendMsg(t, wc, convID, "probe the knobs")
	if turn := waitTurn(t, wc, convID, mid, 60000); turn.Status != "completed" {
		t.Fatalf("bash probe turn must complete, got %s err=%s", turn.Status, turn.ErrorMessage)
	}
	dumps := mock.DumpsFor(dlgModel)
	timeoutSeen, capSeen := false, false
	for _, d := range dumps {
		for _, m := range d.Messages {
			if m.Role != "tool" {
				continue
			}
			low := strings.ToLower(m.Content)
			if strings.Contains(low, "timeout") || strings.Contains(low, "timed out") {
				timeoutSeen = true
			}
			// 200KB 输出在 1KB 上限下必然带截断痕迹（且远小于原量）。
			if strings.Contains(low, "flood") && len(m.Content) < 8*1024 {
				capSeen = true
			}
		}
	}
	if !timeoutSeen {
		t.Error("bashDefaultTimeoutSec=1 must cut the 5s command with a timeout-flavored result")
	}
	if !capSeen {
		t.Error("bashOutputCapKB=1 must cap the flood output fed back to the LLM")
	}

	// agent.invokeMaxTurns：永不收口的 agent 在 2 轮被切，状态/stopReason 诚实。
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"invokeMaxTurns": 2}}).OK(t, nil)
	// Pick the MOCK key by name — the workspace ALSO auto-provisions the managed free-tier key
	// asynchronously, so [0] was a race: when the managed key sorted first, the agent scene
	// routed to the REAL gateway, a real model answered and ended the loop naturally, and the
	// max-turns cut never fired (this test then failed on live-network behavior).
	// 按名取 mock key——workspace 还会异步自动开通托管 free-tier key,取 [0] 是竞态:托管 key 排前时
	// agent 场景被路由到真网关,真模型答完自然收口,max-turns 切割永不触发(本测就此栽在真网络上)。
	keyArr := []struct {
		ID          string `json:"id"`
		DisplayName string `json:"displayName"`
	}{}
	wc.GET("/api/v1/api-keys").OK(t, &keyArr)
	mockKeyID := ""
	for _, k := range keyArr {
		if k.DisplayName == "llmmock" {
			mockKeyID = k.ID
		}
	}
	if mockKeyID == "" {
		t.Fatalf("mock key not found among %d workspace keys", len(keyArr))
	}
	wc.PUT("/api/v1/workspaces/"+wsOf(t, wc)+"/default-models/agent",
		map[string]any{"apiKeyId": mockKeyID, "modelId": agModel}).OK(t, nil)
	fnLoop := fnCreate(t, wc, "loop_target", "def loop_target() -> dict:\n    return {}\n")
	agID := agCreate(t, wc, map[string]any{
		"name": "Endless", "description": "loops", "prompt": "loop",
		"tools": []map[string]any{{"ref": fnLoop, "name": "loop_target"}},
	})
	for i := 0; i < 5; i++ {
		mock.Enqueue(agModel, harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "loop_target",
			Args: fw(map[string]any{})}}})
	}
	res := agInvoke(t, wc, agID, nil)
	if res.Steps > 2 || !strings.Contains(strings.ToLower(res.Status+res.StopReason), "max") {
		t.Fatalf("invokeMaxTurns=2 must cut the loop honestly, got %+v", res)
	}

	// timeout.llmIdleSec：流中静默 8s、闲置 2s → 回合以超时类错误落地。
	wc.PATCH("/api/v1/limits", map[string]any{"timeout": map[string]any{"llmIdleSec": 2}}).OK(t, nil)
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "half......half", StallMS: 8000})
	conv2 := convCreate(t, wc, "idle cut")
	mid2 := sendMsg(t, wc, conv2, "stall mid stream")
	turn := waitTurn(t, wc, conv2, mid2, 30000)
	if turn.Status == "completed" || turn.ErrorCode == "" {
		t.Fatalf("llmIdleSec=2 must error the stalled turn with a code, got %s code=%q", turn.Status, turn.ErrorCode)
	}
}

// wsOf 取 client 绑定的 workspace id（从激活列表反查）。
func wsOf(t *testing.T, wc *harness.Client) string {
	t.Helper()
	var rows []struct {
		ID string `json:"id"`
	}
	wc.GET("/api/v1/workspaces").OK(t, &rows)
	if len(rows) == 0 {
		t.Fatal("no workspace")
	}
	return rows[0].ID
}

// TestPlatformR4_NotificationAllDomains: 通知分径（N0）的**全域普查**——events.md 登记的
// ⊞/⤳ 两档逐事件钉死。⊞ = Emit（落收件箱行 **+** 推 durable 帧）；⤳ = Broadcast（**只推帧、
// 不落行**——rail/树的对账回声，其真相是实体自身状态，进收件箱即噪音）。
//
// 本测试在**两个方向**都会红，这正是 N0 那一刀的全部意义：
//   - ⊞ 档某域不再落行 → 红（wantInbox 的 Eventually 超时）；
//   - ⤳ 档某域**偷偷落了行** → 也红（wantFrameOnly 的行断言）。
//
// 事实源是 events.md 的 ⊞/⤳ 标记，不是「域前缀」——`document` 是唯一横跨两档的域
// （created/updated/moved=⤳ 树刷新回声，deleted=⊞ 破坏性、AI 可删用户文档），按前缀断言
// 表达不了这条分界，故逐**事件全名**断言。
//
// TestPlatformR4_NotificationAllDomains sweeps the whole N0 dispatch: every event type
// registered ⊞ in events.md must persist an inbox row, and every ⤳ one must never persist a
// row (frame only). It goes red in both directions — an Emit-tier domain that stops
// persisting, AND a Broadcast-tier domain that starts persisting.
func TestPlatformR4_NotificationAllDomains(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "notif-ws"}).Field(t, "id")
	wc := c.WS(wsID)
	script := writeScriptedMCP(t)

	// 订阅须早于驱动：⤳ 档不落行，故「它确实发生过」的唯一证据就是流上那条帧——没有这个证据，
	// 下面的「无行」断言就是空断言（一个从未发生的事件当然不落行）。
	// Subscribe BEFORE driving: a ⤳ event leaves no row, so its frame is the ONLY evidence it
	// happened at all — without it the no-row assertion below would pass vacuously.
	sNot := wc.Subscribe(t, "notifications")

	fnCreate(t, wc, "notif_fn", "def notif_fn() -> dict:\n    return {}\n")
	hdCreate(t, wc, "notif_hd", map[string]any{
		"description": "d", "initBody": "self.n = 0",
		"methods": []map[string]any{{"name": "m", "body": "return {\"ok\": True}", "description": "m"}},
	})
	agCreate(t, wc, map[string]any{"name": "notif_ag", "description": "d", "prompt": "p"})
	nestedID(t, wc.POST("/api/v1/controls", map[string]any{
		"name": "notif_ctl", "description": "d",
		"inputs":   []map[string]any{{"name": "x", "type": "number"}},
		"branches": []map[string]any{{"port": "out", "when": "true"}},
	}), "control")
	nestedID(t, wc.POST("/api/v1/approvals", map[string]any{
		"name": "notif_apf", "description": "d", "template": "ok?",
	}), "approval")
	wfCreate(t, wc, "notif_wf", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "t", "kind": "trigger", "ref": "trg_x"}},
		{"op": "add_node", "node": map[string]any{"id": "a", "kind": "action", "ref": "fn_x"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "t", "to": "a"}},
	})
	wc.POST("/api/v1/skills", map[string]any{"name": "notif-skill", "description": "d", "body": "b"}).OK(t, nil)
	wc.PUT("/api/v1/memories/notif-mem", map[string]any{"description": "d", "content": "c", "source": "user"}).OK(t, nil)
	// document 横跨两档：建=树刷新回声（⤳），删=破坏性、值得进收件箱（⊞）。两拍都驱动，才能
	// 证明这条**域内**分界是活的。document straddles both tiers — drive create AND delete.
	docID := wc.POST("/api/v1/documents", map[string]any{"name": "notif_doc", "content": "c"}).Field(t, "id")
	wc.DELETE("/api/v1/documents/"+docID).OK(t, nil)
	wc.POST("/api/v1/conversations", map[string]any{"title": "notif conv"}).OK(t, nil)
	wc.PUT("/api/v1/mcp-servers/notifmcp", map[string]any{
		"description": "d", "command": "python3", "args": []string{script},
	}).OK(t, nil)

	// ⊞ Emit 档：落收件箱行 + 推帧（events.md P1「实体面」/P4/P5 各域表）。
	wantInbox := []string{
		"function.created", "handler.created", "agent.created", "control.created",
		"approval.created", "workflow.created", "skill.created", "memory.created",
		"mcp.installed", "document.deleted",
	}
	// ⤳ Broadcast 档：只推帧、**绝不落行**（events.md :88 document 建/改/移 · :98 conversation 全族）。
	wantFrameOnly := []string{"conversation.created", "document.created"}

	// 每条 ⤳ 帧真到达。**顺带把「无行」断言变成无时序缝的硬断言**：Emit 是先 `repo.Save` 落行、
	// 后 `push` 推帧（app/notification/notification.go），故只要帧已到，倘若它走的是 Emit 档，
	// 那条行此刻**必然已经在库里**——无需靠「等久一点」赌它没有迟到。
	// Emit persists the row BEFORE pushing the frame, so observing the frame proves an
	// Emit-tier row would already exist — the absence check below needs no timing slack.
	for _, ty := range wantFrameOnly {
		sNot.WaitFor(t, 30000, ty+" 必须真到达流（否则下面的无行断言是空断言）", ty)
	}

	type notifRow struct {
		ID   string `json:"id"`
		Type string `json:"type"`
		Read bool   `json:"read"`
	}
	var page []notifRow
	listTypes := func() map[string]bool {
		page = nil
		wc.GET("/api/v1/notifications?limit=200").OK(t, &page)
		got := map[string]bool{}
		for _, n := range page {
			got[n.Type] = true
		}
		return got
	}

	// 方向一：⊞ 档全部落行。
	var got map[string]bool
	harness.Eventually(t, 30000, "every Emit-tier(⊞) event persists an inbox row", func() bool {
		got = listTypes()
		for _, w := range wantInbox {
			if !got[w] {
				return false
			}
		}
		return true
	})

	// 方向二：同一份已填满的 list 里，⤳ 档一行都没有。
	for _, w := range wantFrameOnly {
		if got[w] {
			t.Errorf("%s 登记为 ⤳（仅帧、不落行，events.md）——它绝不能落收件箱行；got types=%v", w, got)
		}
	}
	// conversation 是**全族**仅帧：任何 conversation.* 行都是分径破了。
	for ty := range got {
		if strings.HasPrefix(ty, "conversation.") {
			t.Errorf("conversation.* 全族仅帧（events.md :98）——不得有任何收件箱行，found %q", ty)
		}
	}

	// 未读计数 > 0 → 单条已读递减 → read-all 清零。
	var unread struct {
		Unread int `json:"unread"`
	}
	wc.GET("/api/v1/notifications/unread-count").OK(t, &unread)
	if unread.Unread == 0 {
		t.Fatal("unread count must be positive after the burst")
	}
	before := unread.Unread
	wc.POST("/api/v1/notifications/"+page[0].ID+":mark-read", nil).OK(t, nil) // :action(MD5)
	wc.GET("/api/v1/notifications/unread-count").OK(t, &unread)
	if unread.Unread != before-1 {
		t.Fatalf("single mark-read must decrement (want %d, got %d)", before-1, unread.Unread)
	}
	wc.POST("/api/v1/notifications:mark-all-read", nil).OK(t, nil) // 集合级 :action(MD5)
	wc.GET("/api/v1/notifications/unread-count").OK(t, &unread)
	if unread.Unread != 0 {
		t.Fatalf("read-all must zero the unread count, got %d", unread.Unread)
	}
}

// TestPlatformR4_SandboxRuntimesGCDisk: sandbox 治理面——runtimes 列表（python 已在）、
// disk-usage 形状、:gc 跑通、删 runtime 后列表消失（envs 面 W5 已验）。
func TestPlatformR4_SandboxRuntimesGCDisk(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "sbx-ws"}).Field(t, "id")
	wc := c.WS(wsID)

	// 物化一个 env，让 runtime/磁盘面有真实内容。
	fnCreate(t, wc, "sbx_fn", "def sbx_fn() -> dict:\n    return {}\n")

	var runtimes []struct {
		ID   string `json:"id"`
		Kind string `json:"kind"`
	}
	wc.GET("/api/v1/sandbox/runtimes").OK(t, &runtimes)
	pyID := ""
	for _, rt := range runtimes {
		if rt.Kind == "python" {
			pyID = rt.ID
		}
	}
	if pyID == "" {
		t.Fatalf("python runtime must be installed after env materialization: %+v", runtimes)
	}

	var disk map[string]any
	wc.GET("/api/v1/sandbox/disk-usage").OK(t, &disk)
	if len(disk) == 0 {
		t.Fatalf("disk-usage must report a non-empty shape: %v", disk)
	}
	wc.POST("/api/v1/sandbox:gc", nil).OK(t, nil)

	// 引用守卫：env 还挂在 runtime 上时拒删（409）；清掉 env 后删除放行、列表消失。
	wc.Do("DELETE", "/api/v1/sandbox/runtimes/"+pyID, nil).Fail(t, 409, "SANDBOX_ENV_IN_USE")
	var envs []struct {
		ID string `json:"id"`
	}
	wc.GET("/api/v1/sandbox/envs?ownerKind=function").OK(t, &envs)
	for _, e := range envs {
		wc.DELETE("/api/v1/sandbox/envs/"+e.ID).OK(t, nil)
	}
	wc.DELETE("/api/v1/sandbox/runtimes/"+pyID).OK(t, nil)
	wc.GET("/api/v1/sandbox/runtimes").OK(t, &runtimes)
	for _, rt := range runtimes {
		if rt.ID == pyID {
			t.Fatal("deleted runtime must leave the list")
		}
	}
}

// TestPlatformR4_CascadeEveryAssetKind: workspace 级联删除——12 类资产全建、唯一 token
// 全可搜后删 ws：搜索索引全清（重建同名 ws 一无所见）、keeper 不受涟漪。
func TestPlatformR4_CascadeEveryAssetKind(t *testing.T) {
	srv := harness.Start(t)
	mock := harness.NewLLMMock(t)
	_ = mock
	c := srv.Client(t)
	keeperID := c.POST("/api/v1/workspaces", map[string]any{"name": "keeper"}).Field(t, "id")
	doomedID := c.POST("/api/v1/workspaces", map[string]any{"name": "doomed"}).Field(t, "id")
	keeper, doomed := c.WS(keeperID), c.WS(doomedID)
	script := writeScriptedMCP(t)

	// keeper 放一个对照实体。
	fnCreate(t, keeper, "keeper_fn", "def keeper_fn() -> dict:\n    \"\"\"cascadetoken keeper\"\"\"\n    return {}\n")

	// doomed 12 类全建（共享 token "cascadetoken"）。
	fnCreate(t, doomed, "dm_fn", "def dm_fn() -> dict:\n    \"\"\"cascadetoken fn\"\"\"\n    return {}\n")
	hdCreate(t, doomed, "dm_hd", map[string]any{
		"description": "cascadetoken hd", "initBody": "self.n = 0",
		"methods": []map[string]any{{"name": "m", "body": "return {\"ok\": True}", "description": "m"}},
	})
	agCreate(t, doomed, map[string]any{"name": "dm_ag", "description": "cascadetoken ag", "prompt": "p"})
	nestedID(t, doomed.POST("/api/v1/controls", map[string]any{
		"name": "dm_ctl", "description": "cascadetoken ctl",
		"inputs":   []map[string]any{{"name": "x", "type": "number"}},
		"branches": []map[string]any{{"port": "out", "when": "true"}},
	}), "control")
	nestedID(t, doomed.POST("/api/v1/approvals", map[string]any{
		"name": "dm_apf", "description": "cascadetoken apf", "template": "ok?",
	}), "approval")
	doomed.POST("/api/v1/workflows", map[string]any{
		"name": "dm_wf", "description": "cascadetoken wf",
		"ops": []map[string]any{
			{"op": "add_node", "node": map[string]any{"id": "t", "kind": "trigger", "ref": "trg_x"}},
			{"op": "add_node", "node": map[string]any{"id": "a", "kind": "action", "ref": "fn_x"}},
			{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "t", "to": "a"}},
		},
	}).OK(t, nil)
	doomed.POST("/api/v1/triggers", map[string]any{
		"name": "dm_trg", "description": "cascadetoken trg", "kind": "webhook",
		"config": map[string]any{"path": "dm-in", "secret": "s", "signatureAlgo": "hmac-sha256-hex"},
	}).OK(t, nil)
	doomed.POST("/api/v1/skills", map[string]any{"name": "dm-skill", "description": "cascadetoken skill", "body": "b"}).OK(t, nil)
	doomed.PUT("/api/v1/memories/dm-mem", map[string]any{"description": "cascadetoken mem", "content": "c", "source": "user"}).OK(t, nil)
	doomed.POST("/api/v1/documents", map[string]any{"name": "dm_doc", "content": "cascadetoken doc body"}).OK(t, nil)
	doomed.POST("/api/v1/conversations", map[string]any{"title": "cascadetoken conv"}).OK(t, nil)
	doomed.PUT("/api/v1/mcp-servers/dmmcp", map[string]any{
		"description": "cascadetoken mcp", "command": "python3", "args": []string{script},
	}).OK(t, nil)

	// 全部入索后删 ws。
	harness.Eventually(t, 30000, "doomed assets indexed", func() bool {
		return searchPageOf(t, doomed, "q=cascadetoken&limit=50").Total >= 12
	})
	c.DELETE("/api/v1/workspaces/"+doomedID).OK(t, nil)

	// ws 本体 404；keeper 毫发无损且只见自己的对照实体。
	c.Do("GET", "/api/v1/workspaces/"+doomedID, nil).Fail(t, 404, "WORKSPACE_NOT_FOUND")
	p := searchPageOf(t, keeper, "q=cascadetoken&limit=50")
	if p.Total != 1 || len(p.Hits) != 1 || p.Hits[0].Name != "keeper_fn" {
		t.Fatalf("keeper must keep exactly its own entity, got total=%d %+v", p.Total, p.Hits)
	}

	// 同名重建 = 全新空间：12 类一无所见（物理级联清）。
	rebornID := c.POST("/api/v1/workspaces", map[string]any{"name": "doomed"}).Field(t, "id")
	reborn := c.WS(rebornID)
	if n := searchPageOf(t, reborn, "q=cascadetoken&limit=50").Total; n != 0 {
		t.Fatalf("reborn workspace must see zero residue in the index, got %d", n)
	}
	var fns []struct{}
	reborn.GET("/api/v1/functions").OK(t, &fns)
	var convs []struct{}
	reborn.GET("/api/v1/conversations").OK(t, &convs)
	if len(fns) != 0 || len(convs) != 0 {
		t.Fatalf("reborn workspace must list zero assets, got fn=%d conv=%d", len(fns), len(convs))
	}
}
