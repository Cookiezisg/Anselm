// contract_mega_test.go — Phase 3 · D-mega-1：单条端到端跨模块联动链（零 token，llmmock 驱动）。
//
// 现有 testend 全是分域切片（trigger 一支、workflow 一支、agent 一支、search 一支…）。本文件补上
// 唯一一条把它们**串起来全断言**的主链，专门暴露跨模块集成缝：
//
//	webhook trigger（HMAC 验签 + body 作为 fire payload）
//	  → workflow 混合图（trigger + control 分支 + agent + approval + fn action，五种节点 kind）
//	    → control 按 body.amount 路由 big 端 + emit tier=vip（下游 agent 节点消费 gate.tier）
//	      → agent 节点跑通（workspace 默认 agent 模型，llmmock 喂一回合）+ 执行台账溯源 workflow+flowrun
//	        → approval 节点 park → notifications 流 workflow.approval_pending + flowrun-inbox 收件箱
//	          → decide(yes) 续跑 → publish fn action 跑通（执行台账溯源 workflow+flowrun）→ run completed
//	            → 各节点记忆化行（agent 输出 / control emit / publish 输出）
//	              → relation 边：workflow equip 其 control/agent/approval/fn 节点实体 + trigger↔workflow 绑定
//	                → search：workflow/agent/fn 三实体标脏后可搜（name 命中各自 id）
//	                  → entities 流：workflow build 镜像帧 + flowrun 逐节点 run tick 帧（ephemeral、载 flowrunId）
//	                    → trigger 活动台账：fired=true（webhook 真触发落账）
//
// 断言 = 各域 reference（events.md / domains/{trigger,workflow,agent,relation,search}.md）说的线缆事实。
// helper 一律 megaC_ 前缀，绝不碰既有 helper（agentSetup / fnCreate / agCreate / wfCreate / trgCreate /
// searchQ / harness.Eventually / SSE.WaitFor 直接复用）。时序全走 Eventually / WaitFor，无裸 sleep 断言。
package scenarios

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// megaC_fireWebhook posts a HMAC-signed JSON body to a webhook trigger's mounted path (the real
// inbound path — no workspace header, exactly like an external caller). Returns the HTTP status.
//
// megaC_fireWebhook 向 webhook trigger 的挂载路径 POST 一个 HMAC 签名的 JSON body（真入站路径——不带
// workspace 头，像外部调用方一样）。返回 HTTP 状态码。
func megaC_fireWebhook(t *testing.T, baseURL, trgID, path, secret string, body []byte) int {
	t.Helper()
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(body)
	sig := "sha256=" + hex.EncodeToString(mac.Sum(nil))
	req, err := http.NewRequest("POST", baseURL+"/api/v1/webhooks/"+trgID+"/"+path, strings.NewReader(string(body)))
	if err != nil {
		t.Fatalf("megaC_fireWebhook: new request: %v", err)
	}
	req.Header.Set("X-Hub-Signature-256", sig)
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("megaC_fireWebhook: do: %v", err)
	}
	resp.Body.Close()
	return resp.StatusCode
}

// megaC_awaitRunID polls the flowruns list for the workflow until one run exists and returns its id
// (the webhook path materializes the run asynchronously — the accept response carries no run id).
//
// megaC_awaitRunID 轮询 workflow 的 flowruns 列表直到出现一个 run 并返回其 id（webhook 路径异步材化
// run——accept 响应不带 run id）。
func megaC_awaitRunID(t *testing.T, wc *harness.Client, wfID string) string {
	t.Helper()
	var runID string
	harness.Eventually(t, 20000, "webhook materializes a flowrun", func() bool {
		// The flowruns list is a Paged bare array (data = [...]), newest-first.
		// flowruns 列表是 Paged 裸数组（data = [...]），最新优先。
		var rows []struct {
			ID string `json:"id"`
		}
		r := wc.GET("/api/v1/flowruns?workflowId=" + wfID)
		if r.Status != 200 {
			return false
		}
		if json.Unmarshal(r.Data, &rows) != nil || len(rows) == 0 {
			return false
		}
		runID = rows[0].ID
		return runID != ""
	})
	return runID
}

// megaC_run fetches a flowrun's (status, nodes-json).
//
// megaC_run 取一个 flowrun 的（状态、节点 JSON）。
func megaC_run(t *testing.T, wc *harness.Client, runID string) (string, string) {
	t.Helper()
	var got struct {
		Flowrun struct {
			Status string `json:"status"`
		} `json:"flowrun"`
		Nodes json.RawMessage `json:"nodes"`
	}
	r := wc.GET("/api/v1/flowruns/" + runID)
	if r.Status != 200 {
		return "", ""
	}
	_ = json.Unmarshal(r.Data, &got)
	return got.Flowrun.Status, string(got.Nodes)
}

