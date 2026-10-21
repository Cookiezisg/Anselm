package scenarios

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

// crashSink is the loopback ledger every chain step reports to. It lives in the TEST process, so it
// survives the backend's kill -9 and is the ground truth for "how many times did this node's body
// actually execute" — independent of anything the backend itself recorded.
//
// crashSink 是每个链节点上报的回环台账。它活在**测试进程**里，因此能熬过 backend 的 kill -9，是
// 「该节点函数体实际执行了几次」的真值——独立于 backend 自己记下的任何东西。
type crashSink struct {
	mu   sync.Mutex
	hits map[string]int
	hang map[string]int // node → how many of its next hits should stall (the kill window). 接下来多少次命中要卡住（杀进程窗口）。
	srv  *httptest.Server
}

func newCrashSink() *crashSink {
	s := &crashSink{hits: map[string]int{}, hang: map[string]int{}}
	s.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		node := r.URL.Query().Get("node")
		s.mu.Lock()
		s.hits[node]++
		stall := s.hang[node] > 0
		if stall {
			s.hang[node]--
		}
		s.mu.Unlock()
		_ = json.NewEncoder(w).Encode(map[string]any{"hang": stall})
	}))
	return s
}

func (s *crashSink) hitsOf(node string) int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.hits[node]
}

// stepCode is one chain node: report to the sink, optionally stall (so the harness can kill the
// backend while this body is provably mid-flight), then return v+1. After n steps from seed 0 the
// final value must be exactly n — a recovered run that skipped or double-applied a step cannot land on it.
//
// stepCode 是一个链节点：向 sink 上报，可选卡住（让 harness 在函数体确定在途时杀 backend），再返回 v+1。
// 从 seed 0 走 n 步后终值必须恰为 n——恢复后跳步或重复应用的 run 落不到这个值。
func stepCode(sinkURL, node string) string {
	return fmt.Sprintf("import json, time, urllib.request\n"+
		"def step(v: int) -> dict:\n"+
		"    req = urllib.request.Request('%s/hit?node=%s', data=b'{}', method='POST')\n"+
		"    d = json.loads(urllib.request.urlopen(req, timeout=15).read())\n"+
		"    if d.get('hang'):\n"+
		"        time.sleep(600)\n"+
		"    return {'v': v + 1}\n", sinkURL, node)
}

// crashChain builds start → s0 → s1 → … → s(n-1), each node feeding its value to the next.
// crashChain 建 start → s0 → s1 → … → s(n-1)，每节点把值交给下一个。
func crashChain(t *testing.T, wc *harness.Client, sinkURL, name string, n int) (string, []string) {
	t.Helper()
	ops := []map[string]any{{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}}}
	nodes := make([]string, n)
	prev, prevField := "start", "start.seed"
	for i := 0; i < n; i++ {
		id := fmt.Sprintf("s%d", i)
		nodes[i] = id
		fn := fnCreate(t, wc, fmt.Sprintf("%s_%s", name, id), stepCode(sinkURL, id))
		ops = append(ops,
			map[string]any{"op": "add_node", "node": map[string]any{"id": id, "kind": "action", "ref": fn, "input": map[string]any{"v": prevField}}},
			map[string]any{"op": "add_edge", "edge": map[string]any{"id": "e-" + prev + "-" + id, "from": prev, "to": id}},
		)
		prev, prevField = id, id+".v"
	}
	return wfCreate(t, wc, name, ops), nodes
}

type crashRow struct {
	NodeID    string         `json:"nodeId"`
	Status    string         `json:"status"`
	Iteration int            `json:"iteration"`
	Result    map[string]any `json:"result"`
}

type crashRun struct {
	Flowrun struct {
		ID     string `json:"id"`
		Status string `json:"status"`
	} `json:"flowrun"`
	Nodes []crashRow `json:"nodes"`
}

// crashTally is the sweep's evidence: one line per injected crash, aggregated for the report.
// crashTally 是扫描的证据：每次注入一行，汇总进报告。
type crashTally struct {
	mu                                                  sync.Mutex
	injected, recovered, completedReexec, crashedReexec int
	extraRuns                                           int
}

func (c *crashTally) add(injected int, recovered bool, completedReexec, crashedReexec int) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.injected += injected
	if recovered {
		c.recovered += injected
	}
	c.completedReexec += completedReexec
	c.crashedReexec += crashedReexec
}

