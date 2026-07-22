package scenarios

// Durable-engine black-box scenarios (battle: 全量重测 Phase 3). The four trigger sources each need an
// end-to-end testend; cron/webhook/sensor have one (trigger_test.go) but fsnotify only had an infra
// unit test (fsnotify_test.go) — no black-box that a real watched-dir write drives a run to completion.
// This closes that gap: real server + real fsnotify watcher + real file write → activation + firing +
// completed flowrun. helper prefix durC_.
//
// durable 引擎黑盒场景（战役：全量重测第 3 阶段）。四类 trigger 源各需一条端到端 testend；cron/webhook/sensor
// 已有（trigger_test.go），fsnotify 只有 infra 单测（fsnotify_test.go）——无「真监视目录写文件驱动 run 跑完」的
// 黑盒。本文件补此真空：真 server + 真 fsnotify watcher + 真写文件 → activation + firing + completed flowrun。
// helper 前缀 durC_。

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// durC_ws spins a fresh server + workspace client for a durable scenario.
//
// durC_ws 起一个全新 server + workspace client。
func durC_ws(t *testing.T, name string) (*harness.Server, *harness.Client) {
	t.Helper()
	srv := harness.Start(t)
	c := srv.Client(t)
	ws := c.POST("/api/v1/workspaces", map[string]any{"name": name}).OK(t, nil)
	return srv, c.WS(ws.Field(t, "id"))
}

// TestContractDurable_FsnotifyEndToEnd — D-trg-1: the fsnotify source, black-box. A trigger watching a
// real temp directory + a workflow wired to it (fn node) must, on a real file appearing in that dir,
// record an activation (fired:true), a started firing, and run a flowrun to completion — the same
// activation/firing/flowrun ledger the webhook/cron/sensor testends assert, proving all four sources
// share one durable claim→run path.
func TestContractDurable_FsnotifyEndToEnd(t *testing.T) {
	t.Parallel()
	_, wc := durC_ws(t, "trg-fsnotify")

	// A real directory the server process can stat + watch (same host as the test).
	dir := t.TempDir()
	trgID := trgCreate(t, wc, "dir_watch", "fsnotify", map[string]any{"path": dir})
	wfID, _ := wfWithTrigger(t, wc, "fsnotify_pipe", trgID)

	// Drop a fresh, uniquely-named file each poll tick until a run completes. A unique name per write
	// sidesteps the listener's path+op+second dedup and is robust to any watch-registration lag after
	// :activate — one of the writes is guaranteed to land after the watch is live.
	// 每 tick 落一个全新唯一命名的文件直到 run 完成。每次唯一名绕开 listener 的 path+op+秒桶去重，且对
	// :activate 后的 watch 注册延迟稳健——总有一次写落在 watch 生效之后。
	i := 0
	harness.Eventually(t, 30000, "fsnotify write drives a run to completion", func() bool {
		i++
		fp := filepath.Join(dir, "drop_"+strconv.Itoa(i)+".txt")
		if err := os.WriteFile(fp, []byte("change"), 0o644); err != nil {
			t.Fatalf("write watched file: %v", err)
		}
		r := wc.GET("/api/v1/flowruns?workflowId=" + wfID + "&status=completed")
		return r.Status == 200 && strings.Contains(string(r.Data), `"status":"completed"`)
	})

	// Activation ledger recorded the fire, and the firing inbox shows it started — the same durable
	// evidence the other three sources leave.
	if r := wc.GET("/api/v1/triggers/" + trgID + "/activations"); !strings.Contains(string(r.Data), `"fired":true`) {
		t.Fatalf("activation ledger missing the fsnotify fire: %.400s", r.Data)
	}
	// Filter by status: the drop-until-completed loop above may have produced MORE firings than one
	// page holds (under load the loop runs longer — 50+ drops observed), and the started row can sit
	// past page one; an unfiltered first-page Contains would then miss it. Same assertion, page-proof.
	// 按 status 过滤:上面的循环在负载下可产出超过一页的 firing(实测 50+),started 行可能在第一页之外
	// ——未过滤的首页 Contains 会漏掉它。断言语义不变,免疫分页。
	if r := wc.GET("/api/v1/firings?triggerId=" + trgID + "&status=started"); !strings.Contains(string(r.Data), `"status":"started"`) {
		t.Fatalf("firing inbox must show started: %.400s", r.Data)
	}
	// The fired payload carried the canonical fsnotify eventKind (create|modify|…) — the delivered
	// vocabulary a downstream CEL filter would match (the round-2 configEventKind regression, end-to-end).
	if r := wc.GET("/api/v1/triggers/" + trgID + "/activations"); !strings.Contains(string(r.Data), `"eventKind"`) {
		t.Fatalf("fsnotify activation payload must carry eventKind: %.400s", r.Data)
	}
}
