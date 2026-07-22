// contract_p4b_rail_test.go — Phase 4b：rail 派生字段的 agent 触发变体（E2-rail）。
//
// 三条派生字段的真空补课，全部 llmmock 确定性、零 token：
//
//	awaitingInput —— 由 ask_user（KindAsk）与 danger 门（KindDanger）的 accept/decline/deny 完整链点亮/清除
//	                  （既有 TestChat_RailAwaitingInput 只锁 danger+approve）。
//	hasUnread     —— 长流 + subagent 完成点亮；**取消/出错终态不算**（既有 TestChat_RailUnread 只锁 completed）。
//	isGenerating  —— :cancel 清蓝点；kill-9+restart 后无永久蓝点（派生自内存队列/sweep，重启即无）。
//
// 断言以 conversation.md（isGenerating/awaitingInput/hasUnread 三字段语义）+ humanloop.go（KindAsk/KindDanger、
// Decision*）+ host.go（unread = status==completed）为契约事实源。
package scenarios

import (
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// ─────────────────────────────────────────────────────────────────────────────
// E2-rail-1: awaitingInput —— ask_user（KindAsk）+ danger 门 deny 的补空变体。
// ─────────────────────────────────────────────────────────────────────────────

// TestP4bRail_AwaitingInputAskGate: the ask_user tool (KindAsk, distinct from the danger gate)
// lights the rail's awaitingInput while it blocks on the human; both accept (with an answer) and
// decline clear it. The existing TestChat_RailAwaitingInput only locks the KindDanger+approve arm —
// this covers the ask-tool kind end to end (blocked turn → GET interactions reports kind=ask /
// tool=ask_user → resolve clears the dot and the turn completes).
//
// TestP4bRail_AwaitingInputAskGate：ask_user 工具（KindAsk，区别于 danger 门）阻塞等人时点亮 rail 的
// awaitingInput；accept（带答案）与 decline 都清之。既有测只锁 KindDanger+approve——本测补 ask 这一 kind 的完整链
// （阻塞回合 → GET interactions 报 kind=ask/tool=ask_user → resolve 清点、回合完成）。
func TestP4bRail_AwaitingInputAskGate(t *testing.T) {
	wc, mock := chatSetup(t, false)

	type pend struct {
		ToolCallID string `json:"toolCallId"`
		Kind       string `json:"kind"`
		Tool       string `json:"tool"`
	}
	// waitAsk drives one conversation whose model calls ask_user, blocks, and asserts the rail dot +
	// the pending interaction's shape; returns the conversation id, the assistant turn id, and the
	// tool_call id for the caller to resolve.
	// waitAsk 驱动一个对话：模型调 ask_user、阻塞，断言 rail 点 + 待决交互形状；返对话 id、assistant 回合 id、
	// tool_call id 供调用方解决。
	waitAsk := func(title, sendText string) (convID, midID, tcID string) {
		convID = convCreate(t, wc, title)
		mock.Enqueue(dlgModel,
			harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "ask_user",
				Args: fw(map[string]any{"message": "Which environment?", "options": []string{"staging", "prod"}})}}},
			harness.LLMTurn{Text: "acted on the answer"},
		)
		midID = sendMsg(t, wc, convID, sendText)

		var pending []pend
		harness.Eventually(t, 15000, "ask_user interaction pends", func() bool {
			pending = nil
			wc.GET("/api/v1/conversations/"+convID+"/interactions").OK(t, &pending)
			return len(pending) == 1
		})
		// The ask surfaces as KindAsk on the ask_user tool — NOT a danger gate (self-reported safe).
		// ask 以 KindAsk / ask_user 露出——非 danger 门（自报 safe）。
		if pending[0].Kind != "ask" || pending[0].Tool != "ask_user" {
			t.Fatalf("ask_user must pend as kind=ask/tool=ask_user, got %+v", pending[0])
		}
		// While it blocks, the rail row reports awaitingInput=true. 阻塞期间 rail 行 awaitingInput=true。
		harness.Eventually(t, 5000, "rail awaitingInput true while ask_user blocks", func() bool {
			row, ok := findConv(listConvs(t, wc), convID)
			return ok && row.AwaitingInput
		})
		return convID, midID, pending[0].ToolCallID
	}

	// ── accept path: the answer is fed back, the dot clears, the turn completes. ──
	conv1, mid1, tc1 := waitAsk("ask accept", "deploy somewhere")
	wc.POST("/api/v1/conversations/"+conv1+"/interactions/"+tc1,
		map[string]any{"action": "accept", "answer": "staging"}).OK(t, nil)
	if turn := waitTurn(t, wc, conv1, mid1, 20000); turn.Status != "completed" {
		t.Fatalf("the accepted turn must complete, got %s err=%s", turn.Status, turn.ErrorMessage)
	}
	harness.Eventually(t, 8000, "rail awaitingInput false after accept", func() bool {
		row, ok := findConv(listConvs(t, wc), conv1)
		return ok && !row.AwaitingInput
	})

	// ── decline path: refusing to answer also clears the dot. ──
	conv2, _, tc2 := waitAsk("ask decline", "deploy again")
	wc.POST("/api/v1/conversations/"+conv2+"/interactions/"+tc2,
		map[string]any{"action": "decline"}).OK(t, nil)
	harness.Eventually(t, 8000, "rail awaitingInput false after decline", func() bool {
		row, ok := findConv(listConvs(t, wc), conv2)
		return ok && !row.AwaitingInput
	})
}

