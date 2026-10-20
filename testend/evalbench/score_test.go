package evalbench

import (
	"strings"
	"testing"
	"time"
)

func TestLoadTasksInvariants(t *testing.T) {
	tasks, err := LoadTasks()
	if err != nil {
		t.Fatal(err)
	}
	// Every run mode but "model" is started by the harness, so each one must line up with the
	// trigger kind the task expects — a webhook task that expects a cron trigger would be fired by
	// the harness and judged against the wrong graph. fsnotify additionally needs the watch
	// placeholder, or the harness has no directory to drop a file into.
	//
	// 除 "model" 外每种 run 模式都由 harness 起跑，故必须与任务期望的 trigger kind 对齐——一条期望 cron
	// 的 webhook 任务会被 harness 投递、却按错误的图裁决。fsnotify 另需 watch 占位符，否则 harness 没有
	// 目录可投文件。
	runKind := map[string]string{"webhook": "webhook", "fsnotify": "fsnotify", "sensor": "sensor"}
	for _, task := range tasks {
		switch task.Run {
		case "model", "webhook", "fsnotify", "sensor":
		default:
			t.Errorf("%s: run=%q", task.ID, task.Run)
		}
		if want, ok := runKind[task.Run]; ok && task.Expect.Trigger != want {
			t.Errorf("%s: run=%s must expect a %s trigger, got %q", task.ID, task.Run, want, task.Expect.Trigger)
		}
		if (task.Run == "fsnotify") != strings.Contains(task.Prompt, WatchPlaceholder) {
			t.Errorf("%s: run=%s and %s in prompt must agree", task.ID, task.Run, WatchPlaceholder)
		}
		// A harness-started task must not also order the model to run the workflow. Both runs would
		// exist, the verdict would judge whichever the harness saw first, and the task would measure
		// a race instead of the product. This is a real bug that shipped once: five webhook tasks
		// kept the hand-run tail, so the model ran them with its own sample payload and the
		// assertions failed against the wrong run.
		//
		// 由 harness 起跑的任务不得同时命令模型自己跑。两个 run 都会存在，裁决取 harness 先看到的那个，
		// 任务便测的是竞争而非产品。这是真发生过的 bug：五条 webhook 题留着手动跑的收尾，模型用自己的
		// 样例 payload 跑了一遍，断言便对着错误的 run 失败。
		if task.Run != "model" && strings.Contains(task.Prompt, "trigger_workflow") && !strings.Contains(task.Prompt, "Do NOT start a run") {
			t.Errorf("%s: run=%s but the prompt tells the model to trigger_workflow", task.ID, task.Run)
		}
		if len(task.Assert.Calls)+len(task.Assert.Absent)+len(task.Assert.MCPCalls) == 0 {
			t.Errorf("%s: no assertion — the task could never fail", task.ID)
		}
		if task.Expect.Nodes["trigger"] != 1 {
			t.Errorf("%s: every graph needs exactly one trigger in expect, got %d", task.ID, task.Expect.Nodes["trigger"])
		}
	}
	faults, err := LoadFaults()
	if err != nil {
		t.Fatal(err)
	}
	for _, f := range faults {
		if f.Kind == "sink" && f.Sink == nil {
			t.Errorf("%s: sink fault without sink spec", f.ID)
		}
	}
}

func TestStructureScore(t *testing.T) {
	exp := map[string]int{"trigger": 1, "action": 2, "control": 1}
	if got := StructureScore(exp, []GraphNode{{Kind: "trigger"}, {Kind: "action"}, {Kind: "action"}, {Kind: "control"}}); got != 1 {
		t.Fatalf("exact match = %v, want 1", got)
	}
	// one action missing: min 3 / max 4
	if got := StructureScore(exp, []GraphNode{{Kind: "trigger"}, {Kind: "action"}, {Kind: "control"}}); got != 0.75 {
		t.Fatalf("missing action = %v, want 0.75", got)
	}
	// extra kind: min 4 / max 5
	if got := StructureScore(exp, []GraphNode{{Kind: "trigger"}, {Kind: "action"}, {Kind: "action"}, {Kind: "control"}, {Kind: "agent"}}); got != 0.8 {
		t.Fatalf("extra agent = %v, want 0.8", got)
	}
	if got := StructureScore(exp, nil); got != 0 {
		t.Fatalf("empty = %v, want 0", got)
	}
}

