package scenarios

import (
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// The linear chain in workflow_crashsweep_test.go proves memoization on the easy shape. The shapes
// here are where a recovery bug would actually live: parallel siblings that are in flight together,
// a control node whose unchosen branch must never run, a resident handler whose process dies with
// the backend, and an approval whose human decision must not be asked for twice.
//
// workflow_crashsweep_test.go 里的线性链在最容易的形状上证明了记忆化。这里的形状才是恢复 bug 真正会住的
// 地方：同时在途的并行兄弟、未选分支绝不能执行的 control 节点、进程随 backend 一起死的驻留 handler、
// 以及人工决定绝不能被问第二次的 approval。

// shapeSpec describes one workflow and what each node's execution count may be when one node is
// killed mid-flight.
// shapeSpec 描述一个 workflow，以及某节点在途被杀时每个节点的执行次数允许是多少。
type shapeSpec struct {
	wfID    string
	nodes   []string            // every node whose body reports to the sink. 每个向 sink 上报的节点。
	targets []string            // nodes the sweep kills inside. 扫描要在其中杀的节点。
	flex    map[string][]string // target → siblings that may be in flight with it (1..1+crashes). 与 target 同时在途、可重复的兄弟。
	never   []string            // nodes that must execute 0 times (unchosen branch). 必须 0 次执行的节点（未选分支）。
	final   string              // node whose `v` is the answer. 其 `v` 为终值的节点。
	want    float64
	// decide: the approval node to decide yes, and whether to do it before the first kill.
	// decide：要批准的 approval 节点，以及是否在第一次杀之前批准。
	decide       string
	decideBefore bool
}

type shapeBuilder func(t *testing.T, wc *harness.Client, sinkURL string) shapeSpec

// stepFnCode is a sink-reporting function with the given parameters and result expression.
// stepFnCode 是向 sink 上报、带给定参数与结果表达式的函数。
func stepFnCode(sinkURL, node, params, expr string) string {
	return fmt.Sprintf("import json, time, urllib.request\n"+
		"def step(%s) -> dict:\n"+
		"    req = urllib.request.Request('%s/hit?node=%s', data=b'{}', method='POST')\n"+
		"    d = json.loads(urllib.request.urlopen(req, timeout=15).read())\n"+
		"    if d.get('hang'):\n"+
		"        time.sleep(600)\n"+
		"    return {'v': %s}\n", params, sinkURL, node, expr)
}

func addAction(ops *[]map[string]any, id, ref string, input map[string]any, from ...string) {
	n := map[string]any{"id": id, "kind": "action", "ref": ref}
	if input != nil {
		n["input"] = input
	}
	*ops = append(*ops, map[string]any{"op": "add_node", "node": n})
	for _, f := range from {
		*ops = append(*ops, map[string]any{"op": "add_edge", "edge": map[string]any{"id": "e-" + f + "-" + id, "from": f, "to": id}})
	}
}

func startNode() map[string]any {
	return map[string]any{"op": "add_node", "node": map[string]any{"id": "start", "kind": "trigger", "ref": "trg_manual"}}
}

// diamond: start → a → {b1,b2,b3} → j → z. a=1, each b=2, j=6, z=7.
func diamond(t *testing.T, wc *harness.Client, sink string) shapeSpec {
	ops := []map[string]any{startNode()}
	a := fnCreate(t, wc, "dm_a", stepFnCode(sink, "a", "v: int", "v + 1"))
	addAction(&ops, "a", a, map[string]any{"v": "start.seed"}, "start")
	bs := []string{"b1", "b2", "b3"}
	for _, b := range bs {
		f := fnCreate(t, wc, "dm_"+b, stepFnCode(sink, b, "v: int", "v + 1"))
		addAction(&ops, b, f, map[string]any{"v": "a.v"}, "a")
	}
	j := fnCreate(t, wc, "dm_j", stepFnCode(sink, "j", "x: int, y: int, w: int", "x + y + w"))
	addAction(&ops, "j", j, map[string]any{"x": "b1.v", "y": "b2.v", "w": "b3.v"}, bs...)
	z := fnCreate(t, wc, "dm_z", stepFnCode(sink, "z", "v: int", "v + 1"))
	addAction(&ops, "z", z, map[string]any{"v": "j.v"}, "j")
	return shapeSpec{
		wfID: wfCreate(t, wc, "dm", ops), nodes: []string{"a", "b1", "b2", "b3", "j", "z"},
		targets: []string{"a", "b1", "b2", "b3", "j", "z"},
		flex:    map[string][]string{"b1": {"b2", "b3"}, "b2": {"b1", "b3"}, "b3": {"b1", "b2"}},
		final:   "z", want: 7,
	}
}

// branch: start → s0 → gate(control) → hi | lo. v>0 so only hi runs; lo must execute 0 times.
func branch(t *testing.T, wc *harness.Client, sink string) shapeSpec {
	ops := []map[string]any{startNode()}
	s0 := fnCreate(t, wc, "br_s0", stepFnCode(sink, "s0", "v: int", "v + 1"))
	addAction(&ops, "s0", s0, map[string]any{"v": "start.seed"}, "start")
	ctl := wc.POST("/api/v1/controls", map[string]any{
		"name":   "br_gate",
		"inputs": []map[string]any{{"name": "v", "type": "number"}},
		"branches": []map[string]any{
			{"port": "hi", "when": "input.v > 0.0"},
			{"port": "lo", "when": "true"},
		},
	}).Field(t, "id")
	ops = append(ops,
		map[string]any{"op": "add_node", "node": map[string]any{"id": "gate", "kind": "control", "ref": ctl, "input": map[string]any{"v": "s0.v"}}},
		map[string]any{"op": "add_edge", "edge": map[string]any{"id": "e-s0-gate", "from": "s0", "to": "gate"}})
	hi := fnCreate(t, wc, "br_hi", stepFnCode(sink, "hi", "v: int", "v + 1"))
	lo := fnCreate(t, wc, "br_lo", stepFnCode(sink, "lo", "v: int", "v + 100"))
	addAction(&ops, "hi", hi, map[string]any{"v": "s0.v"})
	addAction(&ops, "lo", lo, map[string]any{"v": "s0.v"})
	ops = append(ops,
		map[string]any{"op": "add_edge", "edge": map[string]any{"id": "e-gate-hi", "from": "gate", "to": "hi", "fromPort": "hi"}},
		map[string]any{"op": "add_edge", "edge": map[string]any{"id": "e-gate-lo", "from": "gate", "to": "lo", "fromPort": "lo"}})
	return shapeSpec{
		wfID: wfCreate(t, wc, "br", ops), nodes: []string{"s0", "hi", "lo"},
		targets: []string{"s0", "hi"}, never: []string{"lo"}, final: "hi", want: 2,
	}
}

// handler: start → s0 → h.step (resident handler, state lives in the dying process) → z.
func handlerShape(t *testing.T, wc *harness.Client, sink string) shapeSpec {
	ops := []map[string]any{startNode()}
	s0 := fnCreate(t, wc, "hd_s0", stepFnCode(sink, "s0", "v: int", "v + 1"))
	addAction(&ops, "s0", s0, map[string]any{"v": "start.seed"}, "start")
	hdID := hdCreate(t, wc, "hd_res", map[string]any{
		"initBody": "self.count = 0",
		"methods": []map[string]any{{
			"name":   "step",
			"inputs": []map[string]any{{"name": "v", "type": "integer"}},
			"body": "import json, time, urllib.request\nself.count += 1\n" +
				"req = urllib.request.Request('" + sink + "/hit?node=h', data=b'{}', method='POST')\n" +
				"d = json.loads(urllib.request.urlopen(req, timeout=15).read())\n" +
				"if d.get('hang'):\n    time.sleep(600)\nreturn {'v': v + 1, 'calls': self.count}",
		}},
	})
	addAction(&ops, "h", hdID+".step", map[string]any{"v": "s0.v"}, "s0")
	z := fnCreate(t, wc, "hd_z", stepFnCode(sink, "z", "v: int", "v + 1"))
	addAction(&ops, "z", z, map[string]any{"v": "h.v"}, "h")
	return shapeSpec{
		wfID: wfCreate(t, wc, "hd", ops), nodes: []string{"s0", "h", "z"},
		targets: []string{"s0", "h", "z"}, final: "z", want: 3,
	}
}

// approval: start → s0 → human(approval) → after. The human decides once; no crash may ask again.
func approvalShape(before bool) shapeBuilder {
	return func(t *testing.T, wc *harness.Client, sink string) shapeSpec {
		ops := []map[string]any{startNode()}
		s0 := fnCreate(t, wc, "ap_s0", stepFnCode(sink, "s0", "v: int", "v + 1"))
		addAction(&ops, "s0", s0, map[string]any{"v": "start.seed"}, "start")
		apf := wc.POST("/api/v1/approvals", map[string]any{"name": "ap_gate", "template": "go on with {{ input.v }}?", "allowReason": true}).Field(t, "id")
		ops = append(ops,
			map[string]any{"op": "add_node", "node": map[string]any{"id": "human", "kind": "approval", "ref": apf, "input": map[string]any{"v": "s0.v"}}},
			map[string]any{"op": "add_edge", "edge": map[string]any{"id": "e-s0-human", "from": "s0", "to": "human"}})
		after := fnCreate(t, wc, "ap_after", stepFnCode(sink, "after", "v: int, decision: str", "v + 1"))
		addAction(&ops, "after", after, map[string]any{"v": "s0.v", "decision": "human.decision"})
		ops = append(ops, map[string]any{"op": "add_edge", "edge": map[string]any{"id": "e-human-after", "from": "human", "to": "after", "fromPort": "yes"}})
		tg := []string{"after"}
		if !before {
			tg = []string{"s0"}
		}
		return shapeSpec{
			wfID: wfCreate(t, wc, "ap", ops), nodes: []string{"s0", "after"},
			targets: tg, final: "after", want: 2, decide: "human", decideBefore: before,
		}
	}
}

func TestWorkflow_CrashShapes(t *testing.T) {
	t.Parallel()
	shapes := []struct {
		name  string
		build shapeBuilder
	}{
		{"diamond", diamond}, {"branch", branch}, {"handler", handlerShape},
		{"approval-decided-then-killed", approvalShape(true)}, {"killed-then-approval", approvalShape(false)},
	}
	var mu sync.Mutex
	runs, ok, kills := 0, 0, 0
	t.Cleanup(func() { t.Logf("CRASHSHAPES runs=%d recovered=%d kills=%d", runs, ok, kills) })
	for _, sh := range shapes {
		// Probe the targets once on a throwaway server-less build is not possible (nodes are created via
		// HTTP), so targets come from a dry description table.
		// 目标列表无法脱离 server 预建（节点经 HTTP 创建），故用静态描述表。
		for _, tgt := range shapeTargets[sh.name] {
			for _, crashes := range []int{1, 2} {
				sh, tgt, crashes := sh, tgt, crashes
				t.Run(fmt.Sprintf("%s/%s_x%d", sh.name, tgt, crashes), func(t *testing.T) {
					t.Parallel()
					good := runShapeCase(t, sh.build, tgt, crashes)
					mu.Lock()
					runs++
					kills += crashes
					if good {
						ok++
					}
					mu.Unlock()
				})
			}
		}
	}
}

var shapeTargets = map[string][]string{
	"diamond":                      {"a", "b1", "b2", "b3", "j", "z"},
	"branch":                       {"s0", "hi"},
	"handler":                      {"s0", "h", "z"},
	"approval-decided-then-killed": {"after"},
	"killed-then-approval":         {"s0"},
}

// parkedAndDecide waits for the approval node to park, then decides yes — the human's one answer.
// parkedAndDecide 等 approval 节点 park，再批准——人唯一的一次回答。
func parkedAndDecide(t *testing.T, wc *harness.Client, runID, node string) {
	t.Helper()
	harness.Eventually(t, 90000, "approval parks", func() bool {
		var got crashRun
		r, err := wc.Try("GET", "/api/v1/flowruns/"+runID, nil)
		if err != nil || r.Status != 200 || json.Unmarshal(r.Data, &got) != nil {
			return false
		}
		for _, n := range got.Nodes {
			if n.NodeID == node && n.Status == "parked" {
				return true
			}
		}
		return false
	})
	// :decide drives the run inline, so it blocks until the downstream node returns — and the downstream
	// node is the one this test stalls. Fire it and let the kill window open.
	// :decide 内联驱动 run，会阻塞到下游节点返回——而下游正是本测试故意卡住的那个。发出去，让杀进程窗口打开。
	go wc.Try("POST", "/api/v1/flowruns/"+runID+"/approvals/"+node+":decide", map[string]any{"decision": "yes", "reason": "crash probe"})
}

func runShapeCase(t *testing.T, build shapeBuilder, target string, crashes int) bool {
	sink := newCrashSink()
	defer sink.srv.Close()
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "crashshape"}).OK(t, nil).Field(t, "id")
	wc := c.WS(wsID)
	spec := build(t, wc, sink.srv.URL)
	sink.mu.Lock()
	sink.hang[target] = crashes
	sink.mu.Unlock()

	go wc.Try("POST", "/api/v1/flowruns", map[string]any{"workflowId": spec.wfID, "payload": map[string]any{"seed": 0}})

	var runID string
	findRun := func() {
		harness.Eventually(t, 60000, "run row exists", func() bool {
			var list []struct {
				ID string `json:"id"`
			}
			r, err := wc.Try("GET", "/api/v1/flowruns?workflowId="+spec.wfID, nil)
			if err != nil || r.Status != 200 || json.Unmarshal(r.Data, &list) != nil || len(list) != 1 {
				return false
			}
			runID = list[0].ID
			return true
		})
	}
	findRun()
	if spec.decide != "" && spec.decideBefore {
		parkedAndDecide(t, wc, runID, spec.decide)
	}
	for crash := 1; crash <= crashes; crash++ {
		harness.Eventually(t, 90000, fmt.Sprintf("%s reports hit #%d", target, crash), func() bool { return sink.hitsOf(target) >= crash })
		srv.Kill9(t)
		srv.Restart(t)
		wc = srv.Client(t).WS(wsID)
	}
	if spec.decide != "" && !spec.decideBefore {
		parkedAndDecide(t, wc, runID, spec.decide)
	}

	var got crashRun
	harness.Eventually(t, 120000, "recovered run reaches a terminal state", func() bool {
		r, err := wc.Try("GET", "/api/v1/flowruns/"+runID, nil)
		if err != nil || r.Status != 200 || json.Unmarshal(r.Data, &got) != nil {
			return false
		}
		return got.Flowrun.Status != "running"
	})

	good := true
	fail := func(f string, a ...any) {
		good = false
		t.Errorf("%s ×%d: "+f, append([]any{target, crashes}, a...)...)
	}
	if got.Flowrun.Status != "completed" {
		fail("run ended %s, want completed; nodes=%+v", got.Flowrun.Status, got.Nodes)
	}
	rows := map[string]crashRow{}
	for _, r := range got.Nodes {
		if _, dup := rows[r.NodeID]; dup {
			fail("duplicate row for node %s", r.NodeID)
		}
		rows[r.NodeID] = r
	}
	if v := rows[spec.final].Result["v"]; v != spec.want {
		fail("final %s.v = %v, want %v (a step was skipped or double-applied)", spec.final, v, spec.want)
	}
	flex := map[string]bool{}
	for _, f := range spec.flex[target] {
		flex[f] = true
	}
	never := map[string]bool{}
	for _, n := range spec.never {
		never[n] = true
		if r, ran := rows[n]; ran {
			fail("unchosen node %s has a row: %+v", n, r)
		}
	}
	for _, id := range spec.nodes {
		h := sink.hitsOf(id)
		lo, hi := 1, 1
		switch {
		case never[id]:
			lo, hi = 0, 0
		case id == target:
			lo, hi = 1+crashes, 1+crashes
		case flex[id]:
			hi = 1 + crashes
		}
		if h < lo || h > hi {
			fail("node %s body executed %d times, want %d..%d", id, h, lo, hi)
		}
		if !never[id] {
			if r, have := rows[id]; !have || r.Status != "completed" || r.Iteration != 0 {
				fail("node %s row = %+v, want one completed row at iteration 0", id, r)
			}
		}
	}
	if spec.decide != "" {
		var inbox struct {
			Parked []struct {
				FlowrunID string `json:"flowrunId"`
			} `json:"parked"`
		}
		wc.GET("/api/v1/flowrun-inbox").OK(t, &inbox)
		for _, p := range inbox.Parked {
			if p.FlowrunID == runID {
				fail("approval was asked again after recovery: %+v", inbox.Parked)
			}
		}
		if r := rows[spec.decide]; !strings.Contains(fmt.Sprint(r.Result), "yes") {
			fail("approval row lost its decision: %+v", r)
		}
	}
	return good
}

