package scenarios

import (
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestChatCancel_HandlerArtifactLeavesNoOrphan exercises cancellation while a resident handler is
// inside a long-running method that would otherwise declare a media artifact. The call must become a
// terminal cancellation, its temporary output must not be uploaded after cancellation, and the
// attachment table must stay unchanged.
//
// TestChatCancel_HandlerArtifactLeavesNoOrphan 在驻留 handler 正执行、且即将声明媒体产物时取消 chat。
// 调用必须进入取消终态，临时输出不得在取消后被上传，附件表也不得增长。
func TestChatCancel_HandlerArtifactLeavesNoOrphan(t *testing.T) {
	t.Parallel()
	srv, wc, mock, _, _ := chatC_setup(t, false)
	hdID := hdCreate(t, wc, "cancel_artifact_keeper", map[string]any{
		"methods": []map[string]any{{
			"name": "plot", "inputs": []any{},
			"body": "import os, time\nyield {'progress': 'HANDLER_ARTIFACT_STARTED'}\ntime.sleep(10)\nopen(os.path.join(os.environ['ANSELM_OUT'], 'plot.png'), 'wb').write(b'late artifact')\nreturn {'chart': {'$media': 'plot.png'}}",
		}},
	})
	mock.Enqueue(dlgModel, harness.LLMTurn{ToolCalls: []harness.MockToolCall{{
		Name: "call_handler", Args: fw(map[string]any{
			"handlerId": hdID, "method": "plot", "args": map[string]any{},
		}),
	}}})

	sse := wc.Subscribe(t, "messages")
	convID := convCreate(t, wc, "cancel handler artifact")
	mid := sendMsg(t, wc, convID, "调用 handler 的 plot，但我会在它运行时取消。")
	sse.WaitFor(t, 15000, "handler call reaches its progress boundary", "HANDLER_ARTIFACT_STARTED")

	rowsBefore := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM attachments`)
	wc.POST("/api/v1/conversations/"+convID+":cancel", nil).OK(t, nil)
	turn := waitTurn(t, wc, convID, mid, 30000)
	if turn.Status != "cancelled" {
		t.Fatalf("cancelled handler turn must be terminal cancelled, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}
	if after := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM attachments`); after != rowsBefore {
		t.Fatalf("cancelled handler must not leave a media attachment row: before=%s after=%s", rowsBefore, after)
	}
	for _, block := range turn.Blocks {
		if strings.Contains(block.Content, `"source":"handler_artifact"`) {
			t.Fatalf("cancelled handler turn must not claim an artifact receipt: %+v", block)
		}
	}

	var page struct {
		Calls []struct {
			Status string `json:"status"`
		} `json:"calls"`
	}
	wc.GET("/api/v1/handlers/"+hdID+"/calls").OK(t, &page)
	if len(page.Calls) != 1 || page.Calls[0].Status != "cancelled" {
		t.Fatalf("cancelled handler call must be auditable as cancelled: %+v", page.Calls)
	}
}