// megaC_ledger returns the (triggeredBy, flowrunId) of the single execution row for a function or
// agent, asserting exactly one row exists.
//
// megaC_ledger 返回 function/agent 唯一一条执行行的（triggeredBy, flowrunId），并断言恰一行。
func megaC_fnLedger(t *testing.T, wc *harness.Client, fnID string) (string, string) {
	t.Helper()
	var page struct {
		Executions []struct {
			TriggeredBy string `json:"triggeredBy"`
			FlowrunID   string `json:"flowrunId"`
		} `json:"executions"`
	}
	wc.GET("/api/v1/functions/"+fnID+"/executions").OK(t, &page)
	if len(page.Executions) != 1 {
		t.Fatalf("function %s must have exactly one execution, got %d", fnID, len(page.Executions))
	}
	return page.Executions[0].TriggeredBy, page.Executions[0].FlowrunID
}

func megaC_agLedger(t *testing.T, wc *harness.Client, agID string) (string, string) {
	t.Helper()
	var page struct {
		Executions []struct {
			TriggeredBy string `json:"triggeredBy"`
			FlowrunID   string `json:"flowrunId"`
		} `json:"executions"`
	}
	wc.GET("/api/v1/agents/"+agID+"/executions").OK(t, &page)
	if len(page.Executions) != 1 {
		t.Fatalf("agent %s must have exactly one execution, got %d", agID, len(page.Executions))
	}
	return page.Executions[0].TriggeredBy, page.Executions[0].FlowrunID
}

// megaC_neighborhood returns the raw relation-neighborhood JSON for one entity at depth 1.
//
// megaC_neighborhood 返回一个实体 depth=1 的关系邻域原始 JSON。
func megaC_neighborhood(t *testing.T, wc *harness.Client, kind, id string) string {
	t.Helper()
	r := wc.GET("/api/v1/relations/neighborhood?kind=" + kind + "&id=" + id + "&depth=1")
	if r.Status != 200 {
		t.Fatalf("neighborhood %s/%s: %d %s", kind, id, r.Status, r.Raw)
	}
	return string(r.Data)
}

// megaC_searchHit reports whether searching `name` (scoped to `types`) returns a hit for `id`.
//
// megaC_searchHit 报告以 name（限 types）搜索是否命中 id。
func megaC_searchHit(t *testing.T, wc *harness.Client, name, types, id string) bool {
	t.Helper()
	p := searchQ(t, wc, "q="+name+"&types="+types+"&limit=10")
	for _, h := range p.Hits {
		if h.EntityID == id {
			return true
		}
	}
	return false
}