func TestJudgeRules(t *testing.T) {
	var task Task
	task.ID = "x"
	task.Assert.Calls = []CallAssert{{Path: "/a", Method: "POST", Count: 2, BodyContains: []string{"\"seq\""}}}
	task.Assert.Absent = []string{"/never"}
	task.Assert.Ordered = []string{"/a#first", "/a#second"}
	task.Assert.MCPCalls = []MCPAssert{{Tool: "echo", Status: "ok"}}

	good := []SinkCall{
		{Method: "POST", Path: "/a", Body: `{"seq":1,"step":"first"}`},
		{Method: "POST", Path: "/a", Body: `{"seq":2,"step":"second"}`},
	}
	if v := Judge(task, good, []MCPLedgerRow{{Tool: "echo", Status: "ok"}}); !v.Pass {
		t.Fatalf("good ledger must pass: %v", v.Reasons)
	}

	cases := map[string]struct {
		ledger []SinkCall
		mcp    []MCPLedgerRow
		want   string
	}{
		"count":  {good[:1], []MCPLedgerRow{{"echo", "ok"}}, "want 2 call(s), got 1"},
		"method": {[]SinkCall{{Method: "GET", Path: "/a", Body: "first seq"}, {Method: "GET", Path: "/a", Body: "second seq"}}, []MCPLedgerRow{{"echo", "ok"}}, "want 2 call(s), got 0"},
		"absent": {append(append([]SinkCall{}, good...), SinkCall{Method: "POST", Path: "/never"}), []MCPLedgerRow{{"echo", "ok"}}, "must not be called"},
		"order":  {[]SinkCall{good[1], good[0]}, []MCPLedgerRow{{"echo", "ok"}}, "expected order"},
		"body":   {[]SinkCall{{Method: "POST", Path: "/a", Body: "first"}, {Method: "POST", Path: "/a", Body: "second"}}, []MCPLedgerRow{{"echo", "ok"}}, "body lacks"},
		"mcp":    {good, []MCPLedgerRow{{"echo", "error"}}, "no MCP call"},
	}
	for name, c := range cases {
		v := Judge(task, c.ledger, c.mcp)
		if v.Pass {
			t.Errorf("%s: must fail", name)
			continue
		}
		if !strings.Contains(strings.Join(v.Reasons, "\n"), c.want) {
			t.Errorf("%s: reasons %v lack %q", name, v.Reasons, c.want)
		}
	}
}

func TestScoreArithmetic(t *testing.T) {
	// 2 tasks × 3 reps. Task A passes attempt 1 on all reps; task B passes attempt 2 twice and never once.
	builds := []BuildRow{
		{Lane: "build", TaskID: "A", Tier: 1, Rep: 1, PassAttempt: 1, Structure: 1},
		{Lane: "build", TaskID: "A", Tier: 1, Rep: 2, PassAttempt: 1, Structure: 1},
		{Lane: "build", TaskID: "A", Tier: 1, Rep: 3, PassAttempt: 1, Structure: 1},
		{Lane: "build", TaskID: "B", Tier: 2, Rep: 1, PassAttempt: 2, Structure: 0.5},
		{Lane: "build", TaskID: "B", Tier: 2, Rep: 2, PassAttempt: 2, Structure: 0.5},
		{Lane: "build", TaskID: "B", Tier: 2, Rep: 3, PassAttempt: 0, Structure: 0.5, Reasons: "POST /b: want 1 call(s), got 0"},
	}
	repairs := []RepairRow{
		{Lane: "repair", TaskID: "A", FaultID: "http_502", Failed: true, NewVersion: true, RerunPass: true},
		{Lane: "repair", TaskID: "A", FaultID: "timeout", Failed: true, NewVersion: true, RerunPass: true, Regression: true},
		{Lane: "repair", TaskID: "A", FaultID: "http_401", Failed: true, NewVersion: true, RerunPass: false, FalseRepair: true},
		{Lane: "repair", TaskID: "A", FaultID: "schema_change", Failed: false}, // void
	}
	s := Score("", builds, repairs)
	if s.Build.Runs != 6 || s.Build.Tasks != 2 {
		t.Fatalf("runs/tasks = %d/%d", s.Build.Runs, s.Build.Tasks)
	}
	if s.Build.Pass1.Num != 3 || s.Build.Pass1.Den != 6 {
		t.Fatalf("pass@1 = %+v", s.Build.Pass1)
	}
	if s.Build.Pass3.Num != 5 || s.Build.Pass3.Den != 6 {
		t.Fatalf("pass@3 = %+v", s.Build.Pass3)
	}
	if got := s.Build.ByTier["T2"]; got.Pass1.Num != 0 || got.Pass3.Num != 2 || got.Runs != 3 {
		t.Fatalf("T2 = %+v", got)
	}
	if len(s.Build.StableTask) != 1 || s.Build.StableTask[0] != "A" {
		t.Fatalf("stable = %v", s.Build.StableTask)
	}
	if s.Build.FailTags["code"] != 1 {
		t.Fatalf("fail tags = %v", s.Build.FailTags)
	}
	if s.Repair.Injections != 3 {
		t.Fatalf("injections = %d (void row must not count)", s.Repair.Injections)
	}
	if s.Repair.Success.Num != 2 || s.Repair.NoRegression.Num != 1 || s.Repair.NoRegression.Den != 2 || s.Repair.FalseRepair.Num != 1 {
		t.Fatalf("repair = %+v", s.Repair)
	}
	md := Markdown(s)
	for _, want := range []string{"50.0% (3/6)", "83.3% (5/6)", "66.7% (2/3)", "50.0% (1/2)", "33.3% (1/3)"} {
		if !strings.Contains(md, want) {
			t.Errorf("markdown lacks %q:\n%s", want, md)
		}
	}
}