// TestP4bRail_AwaitingInputDangerDeny: the danger-gate DENY arm clears the rail's awaitingInput
// (the existing TestChat_RailAwaitingInput only exercises approve). A self-reported-dangerous tool
// blocks → awaitingInput=true → deny → the dot clears and the turn still completes (the denial is
// fed back to the model as the tool result).
//
// TestP4bRail_AwaitingInputDangerDeny：danger 门的 DENY 臂清 rail 的 awaitingInput（既有测只走 approve）。
// 自报危险工具阻塞 → awaitingInput=true → deny → 点清、回合仍完成（拒绝作为工具结果回喂）。
func TestP4bRail_AwaitingInputDangerDeny(t *testing.T) {
	wc, mock := chatSetup(t, false)
	fnID := fnCreate(t, wc, "deny_probe", "def go() -> dict:\n    return {\"ok\": True}\n")
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{ID: "call_deny", Name: "run_function", Args: map[string]any{
			"functionId": fnID, "args": map[string]any{},
			"summary": "Run the gated probe", "danger": "dangerous", "execution_group": 1,
		}}}},
		harness.LLMTurn{Text: "understood, not doing it"},
	)

	convID := convCreate(t, wc, "danger deny")
	mid := sendMsg(t, wc, convID, "do the dangerous thing")

	var pending []struct {
		ToolCallID string `json:"toolCallId"`
		Kind       string `json:"kind"`
	}
	harness.Eventually(t, 15000, "danger interaction pends", func() bool {
		pending = nil
		wc.GET("/api/v1/conversations/"+convID+"/interactions").OK(t, &pending)
		return len(pending) == 1
	})
	if pending[0].Kind != "danger" {
		t.Fatalf("a self-reported-dangerous tool must pend as kind=danger, got %+v", pending[0])
	}
	harness.Eventually(t, 5000, "rail awaitingInput true while the danger gate blocks", func() bool {
		row, ok := findConv(listConvs(t, wc), convID)
		return ok && row.AwaitingInput
	})

	// Deny → the dot clears (broker pending drops → derived AwaitingInput re-reads false). 拒绝 → 点清。
	wc.POST("/api/v1/conversations/"+convID+"/interactions/"+pending[0].ToolCallID,
		map[string]any{"action": "deny"}).OK(t, nil)
	if turn := waitTurn(t, wc, convID, mid, 20000); turn.Status != "completed" {
		t.Fatalf("a denied turn must still complete, got %s", turn.Status)
	}
	harness.Eventually(t, 8000, "rail awaitingInput false after deny", func() bool {
		row, ok := findConv(listConvs(t, wc), convID)
		return ok && !row.AwaitingInput
	})
	// Deny must NOT run the gated function (regression guard against phantom execution). 拒绝不得跑工具。
	var page struct {
		Aggregates struct {
			OKCount int `json:"okCount"`
		} `json:"aggregates"`
	}
	wc.GET("/api/v1/functions/"+fnID+"/executions").OK(t, &page)
	if page.Aggregates.OKCount != 0 {
		t.Fatalf("deny must not run the gated tool, executions=%+v", page.Aggregates)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// E2-rail-2: hasUnread —— subagent 完成变体 + 取消/出错终态不算的负向锁。
// ─────────────────────────────────────────────────────────────────────────────

// TestP4bRail_UnreadSubagentCompletes: a turn that delegates to a subagent (Task) and completes
// flags the rail's hasUnread — the PARENT's completed finalize is the one that sets unread (the
// nested sub-messages complete inside the parent tool, they don't double-count). POST :seen clears
// it. The existing TestChat_RailUnread only covers a plain single-turn reply — this is the
// long-stream/subagent variant.
//
// TestP4bRail_UnreadSubagentCompletes：派 subagent（Task）并完成的回合点亮 rail 的 hasUnread——由**父**回合的
// completed 终态置未读（嵌套 sub-message 在父工具内完成、不重复计）。POST :seen 清之。既有测只覆盖单回合朴素回复
// ——本测补长流/subagent 变体。
func TestP4bRail_UnreadSubagentCompletes(t *testing.T) {
	wc, mock := chatSetup(t, false)
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "Subagent",
			Args: fw(map[string]any{"subagent_type": "general-purpose", "prompt": "Reply exactly SUBDONE-42."})}}},
		harness.LLMTurn{Text: "SUBDONE-42"},                        // the sub-run's turn. 子运行回合。
		harness.LLMTurn{Text: "the subagent finished: SUBDONE-42"}, // parent finalize. 父回合收尾。
	)

	convID := convCreate(t, wc, "subagent unread")
	mid := sendMsg(t, wc, convID, "delegate then report")
	if turn := waitTurn(t, wc, convID, mid, 40000); turn.Status != "completed" {
		t.Fatalf("subagent parent turn must complete, got %s err=%s", turn.Status, turn.ErrorMessage)
	}

	// The completed subagent turn flags unread on the rail (and isGenerating is off). 完成即 hasUnread=true。
	harness.Eventually(t, 10000, "a completed subagent turn flags the conversation unread", func() bool {
		row, ok := findConv(listConvs(t, wc), convID)
		return ok && row.HasUnread && !row.IsGenerating
	})
	// Exactly one sub-message persisted (proves the subagent truly ran, not a plain reply). 恰一条 sub-message。
	var msgs []struct {
		SubagentID string `json:"subagentId"`
	}
	wc.GET("/api/v1/conversations/"+convID+"/messages?limit=50").OK(t, &msgs)
	hasSub := false
	for _, m := range msgs {
		if m.SubagentID != "" {
			hasSub = true
		}
	}
	if !hasSub {
		t.Fatal("the subagent variant must persist ≥1 sub-message (else it's not the subagent path)")
	}
	// :seen clears it (persisted column, cold re-read confirms). :seen 清之（持久列，冷读确认）。
	wc.POST("/api/v1/conversations/"+convID+":seen", nil).OK(t, nil)
	if row, ok := findConv(listConvs(t, wc), convID); !ok || row.HasUnread {
		t.Fatalf(":seen must clear hasUnread after a subagent turn (found=%v hasUnread=%v)", ok, row.HasUnread)
	}
}