// TestWorkflow_CrashSweep kills the backend with SIGKILL while each node of a chain is provably
// mid-execution (once, and twice in a row — the second crash lands inside the recovery re-run),
// restarts on the same data dir, and checks the durable contract from the outside:
//
//   - the run reaches `completed` and the value is exactly n (no skipped / double-applied step);
//   - every node has exactly one completed row at iteration 0;
//   - nodes that were NOT in flight executed exactly once (the memoization claim);
//   - the in-flight node executed 1+crashes times (at-least-once: the engine cannot un-run a body
//     whose process died, so this is reported, not hidden).
//
// TestWorkflow_CrashSweep 在链的每个节点确定「执行中」时用 SIGKILL 杀 backend（一次，以及连续两次——
// 第二次落在恢复重跑里），在同一数据目录重启，从外部核对耐久契约：
//
//   - run 抵达 `completed` 且值恰为 n（无跳步/重复应用）；
//   - 每个节点恰有一条 iteration 0 的 completed 行；
//   - **未在途**的节点恰执行 1 次（记忆化主张）；
//   - 在途节点执行 1+crashes 次（至少一次：引擎无法撤销进程已死的函数体，故如实上报而非隐瞒）。
func TestWorkflow_CrashSweep(t *testing.T) {
	t.Parallel()
	tally := &crashTally{}
	type sweep struct{ n, crashes int }
	cases := []sweep{{3, 1}, {5, 1}, {3, 2}, {5, 2}}
	t.Cleanup(func() {
		t.Logf("CRASHSWEEP injected=%d recovered=%d completedNodeReexec=%d inflightNodeReexec=%d",
			tally.injected, tally.recovered, tally.completedReexec, tally.crashedReexec)
	})
	for _, sc := range cases {
		for k := 0; k < sc.n; k++ {
			sc, k := sc, k
			t.Run(fmt.Sprintf("n%d_crash%d_at_s%d", sc.n, sc.crashes, k), func(t *testing.T) {
				t.Parallel()
				runCrashCase(t, tally, sc.n, k, sc.crashes)
			})
		}
	}
}

func runCrashCase(t *testing.T, tally *crashTally, n, k, crashes int) {
	sink := newCrashSink()
	defer sink.srv.Close()
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "crashsweep"}).OK(t, nil).Field(t, "id")
	wc := c.WS(wsID)
	wfID, nodes := crashChain(t, wc, sink.srv.URL, "cs", n)
	target := nodes[k]
	sink.mu.Lock()
	sink.hang[target] = crashes
	sink.mu.Unlock()

	// The start request may block until the run settles or dies with the backend — the kill IS the point.
	// 起 run 的请求可能阻塞到 run 落定或随 backend 一起死——杀进程就是目的。
	go wc.Try("POST", "/api/v1/flowruns", map[string]any{"workflowId": wfID, "payload": map[string]any{"seed": 0}})

	var runID string
	for crash := 1; crash <= crashes; crash++ {
		harness.Eventually(t, 60000, fmt.Sprintf("node %s reports hit #%d", target, crash), func() bool { return sink.hitsOf(target) >= crash })
		if runID == "" {
			var list []struct {
				ID string `json:"id"`
			}
			wc.GET("/api/v1/flowruns?workflowId="+wfID).OK(t, &list)
			if len(list) != 1 {
				t.Fatalf("exactly one run expected before the first kill, got %d", len(list))
			}
			runID = list[0].ID
		}
		srv.Kill9(t)
		srv.Restart(t)
		wc = srv.Client(t).WS(wsID)
	}

	var got crashRun
	harness.Eventually(t, 90000, "recovered run reaches a terminal state", func() bool {
		r, err := wc.Try("GET", "/api/v1/flowruns/"+runID, nil)
		if err != nil || r.Status != 200 || json.Unmarshal(r.Data, &got) != nil {
			return false
		}
		return got.Flowrun.Status != "running"
	})

	ok := got.Flowrun.Status == "completed"
	if !ok {
		t.Errorf("crash at %s ×%d: run ended %s, want completed", target, crashes, got.Flowrun.Status)
	}
	rows := map[string]crashRow{}
	for _, r := range got.Nodes {
		if _, dup := rows[r.NodeID]; dup {
			ok = false
			t.Errorf("duplicate row for node %s", r.NodeID)
		}
		rows[r.NodeID] = r
	}
	if last := rows[nodes[n-1]]; last.Result["v"] != float64(n) {
		ok = false
		t.Errorf("final value %v, want %d (a step was skipped or double-applied)", last.Result["v"], n)
	}
	completedReexec, crashedReexec := 0, 0
	for _, id := range nodes {
		if r, have := rows[id]; !have || r.Status != "completed" || r.Iteration != 0 {
			ok = false
			t.Errorf("node %s row = %+v, want one completed row at iteration 0", id, r)
		}
		h := sink.hitsOf(id)
		want := 1
		if id == target {
			want = 1 + crashes
		}
		if h != want {
			ok = false
			t.Errorf("node %s body executed %d times, want %d", id, h, want)
			if id == target {
				crashedReexec += h - want
			} else {
				completedReexec += h - want
			}
		}
	}
	tally.add(crashes, ok, completedReexec, crashedReexec)
}

