package evalbench

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestEvalbench_Build is the Pass@1 / Pass@3 lane: for every selected task and every rep, a fresh
// workspace, one build turn, the task's run, a sink verdict — then at most two harness "fix it"
// turns (no human edit, only the failure quoted back). One JSONL row per (task, rep).
//
// TestEvalbench_Build 是 Pass@1 / Pass@3 车道：每条选中任务 × 每次重复，新 workspace、一轮建图、任务
// 规定的运行、sink 裁决——随后最多两轮 harness "修一下"追问（无人工编辑，只回引失败）。每 (task, rep)
// 一行 JSONL。
func TestEvalbench_Build(t *testing.T) {
	requireEvals(t)
	tasks, err := LoadTasks()
	if err != nil {
		t.Fatal(err)
	}
	tasks = selectTasks(t, tasks)
	reps := envInt("EVALBENCH_REPS", 3)
	maxAttempts := envInt("EVALBENCH_ATTEMPTS", 3)
	turnMS := envInt("EVALBENCH_TURN_MS", 420000)
	runMS := envInt("EVALBENCH_RUN_MS", 240000)
	srv := evalServer(t)

	for _, task := range tasks {
		for rep := 1; rep <= reps; rep++ {
			task, rep := task, rep
			t.Run(fmt.Sprintf("%s/rep%d", task.ID, rep), func(t *testing.T) {
				runBuildOnce(t, srv, task, rep, maxAttempts, turnMS, runMS)
			})
		}
	}
}

func runBuildOnce(t *testing.T, srv *harness.Server, task Task, rep, maxAttempts, turnMS, runMS int) {
	t.Helper()
	wc, model := evalWS(t, srv)
	sink := NewSink()
	defer sink.Close()
	if task.Setup != nil && task.Setup.MCP {
		installEchoMCP(t, wc)
	}
	conv := wc.POST("/api/v1/conversations", map[string]any{"title": "evalbench " + task.ID}).Field(t, "id")
	prompt := strings.ReplaceAll(task.Prompt, SinkPlaceholder, sink.URL())

	row := BuildRow{Lane: "build", Model: model, TaskID: task.ID, Tier: task.Tier, Rep: rep}
	start := time.Now()
	defer func() {
		row.WallMS = elapsedMS(start)
		appendRow(t, row)
		t.Logf("%s rep%d: passAttempt=%d structure=%.2f reasons=%s", task.ID, rep, row.PassAttempt, row.Structure, row.Reasons)
	}()

	turn := prompt
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		row.Attempts = attempt
		sink.Reset()
		_, tools := say(t, wc, conv, turn, turnMS)
		row.ModelCalls += tools

		verdict, g := observeAndJudge(t, wc, sink, task, runMS)
		row.Structure = StructureScore(task.Expect.Nodes, g.Nodes)
		kind, _, _ := triggerKind(wc, g)
		row.TriggerOK = TriggerMatches(task.Expect.Trigger, kind)
		row.Reasons = strings.Join(verdict.Reasons, "; ")
		if verdict.Pass {
			row.PassAttempt = attempt
			return
		}
		// The repair turn carries only what a user would paste: the observed failure. No code, no
		// hint about the fix. 修复追问只带用户会粘贴的东西：观测到的失败。不给代码、不提示修法。
		turn = "The workflow did not produce the expected result. Observed: " + row.Reasons +
			". Inspect the workflow and its latest run (get_workflow, get_flowrun), fix the implementation" +
			" or wiring, publish the fix, and start exactly one new run the same way as before."
	}
}

// observeAndJudge finds the task's workflow, fires the webhook when the task says so, settles the
// newest run (deciding approvals), then judges the sink/Library/MCP state.
// observeAndJudge 找到任务 workflow、按任务投递 webhook、等最新 run 落定（裁决审批），再裁决
// sink/Library/MCP 状态。
func observeAndJudge(t *testing.T, wc *harness.Client, sink *Sink, task Task, runMS int) (Verdict, activeGraph) {
	t.Helper()
	wf, ok := findWorkflow(wc, task.Name)
	if !ok {
		return Verdict{Reasons: []string{"no workflow was built"}}, activeGraph{}
	}
	g := readGraph(t, wc, wf.ID)
	if task.Run == "webhook" {
		_, trgID, hookPath := triggerKind(wc, g)
		if trgID == "" {
			return Verdict{Reasons: []string{"no run: workflow has no trigger node"}}, g
		}
		fireWebhook(t, wc, trgID, hookPath, task.WebhookPayload)
	}
	var runID string
	found := false
	deadline := time.Now().Add(60 * time.Second)
	for time.Now().Before(deadline) {
		if runID, found = latestRun(wc, wf.ID); found {
			break
		}
		time.Sleep(time.Second)
	}
	if !found {
		return Verdict{Reasons: []string{"no run was started for the workflow"}}, g
	}
	d := settleRun(t, wc, runID, task.ApprovalDecision, runMS)
	v := Judge(task, sink.Ledger(), docNames(wc), mcpLedger(wc))
	if d.Flowrun.Status != "completed" && d.Flowrun.Status != "cancelled" {
		v.Pass = false
		v.Reasons = append(v.Reasons, fmt.Sprintf("run %s ended %s: %s", runID, d.Flowrun.Status, truncate(d.Flowrun.Error, 200)))
	}
	return v, g
}