// TestP4bRail_UnreadCancelledStaysSeen: a CANCELLED terminal must NOT flag hasUnread — a cancelled
// reply is "not a reply to read" (host.go: unread = status==completed only), and the user who just
// cancelled it has by definition seen the thread. Contrast with TestChat_RailUnread's completed→true.
//
// TestP4bRail_UnreadCancelledStaysSeen：**取消**终态不得点亮 hasUnread——取消的回复「不是待读回复」（host.go：
// unread 仅 status==completed），且刚取消它的用户已看过线程。与既有 completed→true 形成对照。
func TestP4bRail_UnreadCancelledStaysSeen(t *testing.T) {
	wc, mock := chatSetup(t, false)
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "a long stalled reply that gets cancelled......", StallMS: 8000})

	sse := wc.Subscribe(t, "messages")
	convID := convCreate(t, wc, "cancelled not unread")
	mid := sendMsg(t, wc, convID, "talk slowly then i cancel")
	sse.WaitFor(t, 10000, "the stalled reply starts streaming", "a long stalled")

	wc.POST("/api/v1/conversations/"+convID+":cancel", nil)
	if turn := waitTurn(t, wc, convID, mid, 15000); turn.Status != "cancelled" {
		t.Fatalf("the turn must land cancelled, got %s", turn.Status)
	}
	// A cancelled terminal reached, yet the rail stays seen. 到了取消终态，rail 仍已读。
	harness.Eventually(t, 8000, "isGenerating clears after cancel", func() bool {
		row, ok := findConv(listConvs(t, wc), convID)
		return ok && !row.IsGenerating
	})
	if row, ok := findConv(listConvs(t, wc), convID); !ok || row.HasUnread {
		t.Fatalf("a cancelled terminal must not flag hasUnread (found=%v hasUnread=%v)", ok, row.HasUnread)
	}
}