// TestContractMega_TriggerToNotificationChain walks the whole cross-module chain in one run.
//
// TestContractMega_TriggerToNotificationChain 一次 run 走完整条跨模块链。
func TestContractMega_TriggerToNotificationChain(t *testing.T) {
	// agentSetup binds a workspace + registers the llmmock as an openai key + sets BOTH the
	// dialogue and agent default models — the agent node needs the agent default model.
	// agentSetup 绑 workspace + 注册 llmmock 为 openai key + 设 dialogue 与 agent 两个默认模型
	// ——agent 节点要用 agent 默认模型。
	wc, mock := agentSetup(t)

	// Subscribe the entities + notifications streams up front so every build/run/notify frame
	// (including the workflow's create-time build mirror) is collected from the very start.
	// 提前订 entities + notifications 流，使每个 build/run/notify 帧（含 workflow 建时 build 镜像）
	// 从头收齐。
	sEnt := wc.Subscribe(t, "entities")
	sNot := wc.Subscribe(t, "notifications")

	// ── Build the five node-kind entities the mixed graph equips ──────────────────────
	// fn action（publish，读 approval 决策）+ fn action（small，未选端）。单 token 名便于精确搜。
	pubFn := fnCreate(t, wc, "megapublish",
		"def f(decision: str) -> dict:\n    return {\"published\": decision}\n")
	smallFn := fnCreate(t, wc, "megasmall",
		"def f() -> dict:\n    return {\"ran\": \"small\"}\n")

	// control：按 body.amount 路由；big 端 emit tier=vip。
	ctlID := wc.POST("/api/v1/controls", map[string]any{
		"name":   "mega_router",
		"inputs": []map[string]any{{"name": "amount", "type": "number"}},
		"branches": []map[string]any{
			{"port": "big", "when": "input.amount > 100.0", "emit": map[string]string{"tier": "'vip'"}},
			{"port": "small", "when": "true"},
		},
	}).Field(t, "id")

	// agent：混合图里的 worker 节点，读 control emit 的 tier。
	agID := agCreate(t, wc, map[string]any{
		"name": "MegaWorker", "description": "runs inside the mega pipeline", "prompt": "Do the task.",
	})

	// approval：park 门（渲染 body.amount）。
	apfID := wc.POST("/api/v1/approvals", map[string]any{
		"name": "mega_gate", "template": "approve spend {{ input.amt }}?", "allowReason": true,
	}).Field(t, "id")

	// webhook trigger：HMAC 验签、body 进 fire payload。
	secret := "megasecret"
	hookPath := "mega-in"
	trgID := trgCreate(t, wc, "mega_hook", "webhook", map[string]any{
		"path": hookPath, "secret": secret, "signatureAlgo": "hmac-sha256-hex",
	})

	// ── The mixed graph (5 node kinds): trigger → control ─┬─big→ agent → approval → action(publish)
	//                                                       └─small→ action(small, unchosen) ──
	wfID := wfCreate(t, wc, "megapipeline", []map[string]any{
		{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": trgID}},
		{"op": "add_node", "node": map[string]any{"id": "gate", "kind": "control", "ref": ctlID,
			"input": map[string]any{"amount": "start.body.amount"}}},
		{"op": "add_node", "node": map[string]any{"id": "worker", "kind": "agent", "ref": agID,
			"input": map[string]any{"task": "gate.tier"}}},
		{"op": "add_node", "node": map[string]any{"id": "human", "kind": "approval", "ref": apfID,
			"input": map[string]any{"amt": "start.body.amount"}}},
		{"op": "add_node", "node": map[string]any{"id": "publish", "kind": "action", "ref": pubFn,
			"input": map[string]any{"decision": "human.decision"}}},
		{"op": "add_node", "node": map[string]any{"id": "small", "kind": "action", "ref": smallFn}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "gate"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e2", "from": "gate", "to": "worker", "fromPort": "big"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e3", "from": "gate", "to": "small", "fromPort": "small"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e4", "from": "worker", "to": "human"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e5", "from": "human", "to": "publish", "fromPort": "yes"}},
	})
	wc.POST("/api/v1/workflows/"+wfID+":activate", map[string]any{}).OK(t, nil)

	// entities 流：build 镜像帧真到达（function env 物化每次 attempt 写一行 build 终端——见 function.go
	// 的 NodeBuild；workflow/control/agent/approval 的 REST 建不发 build，build 镜像只来自 env 物化或
	// chat loop 的 create/edit tool，故锚在 publish fn 上验此面）。
	sEnt.WaitFor(t, 20000, "function build-mirror frame on entities stream", `"type":"build"`, pubFn)

	// The agent node's single turn must be queued BEFORE the run reaches it (FIFO per model id).
	// agent 节点的一回合必须在 run 抵达前入队（按 model id FIFO）。
	mock.Enqueue(agModel, harness.LLMTurn{Text: "mega-agent-output"})

	// ── Fire the webhook (amount>100 → big path) ──────────────────────────────────────
	// 坏签先探一枪：必 401、绝不触发（webhook 安全门未破，run 仍是干净起点）。
	if code := megaC_badSig(t, wc.BaseURL(), trgID, hookPath); code != 401 {
		t.Fatalf("bad HMAC signature must 401, got %d", code)
	}
	body := []byte(`{"amount":500,"note":"mega"}`)
	if code := megaC_fireWebhook(t, wc.BaseURL(), trgID, hookPath, secret, body); code >= 300 {
		t.Fatalf("good HMAC signature must accept, got %d", code)
	}

	runID := megaC_awaitRunID(t, wc, wfID)

	// ── Park half: approval parks; the summons rides notifications + the inbox lists it ──
	// notifications 流：workflow.approval_pending durable 信号唤人（载 flowrunId）。
	sNot.WaitFor(t, 15000, "approval_pending summons on notifications stream", "workflow.approval_pending", runID)

	// flowrun-inbox：parked 节点登记（human 节点等决策）。
	harness.Eventually(t, 15000, "parked node lands in the flowrun inbox", func() bool {
		var inbox struct {
			Parked []struct {
				FlowRunID string `json:"flowrunId"`
				NodeID    string `json:"nodeId"`
			} `json:"parked"`
		}
		wc.GET("/api/v1/flowrun-inbox").OK(t, &inbox)
		for _, p := range inbox.Parked {
			if p.FlowRunID == runID && p.NodeID == "human" {
				return true
			}
		}
		return false
	})

	// entities 流：flowrun 逐节点 run tick 帧（ephemeral、node.type=run、载本 run 的 flowrunId）。
	tick := sEnt.WaitFor(t, 15000, "flowrun node tick on entities stream", `"type":"run"`, runID)
	tf := protoC_parseFrame(tick.Data)
	if tf.Seq != 0 {
		t.Fatalf("flowrun tick must be EPHEMERAL (seq 0), got seq=%d", tf.Seq)
	}
	if tf.Scope.Kind != "workflow" || tf.Scope.ID != wfID {
		t.Fatalf("flowrun tick must be workflow-scoped to %s, got %s:%s", wfID, tf.Scope.Kind, tf.Scope.ID)
	}

	// agent 节点在 park 前已跑完 → 台账溯源 workflow + 本 flowrun（且恰一行）。
	if by, frn := megaC_agLedger(t, wc, agID); by != "workflow" || frn != runID {
		t.Fatalf("agent execution provenance wrong: triggeredBy=%s flowrunId=%s (want workflow/%s)", by, frn, runID)
	}

	// publish fn 尚未跑（还 parked）——溯源断言留到 decide 之后。此刻 fn 台账应为空。
	var pubPre struct {
		Executions []json.RawMessage `json:"executions"`
	}
	wc.GET("/api/v1/functions/"+pubFn+"/executions").OK(t, &pubPre)
	if len(pubPre.Executions) != 0 {
		t.Fatalf("publish fn must not run before the approval decision, got %d executions", len(pubPre.Executions))
	}

	// ── Decide half: approve → resume through publish → run completes ───────────────────
	wc.POST("/api/v1/flowruns/"+runID+"/approvals/human:decide",
		map[string]any{"decision": "yes", "reason": "ship it"}).OK(t, nil)

	var finalNodes string
	harness.Eventually(t, 25000, "run completes after the approval decision", func() bool {
		st, nodes := megaC_run(t, wc, runID)
		finalNodes = nodes
		return st == "completed"
	})

	// ── Memoized node results: control emit (vip) + agent output + publish output; the
	// unchosen small branch never ran. 记忆化行：control emit + agent 输出 + publish 输出；
	// 未选 small 端从未跑。
	if !strings.Contains(finalNodes, `"tier":"vip"`) {
		t.Fatalf("control emit tier=vip must be memoized: %s", finalNodes)
	}
	if !strings.Contains(finalNodes, "mega-agent-output") {
		t.Fatalf("agent node output must be memoized on its node row: %s", finalNodes)
	}
	if !strings.Contains(finalNodes, `"published":"yes"`) {
		t.Fatalf("publish fn output must be memoized (decision routed through): %s", finalNodes)
	}
	if strings.Contains(finalNodes, `"ran":"small"`) {
		t.Fatalf("unchosen small branch must NOT run: %s", finalNodes)
	}

	// ── Audit provenance: publish fn now has exactly one execution triggered by workflow+flowrun ──
	if by, frn := megaC_fnLedger(t, wc, pubFn); by != "workflow" || frn != runID {
		t.Fatalf("publish fn provenance wrong: triggeredBy=%s flowrunId=%s (want workflow/%s)", by, frn, runID)
	}

	// ── Relation edges: the workflow equips its mixed node entities; trigger↔workflow bind ──
	harness.Eventually(t, 15000, "workflow equip edges span all node kinds", func() bool {
		n := megaC_neighborhood(t, wc, "workflow", wfID)
		return strings.Contains(n, ctlID) && strings.Contains(n, agID) &&
			strings.Contains(n, apfID) && strings.Contains(n, pubFn) && strings.Contains(n, trgID)
	})
	harness.Eventually(t, 15000, "trigger-workflow binding edge", func() bool {
		return strings.Contains(megaC_neighborhood(t, wc, "trigger", trgID), wfID)
	})

	// ── Search: the workflow / agent / publish fn are all indexed and hit by name ──────
	harness.Eventually(t, 20000, "workflow/agent/fn searchable by name", func() bool {
		return megaC_searchHit(t, wc, "megapipeline", "workflow", wfID) &&
			megaC_searchHit(t, wc, "MegaWorker", "agent", agID) &&
			megaC_searchHit(t, wc, "megapublish", "function", pubFn)
	})

	// ── Trigger activation ledger: the webhook fire is booked (fired=true) ──────────────
	harness.Eventually(t, 10000, "webhook fire recorded in the activation ledger", func() bool {
		r := wc.GET("/api/v1/triggers/" + trgID + "/activations")
		return r.Status == 200 && strings.Contains(string(r.Data), `"fired":true`)
	})
}

// megaC_badSig posts a body under a deliberately wrong HMAC signature to prove the webhook security
// gate rejects it (401) before any run materializes.
//
// megaC_badSig 用故意错误的 HMAC 签名 POST，证明 webhook 安全门在任何 run 材化前拒（401）。
func megaC_badSig(t *testing.T, baseURL, trgID, path string) int {
	t.Helper()
	req, err := http.NewRequest("POST", baseURL+"/api/v1/webhooks/"+trgID+"/"+path,
		strings.NewReader(`{"amount":500}`))
	if err != nil {
		t.Fatalf("megaC_badSig: new request: %v", err)
	}
	req.Header.Set("X-Hub-Signature-256", "sha256=deadbeef")
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("megaC_badSig: do: %v", err)
	}
	resp.Body.Close()
	return resp.StatusCode
}