// TestWorkflow_CrashLoop kills inside iteration k of a loop (step → gate → back to step, 8 turns), once
// and twice. A loop is the shape where "memoized by node id" is not enough: the memo key is (node,
// iteration), and a recovery that replays from iteration 0, or re-runs an iteration that already
// finished, shows up as extra executions or a different final count.
//
// TestWorkflow_CrashLoop 在循环（step → gate → 回 step，共 8 轮）的第 k 轮内杀，杀一次与连杀两次。循环是
// 「按节点 id 记忆化」不够的形状：记忆键是 (node, iteration)，从第 0 轮重放、或重跑已完成的某一轮，
// 都会表现为多出的执行次数或不同的终值。
func TestWorkflow_CrashLoop(t *testing.T) {
	t.Parallel()
	const turns = 8
	var mu sync.Mutex
	runs, ok := 0, 0
	t.Cleanup(func() { t.Logf("CRASHLOOP runs=%d recovered=%d", runs, ok) })
	for _, k := range []int{0, 3, 7} {
		for _, crashes := range []int{1, 2} {
			k, crashes := k, crashes
			t.Run(fmt.Sprintf("iter%d_x%d", k, crashes), func(t *testing.T) {
				t.Parallel()
				good := runLoopCase(t, turns, k, crashes)
				mu.Lock()
				runs++
				if good {
					ok++
				}
				mu.Unlock()
			})
		}
	}
}