// TestP4bRail_UnreadErrorStaysSeen: an ERROR terminal must NOT flag hasUnread (same rule as cancel).
// A fresh workspace with NO dialogue model errors the turn immediately with a configuration code —
// a fast, retry-free error terminal — and the rail must still read hasUnread=false.
//
// TestP4bRail_UnreadErrorStaysSeen：**出错**终态不得点亮 hasUnread（同取消规则）。全新未配 dialogue 模型的
// workspace 即刻以配置类错误码报错——快、无重试的出错终态——rail 仍须 hasUnread=false。
func TestP4bRail_UnreadErrorStaysSeen(t *testing.T) {
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": "err-unread"}).OK(t, nil)
	wc := c.WS(ws.Field(t, "id"))

	convID := convCreate(t, wc, "error not unread")
	mid := sendMsg(t, wc, convID, "answer with no model configured")
	turn := waitTurn(t, wc, convID, mid, 20000)
	if turn.Status == "completed" || turn.ErrorCode == "" {
		t.Fatalf("an unconfigured turn must error terminally with a code, got %s code=%q", turn.Status, turn.ErrorCode)
	}
	// The turn reached an error terminal, yet the rail stays seen. 到了出错终态，rail 仍已读。
	if row, ok := findConv(listConvs(t, wc), convID); !ok || row.HasUnread {
		t.Fatalf("an error terminal must not flag hasUnread (found=%v hasUnread=%v status=%s)", ok, row.HasUnread, turn.Status)
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// E2-rail-3: isGenerating —— :cancel 清蓝点 + kill-9/restart 无永久残留。
// ─────────────────────────────────────────────────────────────────────────────

// TestP4bRail_GeneratingCancelClearsDot: an in-flight turn reports isGenerating=true on the rail
// (List + Get); :cancel drops the blue dot (isGenerating derives from the in-memory queue — the
// cancelled turn is no longer running/queued). TestChat_CancelAndStreamConflict locks the turn's
// cancelled STATUS but never the derived rail dot clearing — that is this test.
//
// TestP4bRail_GeneratingCancelClearsDot：在途回合 rail 报 isGenerating=true（List+Get）；:cancel 落下蓝点
// （isGenerating 派生自内存队列——取消的回合已不在跑/排队）。既有测锁回合 cancelled 状态、从未锁派生 rail 点清除
// ——本测补此。
func TestP4bRail_GeneratingCancelClearsDot(t *testing.T) {
	wc, mock := chatSetup(t, false)
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "streaming and about to be cancelled......", StallMS: 8000})

	sse := wc.Subscribe(t, "messages")
	convID := convCreate(t, wc, "generating cancel")
	mid := sendMsg(t, wc, convID, "talk slowly")
	sse.WaitFor(t, 10000, "the stalled reply starts streaming", "streaming and about")

	// In-flight: the rail dot is on (List and Get both derive it). 在途：List 与 Get 都派生蓝点。
	harness.Eventually(t, 5000, "rail isGenerating true while streaming", func() bool {
		row, ok := findConv(listConvs(t, wc), convID)
		return ok && row.IsGenerating
	})
	var detail struct {
		IsGenerating bool `json:"isGenerating"`
	}
	wc.GET("/api/v1/conversations/"+convID).OK(t, &detail)
	if !detail.IsGenerating {
		t.Fatal("Get must also derive isGenerating=true while streaming")
	}

	// :cancel → the turn lands cancelled and the derived dot clears. :cancel → 回合取消、派生点清。
	wc.POST("/api/v1/conversations/"+convID+":cancel", nil)
	if turn := waitTurn(t, wc, convID, mid, 15000); turn.Status != "cancelled" {
		t.Fatalf("the cancelled turn must persist as cancelled, got %s", turn.Status)
	}
	harness.Eventually(t, 8000, "rail isGenerating false after cancel", func() bool {
		row, ok := findConv(listConvs(t, wc), convID)
		if !ok || row.IsGenerating {
			return false
		}
		wc.GET("/api/v1/conversations/"+convID).OK(t, &detail)
		return !detail.IsGenerating
	})
}