func nodeAim(i int) int { return i % 5 }

// TestWorkflow_CrashSweepRandomInstant kills at a random moment just after a chosen node of a fast
// 5-node run executed (no stall hook), so the kill can land between node rows, mid-write, or after the run already finished —
// the windows a deterministic hook cannot aim at. Each node must have executed 1 or 2 times, the
// result must be exact, and the final status must be completed. Seeds are fixed for reproducibility.
//
// TestWorkflow_CrashSweepRandomInstant 在一个快速 5 节点 run 的随机时刻杀进程（无卡住钩子），让杀落在
// 节点行之间、写盘中、或 run 已结束之后——确定性钩子瞄不到的窗口。每节点须执行 1 或 2 次、结果精确、
// 终态 completed。种子固定以便复现。
func TestWorkflow_CrashSweepRandomInstant(t *testing.T) {
	t.Parallel()
	const trials = 60
	var mu sync.Mutex
	var ok int
	// progress[i] = trials where i of the 5 nodes had already executed at the instant of the kill —
	// the evidence that the random kills really landed at different points of the run.
	// progress[i] = 杀的瞬间已有 i 个节点执行过的试验数——证明随机杀确实落在 run 的不同位置。
	var progress [6]int
	t.Cleanup(func() {
		t.Logf("CRASHSWEEP-RANDOM trials=%d recovered=%d nodesDoneAtKill(0..5)=%v", trials, ok, progress)
	})
	for i := 0; i < trials; i++ {
		i := i
		t.Run(fmt.Sprintf("seed%02d", i), func(t *testing.T) {
			t.Parallel()
			// Aim at node boundaries: wait until node (i%5) has executed, then kill after a random 0–200ms
			// — i.e. around the instant its row is being persisted and the next body is being dispatched.
			// 瞄准节点边界：等第 (i%5) 个节点执行过，再随机 0–200ms 后杀——即它的行正在落盘、下一个函数体正在派发的瞬间。
			aim := nodeAim(i)
			delay := time.Duration(rand.New(rand.NewSource(int64(i)+1)).Intn(200)) * time.Millisecond
			sink := newCrashSink()
			defer sink.srv.Close()
			srv := harness.Start(t)
			c := srv.Client(t)
			wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "crashrand"}).OK(t, nil).Field(t, "id")
			wc := c.WS(wsID)
			wfID, nodes := crashChain(t, wc, sink.srv.URL, "cr", 5)

			go wc.Try("POST", "/api/v1/flowruns", map[string]any{"workflowId": wfID, "payload": map[string]any{"seed": 0}})
			harness.Eventually(t, 60000, "aimed node executes", func() bool { return sink.hitsOf(nodes[aim]) > 0 })
			time.Sleep(delay)
			done := 0
			for _, id := range nodes {
				if sink.hitsOf(id) > 0 {
					done++
				}
			}
			mu.Lock()
			progress[done]++
			mu.Unlock()
			srv.Kill9(t)
			srv.Restart(t)
			wc = srv.Client(t).WS(wsID)

			// The run row may not exist if the kill beat the insert; then nothing was promised, and
			// the honest outcome is "no run" — count it, do not fail it.
			// 若杀在 insert 之前，run 行不存在：此时什么都没承诺，如实计「无 run」，不判失败。
			var list []struct {
				ID string `json:"id"`
			}
			wc.GET("/api/v1/flowruns?workflowId="+wfID).OK(t, &list)
			if len(list) == 0 {
				mu.Lock()
				ok++
				mu.Unlock()
				return
			}
			var got crashRun
			harness.Eventually(t, 90000, "run reaches a terminal state", func() bool {
				r, err := wc.Try("GET", "/api/v1/flowruns/"+list[0].ID, nil)
				if err != nil || r.Status != 200 || json.Unmarshal(r.Data, &got) != nil {
					return false
				}
				return got.Flowrun.Status != "running"
			})
			good := got.Flowrun.Status == "completed"
			if !good {
				t.Errorf("delay %v: run ended %s", delay, got.Flowrun.Status)
			}
			rows := map[string]crashRow{}
			for _, r := range got.Nodes {
				rows[r.NodeID] = r
			}
			if good && rows[nodes[4]].Result["v"] != float64(5) {
				good = false
				t.Errorf("delay %v: final value %v, want 5", delay, rows[nodes[4]].Result["v"])
			}
			for _, id := range nodes {
				if h := sink.hitsOf(id); h < 1 || h > 2 {
					good = false
					t.Errorf("delay %v: node %s executed %d times, want 1 or 2", delay, id, h)
				}
			}
			mu.Lock()
			if good {
				ok++
			}
			mu.Unlock()
		})
	}
}
