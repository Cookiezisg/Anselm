package evalbench

import (
	"strings"
	"testing"
)

func TestLoadTasksInvariants(t *testing.T) {
	tasks, err := LoadTasks()
	if err != nil {
		t.Fatal(err)
	}
	for _, task := range tasks {
		if task.Run != "model" && task.Run != "webhook" {
			t.Errorf("%s: run=%q", task.ID, task.Run)
		}
		if task.Run == "webhook" && task.Expect.Trigger != "webhook" {
			t.Errorf("%s: webhook run must expect a webhook trigger", task.ID)
		}
		if len(task.Assert.Calls)+len(task.Assert.Absent)+len(task.Assert.Documents)+len(task.Assert.MCPCalls) == 0 {
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
	task.Assert.Documents = []DocAssert{{NameContains: "Digest"}}
	task.Assert.MCPCalls = []MCPAssert{{Tool: "echo", Status: "ok"}}

	good := []SinkCall{
		{Method: "POST", Path: "/a", Body: `{"seq":1,"step":"first"}`},
		{Method: "POST", Path: "/a", Body: `{"seq":2,"step":"second"}`},
	}
	if v := Judge(task, good, []string{"Digest T4-13"}, []MCPLedgerRow{{Tool: "echo", Status: "ok"}}); !v.Pass {
		t.Fatalf("good ledger must pass: %v", v.Reasons)
	}

	cases := map[string]struct {
		ledger []SinkCall
		docs   []string
		mcp    []MCPLedgerRow
		want   string
	}{
		"count":  {good[:1], []string{"Digest"}, []MCPLedgerRow{{"echo", "ok"}}, "want 2 call(s), got 1"},
		"method": {[]SinkCall{{Method: "GET", Path: "/a", Body: "first seq"}, {Method: "GET", Path: "/a", Body: "second seq"}}, []string{"Digest"}, []MCPLedgerRow{{"echo", "ok"}}, "want 2 call(s), got 0"},
		"absent": {append(append([]SinkCall{}, good...), SinkCall{Method: "POST", Path: "/never"}), []string{"Digest"}, []MCPLedgerRow{{"echo", "ok"}}, "must not be called"},
		"order":  {[]SinkCall{good[1], good[0]}, []string{"Digest"}, []MCPLedgerRow{{"echo", "ok"}}, "expected order"},
		"body":   {[]SinkCall{{Method: "POST", Path: "/a", Body: "first"}, {Method: "POST", Path: "/a", Body: "second"}}, []string{"Digest"}, []MCPLedgerRow{{"echo", "ok"}}, "body lacks"},
		"doc":    {good, nil, []MCPLedgerRow{{"echo", "ok"}}, "no Library document"},
		"mcp":    {good, []string{"Digest"}, []MCPLedgerRow{{"echo", "error"}}, "no MCP call"},
	}
	for name, c := range cases {
		v := Judge(task, c.ledger, c.docs, c.mcp)
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
	if v := Judge(task, retried, nil, nil); !v.Pass {
		t.Fatalf("a faulted attempt followed by one delivery must pass: %v", v.Reasons)
	}
	if v := Judge(task, retried[:1], nil, nil); v.Pass {
		t.Fatal("a faulted attempt alone is not a delivery")
	}
	if v := Judge(task, append(retried, SinkCall{Method: "POST", Path: "/never", Faulted: true}), nil, nil); v.Pass {
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