// TestP4bRail_GeneratingNoResidueAfterCrash: isGenerating derives from in-memory state / the boot
// sweep — never a persisted column — so a hard crash mid-stream leaves NO permanent blue dot. An
// in-flight turn reports isGenerating=true; after kill-9 + restart on the same data dir, the rail
// row reads isGenerating=false (the in-memory queue is gone) and the swept orphan is cancelled.
// TestContractChat_CrashSweepOrphans locks the swept message STATUS; this locks the rail-derived
// isGenerating angle (no forever-spinning dot).
//
// TestP4bRail_GeneratingNoResidueAfterCrash：isGenerating 派生自内存态/boot sweep——绝非持久列——故流式中硬崩溃
// 不留永久蓝点。在途回合 isGenerating=true；同目录 kill-9+restart 后，rail 行 isGenerating=false（内存队列已没）、
// 被扫孤儿为 cancelled。既有崩溃测锁被扫 message 状态；本测锁 rail 派生 isGenerating 角度（无永久转圈点）。
func TestP4bRail_GeneratingNoResidueAfterCrash(t *testing.T) {
	srv, wc, mock, wsID, _ := chatC_setup(t, false)
	// 8s stall keeps the turn in-flight through the kill (WaitDumps confirms arrival, the kill lands
	// ~2s later) WITHOUT the mock's Close blocking on a 60s handler drain at cleanup.
	// 8s stall 足以让回合在 kill 时仍在飞（WaitDumps 确认到达、kill 约 2s 后落），又不让 mock 的 Close 在清理时等 60s 抽干。
	mock.Enqueue(dlgModel, harness.LLMTurn{Text: "doomed stalled stream that never finishes......", StallMS: 8000})

	convID := convCreate(t, wc, "crash generating")
	mid := sendMsg(t, wc, convID, "stall then die")
	mock.WaitDumps(t, dlgModel, 1, 10000) // the generation is genuinely in flight. 生成确已在飞。

	// Before the crash: the rail dot is on. 崩溃前：rail 蓝点亮。
	harness.Eventually(t, 5000, "rail isGenerating true while streaming", func() bool {
		row, ok := findConv(listConvs(t, wc), convID)
		return ok && row.IsGenerating
	})

	srv.Kill9(t)
	srv.Restart(t)
	wc2 := srv.Client(t).WS(wsID)

	// After crash+restart: the swept orphan is cancelled AND the rail reads isGenerating=false (the
	// in-memory queue died with the process — no forever-spinning dot). 崩溃重启后：孤儿 cancelled + rail 无蓝点。
	harness.Eventually(t, 15000, "boot reconciliation cancels the orphan", func() bool {
		for _, m := range listMsgs(t, wc2, convID) {
			if m.ID == mid {
				return m.Status == "cancelled"
			}
		}
		return false
	})
	if row, ok := findConv(listConvs(t, wc2), convID); !ok || row.IsGenerating {
		t.Fatalf("no permanent blue dot may survive a crash+restart (found=%v isGenerating=%v)", ok, row.IsGenerating)
	}
}