// TestChatRetry_HandlerArtifactDoesNotReexecute proves regenerate is a new answer over the current
// thread, not a second execution of a side-effecting handler whose old assistant version was
// superseded. The original receipt remains readable, while the handler ledger and attachment row
// count remain exactly one.
//
// TestChatRetry_HandlerArtifactDoesNotReexecute 证明重生成是当前线程上的新回答，不会再次执行一个已被
// supersede 的 assistant 版本里的有副作用 handler。原 receipt 仍可读，handler 台账与附件行数恰为一。
func TestChatRetry_HandlerArtifactDoesNotReexecute(t *testing.T) {
	t.Parallel()
	srv, wc, mock, _, _ := chatC_setup(t, false)
	pngB64 := "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
	hdID := hdCreate(t, wc, "retry_artifact_keeper", map[string]any{
		"methods": []map[string]any{{
			"name": "plot", "inputs": []any{},
			"body": "import base64, os\nopen(os.path.join(os.environ['ANSELM_OUT'], 'plot.png'), 'wb').write(base64.b64decode('" + pngB64 + "'))\nreturn {'chart': {'$media': 'plot.png'}}",
		}},
	})
	mock.Enqueue(dlgModel,
		harness.LLMTurn{ToolCalls: []harness.MockToolCall{{Name: "call_handler", Args: fw(map[string]any{
			"handlerId": hdID, "method": "plot", "args": map[string]any{},
		})}}},
		harness.LLMTurn{Text: "FIRST-HANDLER-ANSWER"},
		harness.LLMTurn{Text: "SECOND-HANDLER-ANSWER"},
	)
	convID := convCreate(t, wc, "retry handler artifact")
	first := sendMsg(t, wc, convID, "调用 handler 并保留图片")
	firstTurn := waitTurn(t, wc, convID, first, 30000)
	if firstTurn.Status != "completed" {
		t.Fatalf("first handler turn must complete, got %s err=%s", firstTurn.Status, firstTurn.ErrorMessage)
	}
	attID := attachmentFrom(t, firstTurn, "handler_artifact")
	rowsBefore := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM attachments`)

	retryID := retryPost(t, wc, convID, "")
	secondTurn := waitTurn(t, wc, convID, retryID, 30000)
	if secondTurn.Status != "completed" {
		t.Fatalf("regenerated handler turn must complete, got %s err=%s", secondTurn.Status, secondTurn.ErrorMessage)
	}
	if after := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM attachments`); after != rowsBefore {
		t.Fatalf("retry re-uploaded handler output: rows before=%s after=%s", rowsBefore, after)
	}
	var calls struct {
		Calls []struct {
			Status string `json:"status"`
		} `json:"calls"`
	}
	wc.GET("/api/v1/handlers/"+hdID+"/calls").OK(t, &calls)
	if len(calls.Calls) != 1 || calls.Calls[0].Status != "ok" {
		t.Fatalf("retry must not execute the handler a second time: %+v", calls)
	}
	if r := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil); r.Status != 200 || !bytes2IsImage(r.Raw) {
		t.Fatalf("the original handler artifact must remain readable after retry: HTTP %d", r.Status)
	}

}

// TestChatCrash_HandlerArtifactLeavesNoOrphan covers hard-crash recovery at the same media
// boundary. Killing the backend while the handler call is in flight must be reconciled on restart
// to a cancelled turn, without a late attachment row from the abandoned output directory.
//
// TestChatCrash_HandlerArtifactLeavesNoOrphan 覆盖同一媒体边界的硬崩溃恢复：handler 调用在途时杀掉
// backend，重启后的 boot sweep 必须把回合对账为 cancelled，废弃输出目录不得晚到附件表。
func TestChatCrash_HandlerArtifactLeavesNoOrphan(t *testing.T) {
	t.Parallel()
	srv, wc, mock, wsID, _ := chatC_setup(t, false)
	hdID := hdCreate(t, wc, "crash_artifact_keeper", map[string]any{
		"methods": []map[string]any{{
			"name": "plot", "inputs": []any{},
			"body": "import os, time\nyield {'progress': 'CRASH_ARTIFACT_STARTED'}\ntime.sleep(10)\nopen(os.path.join(os.environ['ANSELM_OUT'], 'plot.png'), 'wb').write(b'late artifact')\nreturn {'chart': {'$media': 'plot.png'}}",
		}},
	})
	mock.Enqueue(dlgModel, harness.LLMTurn{ToolCalls: []harness.MockToolCall{{
		Name: "call_handler", Args: fw(map[string]any{
			"handlerId": hdID, "method": "plot", "args": map[string]any{},
		}),
	}}})
	sse := wc.Subscribe(t, "messages")
	convID := convCreate(t, wc, "crash handler artifact")
	mid := sendMsg(t, wc, convID, "调用 handler 的 plot，然后模拟崩溃。")
	sse.WaitFor(t, 15000, "handler call reaches its crash boundary", "CRASH_ARTIFACT_STARTED")
	rowsBefore := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM attachments`)

	srv.Kill9(t)
	srv.Restart(t)
	wc2 := srv.Client(t).WS(wsID)
	harness.Eventually(t, 20000, "boot reconciliation cancels abandoned media turn", func() bool {
		for _, msg := range listMsgs(t, wc2, convID) {
			if msg.ID == mid {
				return msg.Status == "cancelled"
			}
		}
		return false
	})
	if after := chatC_sqlite(t, srv.DataDir, `SELECT COUNT(*) FROM attachments`); after != rowsBefore {
		t.Fatalf("crash-recovered handler must not leave an attachment row: before=%s after=%s", rowsBefore, after)
	}
}