func TestReadRowsRoundtrip(t *testing.T) {
	in := `{"lane":"build","taskId":"A","tier":1,"rep":1,"passAttempt":1}
{"lane":"repair","taskId":"A","faultId":"http_502","failed":true,"newVersion":true,"rerunPass":true}

`
	b, r, err := ReadRows(strings.NewReader(in))
	if err != nil || len(b) != 1 || len(r) != 1 {
		t.Fatalf("roundtrip: %v %d %d", err, len(b), len(r))
	}
	if _, _, err := ReadRows(strings.NewReader(`{"lane":"nope"}`)); err == nil {
		t.Fatal("unknown lane must error")
	}
}

func TestJudgeFaultedCallsAreNotDeliveries(t *testing.T) {
	var task Task
	task.Assert.Calls = []CallAssert{{Path: "/a", Method: "POST", Count: 1, BodyContains: []string{"x"}}}
	task.Assert.Absent = []string{"/never"}
	retried := []SinkCall{
		{Method: "POST", Path: "/a", Body: "", Faulted: true},
		{Method: "POST", Path: "/a", Body: "x"},
	}
	if v := Judge(task, retried, nil); !v.Pass {
		t.Fatalf("a faulted attempt followed by one delivery must pass: %v", v.Reasons)
	}
	if v := Judge(task, retried[:1], nil); v.Pass {
		t.Fatal("a faulted attempt alone is not a delivery")
	}
	if v := Judge(task, append(retried, SinkCall{Method: "POST", Path: "/never", Faulted: true}), nil); v.Pass {
		t.Fatal("absent counts faulted attempts too")
	}
}

func TestScoreModelFilterDenominators(t *testing.T) {
	builds := []BuildRow{
		{Lane: "build", Model: "m1", TaskID: "A", Tier: 1, PassAttempt: 1},
		{Lane: "build", Model: "m2", TaskID: "A", Tier: 1, PassAttempt: 0},
	}
	s := Score("m1", builds, nil)
	if s.Build.Runs != 1 || s.Build.Pass1.Den != 1 || s.Build.Pass1.Num != 1 {
		t.Fatalf("filtered score = runs %d, pass@1 %+v", s.Build.Runs, s.Build.Pass1)
	}
}

func TestFirstPayloadNested(t *testing.T) {
	var task Task
	task.Prompt = `Start one run with payload {"order": {"id": 7}, "ok": true} and report.`
	p := firstPayload(task)
	if inner, _ := p["order"].(map[string]any); inner["id"] != float64(7) || p["ok"] != true {
		t.Fatalf("payload = %v", p)
	}
}

func TestTriggerMatches(t *testing.T) {
	for _, c := range []struct {
		expected, observed string
		want               bool
	}{
		{"manual", "cron", true},
		{"manual", "manual", true},
		{"manual", "", false},
		{"webhook", "webhook", true},
		{"webhook", "cron", false},
	} {
		if got := TriggerMatches(c.expected, c.observed); got != c.want {
			t.Errorf("TriggerMatches(%q, %q) = %v, want %v", c.expected, c.observed, got, c.want)
		}
	}
}