func runLoopCase(t *testing.T, turns, k, crashes int) bool {
	sink := newCrashSink()
	defer sink.srv.Close()
	srv := harness.Start(t)
	c := srv.Client(t)
	wsID := c.POST("/api/v1/workspaces", map[string]any{"name": "crashloop"}).OK(t, nil).Field(t, "id")
	wc := c.WS(wsID)

	step := fnCreate(t, wc, "lp_step", stepFnCode(sink.srv.URL, "step", "n: int", "n + 1"))
	fin := fnCreate(t, wc, "lp_fin", stepFnCode(sink.srv.URL, "fin", "n: int", "n"))
	ctl := wc.POST("/api/v1/controls", map[string]any{
		"name":   "lp_gate",
		"inputs": []map[string]any{{"name": "n", "type": "number"}},
		"branches": []map[string]any{
			{"port": "done", "when": fmt.Sprintf("input.n >= %d", turns), "emit": map[string]string{"n": "input.n"}},
			{"port": "retry", "when": "true"},
		},
	}).Field(t, "id")
	wfID := wfCreate(t, wc, "lp", []map[string]any{
		startNode(),
		{"op": "add_node", "node": map[string]any{"id": "step", "kind": "action", "ref": step, "input": map[string]any{"n": "has(step.v) ? step.v : start.seed"}}},
		{"op": "add_node", "node": map[string]any{"id": "gate", "kind": "control", "ref": ctl, "input": map[string]any{"n": "step.v"}}},
		{"op": "add_node", "node": map[string]any{"id": "fin", "kind": "action", "ref": fin, "input": map[string]any{"n": "gate.n"}}},
		{"op": "add_edge", "edge": map[string]any{"id": "e1", "from": "start", "to": "step"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e2", "from": "step", "to": "gate"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e3", "from": "gate", "to": "fin", "fromPort": "done"}},
		{"op": "add_edge", "edge": map[string]any{"id": "e4", "from": "gate", "to": "step", "fromPort": "retry"}},
	})
	sink.mu.Lock()
	sink.skip["step"], sink.hang["step"] = k, crashes
	sink.mu.Unlock()

	go wc.Try("POST", "/api/v1/flowruns", map[string]any{"workflowId": wfID, "payload": map[string]any{"seed": 0}})
	var runID string
	harness.Eventually(t, 60000, "run row exists", func() bool {
		var list []struct {
			ID string `json:"id"`
		}
		r, err := wc.Try("GET", "/api/v1/flowruns?workflowId="+wfID, nil)
		if err != nil || r.Status != 200 || json.Unmarshal(r.Data, &list) != nil || len(list) != 1 {
			return false
		}
		runID = list[0].ID
		return true
	})
	for crash := 1; crash <= crashes; crash++ {
		want := k + crash // hits so far: k clean turns + this stalled one (+ earlier stalled ones). 到目前的命中数。
		harness.Eventually(t, 90000, fmt.Sprintf("step reports hit #%d", want), func() bool { return sink.hitsOf("step") >= want })
		srv.Kill9(t)
		srv.Restart(t)
		wc = srv.Client(t).WS(wsID)
	}

	var got crashRun
	harness.Eventually(t, 120000, "recovered loop reaches a terminal state", func() bool {
		r, err := wc.Try("GET", "/api/v1/flowruns/"+runID+"?limit=100", nil)
		if err != nil || r.Status != 200 || json.Unmarshal(r.Data, &got) != nil {
			return false
		}
		return got.Flowrun.Status != "running"
	})

	good := true
	fail := func(f string, a ...any) {
		good = false
		t.Errorf("loop kill@iter%d ×%d: "+f, append([]any{k, crashes}, a...)...)
	}
	if got.Flowrun.Status != "completed" {
		fail("run ended %s, want completed", got.Flowrun.Status)
	}
	seen := map[string]bool{}
	stepRows := 0
	for _, r := range got.Nodes {
		key := fmt.Sprintf("%s#%d", r.NodeID, r.Iteration)
		if seen[key] {
			fail("duplicate row %s", key)
		}
		seen[key] = true
		if r.NodeID == "step" {
			stepRows++
			if r.Result["v"] != float64(r.Iteration+1) {
				fail("step iteration %d computed %v, want %d (the loop value was reset or skipped)", r.Iteration, r.Result["v"], r.Iteration+1)
			}
		}
		if r.NodeID == "fin" && r.Result["v"] != float64(turns) {
			fail("fin = %v, want %d", r.Result["v"], turns)
		}
	}
	if stepRows != turns {
		fail("step has %d iteration rows, want %d", stepRows, turns)
	}
	if h := sink.hitsOf("step"); h != turns+crashes {
		fail("step body executed %d times, want %d (each iteration once + %d re-runs of the killed one)", h, turns+crashes, crashes)
	}
	if h := sink.hitsOf("fin"); h != 1 {
		fail("fin executed %d times, want 1", h)
	}
	return good
}
