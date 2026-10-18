package evalbench

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// TestEvalbench_Repair is the fault-injection lane. For each selected task × each fault: a fresh
// workspace, one build turn (attempt 1 only — a task that does not build cleanly is void here, not a
// failed repair), then the fault is armed and a run started by the harness. If the run fails, the
// harness quotes the failure back (plus the one fact the catalog says a user would know, e.g. the
// bearer token) in ≤ 2 repair turns. Verdicts are observed, not reported: a new function version
// in the graph + the rerun passing the sink assertion = repair; a clean rerun afterwards decides
// regression; a completed rerun that fails the assertion is a false repair.
//
// TestEvalbench_Repair 是故障注入车道。每条任务 × 每个故障：新 workspace、一轮建图（仅 attempt 1——建不
// 干净的任务在此作废而非计入修复失败），装载故障、harness 起 run。run 失败则 harness 在 ≤2 轮里回引
// 失败（外加目录声明用户本就知道的那一个事实，如 bearer token）。裁决只看观测：图内函数出了新版本 +
// 重跑通过 sink 断言 = 修复；随后一次干净重跑判回归；重跑 completed 但断言失败 = 误修复。
func TestEvalbench_Repair(t *testing.T) {
	requireEvals(t)
	tasks, err := LoadTasks()
	if err != nil {
		t.Fatal(err)
	}
	faults, err := LoadFaults()
	if err != nil {
		t.Fatal(err)
	}
	tasks = selectRepairTasks(t, selectTasks(t, tasks))
	turnMS := envInt("EVALBENCH_TURN_MS", 420000)
	runMS := envInt("EVALBENCH_RUN_MS", 240000)
	srv := evalServer(t)

	for _, task := range tasks {
		if task.Run != "model" || len(task.Assert.Calls) == 0 {
			continue // repairs are judged on a sink delivery the harness can re-trigger
		}
		for _, fault := range faults {
			task, fault := task, fault
			t.Run(task.ID+"/"+fault.ID, func(t *testing.T) {
				runRepairOnce(t, srv, task, fault, turnMS, runMS)
			})
		}
	}
}

// selectRepairTasks narrows to tasks the build lane found stable (Pass@3 on every rep) when a
// results file is present, so repair rates are never diluted by tasks that could not build. With
// no results file every selected task is attempted and void rows mark the ones that did not build.
//
// selectRepairTasks 在存在结果文件时收窄到建图车道判定稳定（每次重复都 Pass@3）的任务，使修复率不被
// 建不出来的任务稀释；没有结果文件则全部尝试，作废行标记建不出来的那些。
func selectRepairTasks(t *testing.T, tasks []Task) []Task {
	t.Helper()
	f, err := os.Open(resultsPath(t))
	if err != nil {
		return tasks
	}
	defer f.Close()
	builds, _, err := ReadRows(f)
	if err != nil || len(builds) == 0 {
		return tasks
	}
	s := Score("", builds, nil)
	stable := map[string]bool{}
	for _, id := range s.Build.StableTask {
		stable[id] = true
	}
	var out []Task
	for _, task := range tasks {
		if stable[task.ID] {
			out = append(out, task)
		}
	}
	t.Logf("repair lane: %d stable tasks from %s", len(out), resultsPath(t))
	return out
}

