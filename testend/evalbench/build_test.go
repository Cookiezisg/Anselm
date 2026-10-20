package evalbench

import (
	"fmt"
	"os"
	"path/filepath"
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
	slots := laneSlots()

	for _, task := range tasks {
		for rep := 1; rep <= reps; rep++ {
			task, rep := task, rep
			t.Run(fmt.Sprintf("%s/rep%d", task.ID, rep), func(t *testing.T) {
				parallelCase(t, slots)
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
	// Mount an EMPTY residency so Bash starts somewhere with nothing in it. Unmounted means "the whole
	// machine", which in practice meant the server's cwd inside this repo — one `ls` from the task
	// definitions and the grading doc. This narrows the default; it is not a jail (the prompt still
	// tells the model it may read any absolute path), so contamination is also detected per run.
	//
	// 挂一个**空**驻地，使 Bash 从一个空目录起步。未挂等于「整台机器」，实际是 server 在本仓库内的 cwd
	// ——离任务定义与评分文档只有一个 `ls`。这是收窄默认值、不是牢（提示词仍告知模型可读任意绝对路径），
	// 故同时按运行检测污染。
	wc.PATCH("/api/v1/conversations/"+conv, map[string]any{"workDir": t.TempDir()})
	prompt := strings.ReplaceAll(task.Prompt, SinkPlaceholder, sink.URL())
	// An fsnotify task needs a real directory only this run owns; the harness creates the file in it
	// later. Substituted here so the model sees an absolute path it can actually watch.
	// fsnotify 任务需要一个本次运行独占的真实目录，harness 稍后在其中建文件。在此替换，使模型看到一个
	// 真能监听的绝对路径。
	watchDir := ""
	if strings.Contains(prompt, WatchPlaceholder) {
		watchDir = t.TempDir()
		prompt = strings.ReplaceAll(prompt, WatchPlaceholder, watchDir)
	}

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
		_, tools, toolNames, hit, llmErr := say(t, wc, conv, turn, turnMS)
		row.ModelCalls += tools
		if attempt == 1 {
			row.FirstTools = toolNames
		}
		// A provider refusal is not a product verdict: the model never got to act, so the run is
		// NOT MEASURED and leaves every rate alone. Fail loudly too — a lane that reports ok while
		// the key is out of credit is worse than no lane at all.
		//
		// 供方拒绝不是产品裁决：模型根本没机会动手，故该次运行**未测量**，不进任何比率。同时显式失败——
		// 一条在余额耗尽时仍报 ok 的车道比没有车道更坏。
		guard := ""
		if llmErr != "" {
			if ProviderAborted(llmErr) {
				row.NotMeasured = llmErr
				t.Errorf("%s rep%d attempt%d: provider aborted the turn (%s); run NOT MEASURED", task.ID, rep, attempt, llmErr)
				return
			}
			// The product's own breaker tripped on what the model did — a failure to attribute, not
			// missing data. 产品自身熔断被模型的行为触发——是可归因的失败，不是缺数据。
			guard = llmErr
			t.Logf("%s rep%d attempt%d: turn aborted by a product guard (%s); scored as a FAILURE", task.ID, rep, attempt, guard)
		}
		// Sticky: once a run has read the benchmark, nothing later in it is attributable.
		// 粘滞：一旦该次运行读过基准，其后一切都不可归因。
		if hit != "" && row.Contaminated == "" {
			row.Contaminated = hit
			t.Logf("%s rep%d attempt%d: VOID, tool args touched %q", task.ID, rep, attempt, hit)
		}

		verdict, g := observeAndJudge(t, wc, sink, task, runMS, watchDir)
		if guard != "" {
			verdict.Pass = false
			verdict.Reasons = append(verdict.Reasons, "turn aborted by a product guard: "+guard)
		}
		row.Structure = StructureScore(task.Expect.Nodes, g.Nodes)
		kind, _, _ := triggerKind(wc, g)
		row.TriggerOK = TriggerMatches(task.Expect.Trigger, kind)
		row.Reasons = strings.Join(verdict.Reasons, "; ")
		if attempt == 1 {
			row.FirstReasons = row.Reasons
		}
		if verdict.Pass {
			row.PassAttempt = attempt
			return
		}
		dumpConversation(t, wc, conv, task.ID, rep, attempt)
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
func observeAndJudge(t *testing.T, wc *harness.Client, sink *Sink, task Task, runMS int, watchDir string) (Verdict, activeGraph) {
	t.Helper()
	wf, ok := findWorkflow(wc, task.Name)
	if !ok {
		return Verdict{Reasons: []string{"no workflow was built"}}, activeGraph{}
	}
	g := readGraph(t, wc, wf.ID)
	// Autonomous kinds get a longer window: a sensor probes on its own cadence (floor 5s) and an
	// fsnotify event has to cross the watcher, the firing row and the scheduler fan-out.
	// 自主型给更长的窗口：sensor 按自己的节拍探测（下限 5s），fsnotify 事件要穿过 watcher、firing 行
	// 与 scheduler 扇出。
	wait := 60 * time.Second
	switch task.Run {
	case "webhook":
		_, trgID, hookPath := triggerKind(wc, g)
		if trgID == "" {
			return Verdict{Reasons: []string{"no run: workflow has no trigger node"}}, g
		}
		fireWebhook(t, wc, trgID, hookPath, task.WebhookPayload)
	case "fsnotify":
		if watchDir == "" {
			return Verdict{Reasons: []string{"task bug: run=fsnotify without " + WatchPlaceholder + " in the prompt"}}, g
		}
		if err := os.WriteFile(filepath.Join(watchDir, "eb-drop.txt"), []byte("eb\n"), 0o644); err != nil {
			t.Fatalf("fsnotify drop: %v", err)
		}
		wait = 150 * time.Second
	case "sensor":
		wait = 150 * time.Second
	}
	var runID string
	found := false
	deadline := time.Now().Add(wait)
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
	scoped := sink.LedgerSince(d.Flowrun.StartedAt)
	v := Judge(task, scoped, mcpLedger(wc))
	// Say so when probes were excluded: a verdict that silently drops observations is not auditable.
	// 排除了试探就说出来：静默丢弃观测的裁决不可审计。
	if n := len(sink.Ledger()) - len(scoped); n > 0 {
		v.Reasons = append(v.Reasons, fmt.Sprintf("(%d pre-run call(s) excluded from the verdict)", n))
	}
	if d.Flowrun.Status != "completed" && d.Flowrun.Status != "cancelled" {
		v.Pass = false
		v.Reasons = append(v.Reasons, fmt.Sprintf("run %s ended %s: %s", runID, d.Flowrun.Status, truncate(d.Flowrun.Error, 200)))
	}
	return v, g
}