// Contamination voids a run instead of scoring it: a run that read the task definitions cannot be
// counted as a pass (it may have read the answer) nor as a failure (it was never fairly attempted).
//
// 污染令该次运行**作废**而非计分：读过任务定义的运行不能算通过（可能读了答案），也不能算失败
// （它从未被公平地尝试）。
func TestScoreVoidsContaminatedRuns(t *testing.T) {
	builds := []BuildRow{
		{Lane: "build", Model: "m", TaskID: "T1-01", Tier: 1, Rep: 1, PassAttempt: 1, Structure: 1},
		{Lane: "build", Model: "m", TaskID: "T1-02", Tier: 1, Rep: 1, PassAttempt: 1, Structure: 1, Contaminated: "tasks.json"},
		{Lane: "build", Model: "m", TaskID: "T1-03", Tier: 1, Rep: 1, PassAttempt: 0, Structure: 0, Contaminated: "eval-benchmark"},
	}
	s := Score("m", builds, nil)
	if s.Build.Runs != 1 {
		t.Fatalf("runs = %d, want 1 (two of three voided)", s.Build.Runs)
	}
	if s.Build.Void != 2 {
		t.Fatalf("void = %d, want 2", s.Build.Void)
	}
	if s.Build.Pass1.Num != 1 || s.Build.Pass1.Den != 1 {
		t.Fatalf("pass@1 = %d/%d, want 1/1", s.Build.Pass1.Num, s.Build.Pass1.Den)
	}
	// The voided failure must not land in the failure histogram either.
	// 作废的失败也不得进入归因直方图。
	if n := len(s.Build.FailTags); n != 0 {
		t.Fatalf("failTags = %v, want empty", s.Build.FailTags)
	}
}

func TestLooksContaminated(t *testing.T) {
	needles := []string{"tasks.json", "evalbench", "eval-benchmark", "/repo/root"}
	for _, tc := range []struct {
		name string
		args string
		want string
	}{
		{"clean create", `{"name":"eb_digest13","nodes":[{"kind":"trigger"}]}`, ""},
		{"reads task file", `{"command":"cat tasks.json"}`, "tasks.json"},
		{"greps the suite", `{"pattern":"eb_digest","path":"/x/evalbench"}`, "evalbench"},
		{"reads grading doc", `{"command":"sed -n 1,50p docs/working/eval-benchmark/README.md"}`, "eval-benchmark"},
		{"cds into the repo", `{"command":"cd /repo/root && ls"}`, "/repo/root"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := looksContaminated(tc.args, needles); got != tc.want {
				t.Fatalf("looksContaminated(%s) = %q, want %q", tc.args, got, tc.want)
			}
		})
	}
}

// The sink ledger must be scoped to the run: a model that smoke-tests its function before wiring it
// POSTs to the sink, and judging that probe turns "exactly one call" into a penalty for verifying
// your work. 台账必须切到 run 窗口：接线前试跑函数的模型会 POST 一次 sink，裁决那次试探会把"恰好一次
// 调用"变成对"先验证再交付"的惩罚。
func TestLedgerSinceExcludesPreRunProbes(t *testing.T) {
	s := NewSink()
	defer s.Close()
	base := time.Now()
	s.calls = []SinkCall{
		{Seq: 1, Path: "/t1-02", Method: "POST", At: base},                      // model's run_function probe
		{Seq: 2, Path: "/t1-02", Method: "POST", At: base.Add(2 * time.Second)}, // the flowrun itself
	}
	runStart := base.Add(1 * time.Second)

	if all := s.Ledger(); len(all) != 2 {
		t.Fatalf("unscoped ledger = %d calls, want 2", len(all))
	}
	scoped := s.LedgerSince(runStart)
	if len(scoped) != 1 || scoped[0].Seq != 2 {
		t.Fatalf("scoped ledger = %+v, want only seq 2", scoped)
	}
	// A zero `since` means "no run to scope to" and must not silently drop observations.
	// since 为零值意为「没有可切窗的 run」，不得静默丢弃观测。
	if len(s.LedgerSince(time.Time{})) != 2 {
		t.Fatal("zero since must return the whole ledger")
	}

	task := Task{Assert: TaskAssert{Calls: []CallAssert{{Path: "/t1-02", Method: "POST", Count: 1}}}}
	if v := Judge(task, s.Ledger(), nil); v.Pass {
		t.Fatal("unscoped ledger should fail the exactly-one assertion (got 2)")
	}
	if v := Judge(task, scoped, nil); !v.Pass {
		t.Fatalf("scoped ledger should pass: %v", v.Reasons)
	}
}