func runRepairOnce(t *testing.T, srv *harness.Server, task Task, fault Fault, turnMS, runMS int) {
	t.Helper()
	wc, model := evalWS(t, srv)
	sink := NewSink()
	defer sink.Close()
	if task.Setup != nil && task.Setup.MCP {
		installEchoMCP(t, wc)
	}
	conv := wc.POST("/api/v1/conversations", map[string]any{"title": "evalbench repair " + task.ID}).Field(t, "id")
	row := RepairRow{Lane: "repair", Model: model, TaskID: task.ID, Tier: task.Tier, FaultID: fault.ID}
	defer func() {
		appendRow(t, row)
		t.Logf("%s/%s: failed=%v newVersion=%v rerunPass=%v regression=%v false=%v reasons=%s",
			task.ID, fault.ID, row.Failed, row.NewVersion, row.RerunPass, row.Regression, row.FalseRepair, row.Reasons)
	}()

	// 1. Clean build + clean first run must pass, else the injection is void.
	// 1. 干净建图 + 干净首跑必须通过，否则注入作废。
	say(t, wc, conv, strings.ReplaceAll(task.Prompt, SinkPlaceholder, sink.URL()), turnMS)
	v0, g := observeAndJudge(t, wc, sink, task, runMS)
	if !v0.Pass {
		row.Reasons = "void: clean build did not pass: " + strings.Join(v0.Reasons, "; ")
		return
	}
	wf, _ := findWorkflow(wc, task.Name)
	baseVersion := maxFunctionVersion(wc, g)

	// 2. Arm the fault and start a harness run (not a model run: the model must not know yet).
	// 2. 装载故障并由 harness 起 run（不是模型起：模型此刻还不该知道）。
	sink.Reset()
	if fault.Kind == "sink" {
		sink.Arm(&fault)
	} else {
		breakFunction(t, wc, g)
	}
	runID := startRun(t, wc, wf.ID, firstPayload(task))
	d := settleRun(t, wc, runID, task.ApprovalDecision, runMS)
	if d.Flowrun.Status != "failed" {
		v := Judge(task, sink.Ledger(), docNames(wc), mcpLedger(wc))
		if v.Pass {
			row.Reasons = "void: fault did not bite (run " + d.Flowrun.Status + ", assertion passed)"
			return
		}
	}
	row.Failed = true

	// 3. Repair turns: the failure quoted back, plus the one user-known fact the catalog grants.
	// 3. 修复追问：回引失败，外加目录授予的那一个用户已知事实。
	hint := map[string]string{
		"http_401": " The sink requires the header 'Authorization: Bearer eb-token'.",
	}[fault.ID]
	for turn := 1; turn <= 2; turn++ {
		row.RepairTurns = turn
		msg := fmt.Sprintf("Run %s of workflow %s failed with status %s: %s.%s Diagnose it from the run (get_flowrun,"+
			" get_function), fix the implementation so the delivery succeeds, publish the fix, and start exactly"+
			" one new run with the same payload.", runID, wf.Name, d.Flowrun.Status, truncate(d.Flowrun.Error, 400), hint)
		sink.Reset()
		if fault.Kind == "sink" {
			sink.Arm(&fault) // header-gated faults keep biting; transient ones clear on first retry
		}
		say(t, wc, conv, msg, turnMS)
		g = readGraph(t, wc, wf.ID)
		row.NewVersion = maxFunctionVersion(wc, g) > baseVersion
		rerun, ok := latestRun(wc, wf.ID)
		if !ok || rerun == runID {
			// Keep the last judged rerun's verdict visible next to this turn's miss.
			// 保留上一次已裁决重跑的结论，与本轮未起 run 并列。
			row.Reasons = strings.TrimSuffix(fmt.Sprintf("turn %d: model published no new run; %s", turn, row.Reasons), "; ")
			continue
		}
		d = settleRun(t, wc, rerun, task.ApprovalDecision, runMS)
		v := Judge(task, sink.Ledger(), docNames(wc), mcpLedger(wc))
		row.RerunPass = v.Pass && d.Flowrun.Status == "completed"
		row.FalseRepair = row.NewVersion && d.Flowrun.Status == "completed" && !v.Pass
		row.Reasons = strings.Join(v.Reasons, "; ")
		if row.RerunPass {
			break
		}
		runID = rerun
	}
	if !row.RerunPass {
		return
	}

	// 4. Regression: fault disarmed, sink clean, one more harness run must still pass.
	// 4. 回归：撤故障、清 sink，再由 harness 起一次 run 仍须通过。
	sink.Reset()
	clean := startRun(t, wc, wf.ID, firstPayload(task))
	d = settleRun(t, wc, clean, task.ApprovalDecision, runMS)
	v := Judge(task, sink.Ledger(), docNames(wc), mcpLedger(wc))
	row.Regression = !(v.Pass && d.Flowrun.Status == "completed")
	if row.Regression {
		row.Reasons = "regression: " + strings.Join(v.Reasons, "; ")
	}
}

// breakFunction is the harness-side `model_bad_output` fault: the first sink-calling function in
// the graph is edited to return a list instead of a dict, which the engine rejects at the node.
// breakFunction 是 harness 侧的 model_bad_output 故障：把图里第一个调 sink 的函数改成返回 list 而非
// dict，引擎在节点处拒绝。
func breakFunction(t *testing.T, wc *harness.Client, g activeGraph) {
	t.Helper()
	for _, n := range g.Nodes {
		if n.Kind != "action" || !strings.HasPrefix(n.Ref, "fn_") {
			continue
		}
		var fn struct {
			ActiveVersion struct {
				Code string `json:"code"`
			} `json:"activeVersion"`
		}
		wc.GET("/api/v1/functions/"+n.Ref).OK(t, &fn)
		if !strings.Contains(fn.ActiveVersion.Code, "urllib") {
			continue
		}
		broken := strings.Replace(fn.ActiveVersion.Code, "return {", "return [{", 1)
		broken = strings.Replace(broken, "}\n", "}]\n", 1)
		wc.POST("/api/v1/functions/"+n.Ref+":edit", map[string]any{"ops": []map[string]any{{"op": "set_code", "code": broken}}}).OK(t, nil)
		return
	}
	t.Skip("model_bad_output: graph has no sink-calling function to break")
}

// firstPayload extracts the payload the task prompt told the model to start with, so harness runs
// exercise the same branch. firstPayload 从任务提示词里取出要求的起跑 payload，使 harness 起的 run
// 走同一分支。
func firstPayload(task Task) map[string]any {
	i := strings.LastIndex(task.Prompt, "payload {")
	if i < 0 {
		return map[string]any{}
	}
	var p map[string]any
	if json.NewDecoder(strings.NewReader(task.Prompt[i+len("payload "):])).Decode(&p) != nil {
		return map[string]any{}
	}
	return p
}