// TestScoreDropsProviderAbortedRuns pins the asymmetry that matters: a run the provider refused is
// neither a pass nor a failure, so it must leave every ratio untouched and surface on its own line.
//
// TestScoreDropsProviderAbortedRuns 锁住要紧的那条不对称：被供方拒绝的运行既非通过也非失败，必须不
// 动任何比率、并单独报出。
func TestScoreDropsProviderAbortedRuns(t *testing.T) {
	rows := []BuildRow{
		{Lane: "build", TaskID: "T1-01", Tier: 1, Rep: 1, PassAttempt: 1, Structure: 1},
		{Lane: "build", TaskID: "T1-01", Tier: 1, Rep: 2, NotMeasured: "LLM_QUOTA_EXHAUSTED: 402"},
		{Lane: "build", TaskID: "T1-02", Tier: 1, Rep: 1, Contaminated: "tasks.json"},
	}
	s := Score("", rows, nil)
	if s.Build.NotMeasured != 1 {
		t.Fatalf("notMeasured = %d, want 1", s.Build.NotMeasured)
	}
	if s.Build.Void != 1 {
		t.Fatalf("void = %d, want 1", s.Build.Void)
	}
	if s.Build.Pass1.Den != 1 || s.Build.Pass1.Num != 1 {
		t.Fatalf("pass@1 = %d/%d, want 1/1 (only the measured run counts)", s.Build.Pass1.Num, s.Build.Pass1.Den)
	}
	rs := Score("", nil, []RepairRow{
		{Lane: "repair", TaskID: "T1-01", FaultID: "http_502", Failed: true, NotMeasured: "LLM_QUOTA_EXHAUSTED: 402"},
	})
	if rs.Repair.Injections != 0 {
		t.Fatalf("injections = %d, want 0 (the aborted row is not an injection)", rs.Repair.Injections)
	}
}

// TestJudgeAtLeastFloor pins the one relaxation: an autonomous trigger may fire more than once in
// the window, so AtLeast judges a floor while every other assertion stays exact.
// TestJudgeAtLeastFloor 锁定唯一的放宽：自主型触发器可能在窗口内多次 fire，故 AtLeast 判下限，
// 其余断言仍精确。
func TestJudgeAtLeastFloor(t *testing.T) {
	ledger := []SinkCall{{Path: "/auto", Method: "POST", Body: `{"fired":true}`}, {Path: "/auto", Method: "POST", Body: `{"fired":true}`}}
	floor := Task{Assert: TaskAssert{Calls: []CallAssert{{Path: "/auto", Method: "POST", Count: 1, AtLeast: true}}}}
	if v := Judge(floor, ledger, nil); !v.Pass {
		t.Fatalf("two calls must satisfy a floor of one: %v", v.Reasons)
	}
	exact := Task{Assert: TaskAssert{Calls: []CallAssert{{Path: "/auto", Method: "POST", Count: 1}}}}
	if v := Judge(exact, ledger, nil); v.Pass {
		t.Fatal("two calls must NOT satisfy an exact count of one")
	}
	short := Task{Assert: TaskAssert{Calls: []CallAssert{{Path: "/auto", Method: "POST", Count: 3, AtLeast: true}}}}
	if v := Judge(short, ledger, nil); v.Pass {
		t.Fatal("two calls must not satisfy a floor of three")
	}
}

// TestTriggerKindOfSpeaksTheProduct pins the benchmark to the trigger domain's own vocabulary: every
// kind in domain/trigger must round-trip to itself, so expect.trigger can be written with the word
// the product uses. fsnotify once mapped to "file" and silently failed the check on every task that
// used it.
//
// TestTriggerKindOfSpeaksTheProduct 把基准钉在 trigger 域自己的词汇上：domain/trigger 的每种 kind 都
// 必须原样往返，使 expect.trigger 能直接写产品用的那个词。fsnotify 曾被映射成 "file"，静默地让所有用到
// 它的任务都判不过。
func TestTriggerKindOfSpeaksTheProduct(t *testing.T) {
	for _, kind := range []string{"cron", "webhook", "fsnotify", "sensor"} {
		if got := TriggerKindOf(kind); got != kind {
			t.Errorf("TriggerKindOf(%q) = %q, want the product's own word", kind, got)
		}
		if !TriggerMatches(kind, TriggerKindOf(kind)) {
			t.Errorf("a task expecting %q cannot be satisfied by an actual %q trigger", kind, kind)
		}
	}
	// An unreadable trigger still has to satisfy a hand-run task, and must not satisfy a named kind.
	// 读不到的 trigger 仍须满足手动跑的任务，且不得满足某个具名 kind。
	if !TriggerMatches("manual", TriggerKindOf("")) {
		t.Error(`a hand-run task must accept an unreadable trigger`)
	}
	if TriggerMatches("cron", TriggerKindOf("")) {
		t.Error(`an unreadable trigger must not pass as cron`)
	}
}
