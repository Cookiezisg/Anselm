package evalbench

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"sort"
	"strings"
)

// BuildRow is one (task, rep) outcome of the build lane, appended as JSONL by the runner.
//
// Attempt semantics: attempt 1 is the model's first build + first run with ZERO follow-up turns.
// Each later attempt is one harness "fix it" turn containing no human edit (the run's failure is
// quoted back; the model inspects and republishes). Pass@1 counts attempt 1 only; Pass@3 counts a
// pass on attempt ≤ 3, i.e. ≤ 2 repair turns after the first run — the catalog's "three rounds"
// are attempts, so the number is conservative, never generous.
//
// BuildRow 是建图车道的一条 (task, rep) 结果，runner 以 JSONL 追加。attempt 1 = 模型首次建图 + 首跑、
// 零追问；此后每个 attempt 是 harness 一轮不含人工编辑的"修一下"追问。Pass@1 只看 attempt 1；
// Pass@3 看 attempt ≤ 3，口径保守不宽松。
type BuildRow struct {
	Lane        string  `json:"lane"` // "build"
	Model       string  `json:"model"`
	TaskID      string  `json:"taskId"`
	Tier        int     `json:"tier"`
	Rep         int     `json:"rep"`
	PassAttempt int     `json:"passAttempt"` // 0 = never passed within the attempt budget
	Attempts    int     `json:"attempts"`
	Structure   float64 `json:"structure"` // StructureScore of the final active version
	TriggerOK   bool    `json:"triggerOk"`
	Reasons     string  `json:"reasons,omitempty"` // last verdict's reasons, joined
	// FirstReasons keeps attempt 1's verdict so a pass@1 failure stays attributable after a later
	// attempt succeeds and overwrites Reasons.
	//
	// FirstReasons 保留 attempt 1 的裁决，使首轮失败在后续 attempt 通过并覆盖 Reasons 后仍可归因。
	FirstReasons string `json:"firstReasons,omitempty"`
	// FirstTools is attempt 1's tool-call name sequence, the only record of what the model actually
	// did: Anselm tools execute in-process, so they never show up in the server's HTTP log.
	//
	// FirstTools 是 attempt 1 的工具调用名序列，也是模型实际行为的唯一记录——Anselm 工具进程内执行，
	// 不会出现在服务端 HTTP 日志中。
	FirstTools []string `json:"firstTools,omitempty"`
	ModelCalls int      `json:"modelCalls"`
	WallMS     int64    `json:"wallMs"`
}

// RepairRow is one (task, fault) outcome of the repair lane. RepairRow 是修复车道的一条 (task, fault)。
type RepairRow struct {
	Lane        string `json:"lane"` // "repair"
	Model       string `json:"model"`
	TaskID      string `json:"taskId"`
	Tier        int    `json:"tier"`
	FaultID     string `json:"faultId"`
	Failed      bool   `json:"failed"`      // the injected fault really failed the run (else the row is void)
	NewVersion  bool   `json:"newVersion"`  // a new function/workflow version was published by the model
	RerunPass   bool   `json:"rerunPass"`   // the rerun passed the task assertion with the fault still armed
	Regression  bool   `json:"regression"`  // a clean rerun (fault disarmed, sink reset) FAILED after the repair
	FalseRepair bool   `json:"falseRepair"` // new version + rerun completed, but the assertion failed
	RepairTurns int    `json:"repairTurns"`
	Reasons     string `json:"reasons,omitempty"`
}

// Summary is what any published number is built from. Every ratio carries its numerator/denominator
// so the number can be re-derived by hand. Summary 是任何对外数字的来源；每个比率都带分子分母，可手算复核。
type Summary struct {
	Model string `json:"model"`
	Build struct {
		Tasks      int             `json:"tasks"`
		Runs       int             `json:"runs"`
		Pass1      Ratio           `json:"pass@1"`
		Pass3      Ratio           `json:"pass@3"`
		ByTier     map[string]Tier `json:"byTier"`
		StableTask []string        `json:"stableTasks"` // passed within 3 attempts on EVERY rep
		Structure  float64         `json:"meanStructure"`
		FailTags   map[string]int  `json:"failTags"`
	} `json:"build"`
	Repair struct {
		Injections   int              `json:"injections"`
		Success      Ratio            `json:"success"`
		NoRegression Ratio            `json:"noRegression"` // denominator = successful repairs
		FalseRepair  Ratio            `json:"falseRepair"`  // denominator = injections
		ByFault      map[string]Ratio `json:"byFault"`
	} `json:"repair"`
}

type Ratio struct {
	Num int     `json:"num"`
	Den int     `json:"den"`
	Pct float64 `json:"pct"`
}

type Tier struct {
	Runs  int   `json:"runs"`
	Pass1 Ratio `json:"pass@1"`
	Pass3 Ratio `json:"pass@3"`
}

func ratio(n, d int) Ratio {
	r := Ratio{Num: n, Den: d}
	if d > 0 {
		r.Pct = float64(n) * 100 / float64(d)
	}
	return r
}

// ReadRows decodes a JSONL stream of BuildRow / RepairRow, dispatching on "lane".
// ReadRows 解码 JSONL 流，按 "lane" 分派。
func ReadRows(r io.Reader) ([]BuildRow, []RepairRow, error) {
	var builds []BuildRow
	var repairs []RepairRow
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 1<<20), 1<<24)
	line := 0
	for sc.Scan() {
		line++
		raw := strings.TrimSpace(sc.Text())
		if raw == "" {
			continue
		}
		var probe struct {
			Lane string `json:"lane"`
		}
		if err := json.Unmarshal([]byte(raw), &probe); err != nil {
			return nil, nil, fmt.Errorf("line %d: %w", line, err)
		}
		switch probe.Lane {
		case "build":
			var b BuildRow
			if err := json.Unmarshal([]byte(raw), &b); err != nil {
				return nil, nil, fmt.Errorf("line %d: %w", line, err)
			}
			builds = append(builds, b)
		case "repair":
			var p RepairRow
			if err := json.Unmarshal([]byte(raw), &p); err != nil {
				return nil, nil, fmt.Errorf("line %d: %w", line, err)
			}
			repairs = append(repairs, p)
		default:
			return nil, nil, fmt.Errorf("line %d: unknown lane %q", line, probe.Lane)
		}
	}
	return builds, repairs, sc.Err()
}

// Score folds rows into the Summary. Pass@k denominators are RUNS (task × rep), never tasks, so a
// task that passes once in three reps contributes 1/3, not 1. Score 把行折叠成 Summary；Pass@k 分母是
// run 数（task × rep）而非任务数，三次过一次只贡献 1/3。
func Score(model string, builds []BuildRow, repairs []RepairRow) Summary {
	var s Summary
	s.Model = model
	if s.Model == "" {
		seen := map[string]bool{}
		for _, b := range builds {
			if b.Model != "" && !seen[b.Model] {
				seen[b.Model] = true
				if s.Model != "" {
					s.Model += ","
				}
				s.Model += b.Model
			}
		}
	}
	s.Build.ByTier = map[string]Tier{}
	s.Build.FailTags = map[string]int{}

	tasks := map[string]bool{}
	tierRuns := map[int]int{}
	tierP1 := map[int]int{}
	tierP3 := map[int]int{}
	p1, p3 := 0, 0
	var structSum float64
	allStable := map[string]bool{}
	runs := 0
	for _, b := range builds {
		if b.Model != "" && model != "" && b.Model != model {
			continue
		}
		runs++
		tasks[b.TaskID] = true
		tierRuns[b.Tier]++
		structSum += b.Structure
		if b.PassAttempt == 1 {
			p1++
			tierP1[b.Tier]++
		}
		if b.PassAttempt >= 1 && b.PassAttempt <= 3 {
			p3++
			tierP3[b.Tier]++
			if _, seen := allStable[b.TaskID]; !seen {
				allStable[b.TaskID] = true
			}
		} else {
			allStable[b.TaskID] = false
			s.Build.FailTags[failTag(b.Reasons)]++
		}
	}
	s.Build.Tasks = len(tasks)
	s.Build.Runs = runs
	s.Build.Pass1 = ratio(p1, runs)
	s.Build.Pass3 = ratio(p3, runs)
	if runs > 0 {
		s.Build.Structure = structSum / float64(runs)
	}
	for tier, n := range tierRuns {
		s.Build.ByTier[fmt.Sprintf("T%d", tier)] = Tier{Runs: n, Pass1: ratio(tierP1[tier], n), Pass3: ratio(tierP3[tier], n)}
	}
	for id, ok := range allStable {
		if ok {
			s.Build.StableTask = append(s.Build.StableTask, id)
		}
	}
	sort.Strings(s.Build.StableTask)

	s.Repair.ByFault = map[string]Ratio{}
	inj, succ, noReg, falseRep := 0, 0, 0, 0
	faultInj := map[string]int{}
	faultSucc := map[string]int{}
	for _, r := range repairs {
		if r.Model != "" && model != "" && r.Model != model {
			continue
		}
		if !r.Failed {
			continue // the fault never bit; the injection is void, not a success
		}
		inj++
		faultInj[r.FaultID]++
		ok := r.NewVersion && r.RerunPass
		if ok {
			succ++
			faultSucc[r.FaultID]++
			if !r.Regression {
				noReg++
			}
		}
		if r.FalseRepair {
			falseRep++
		}
	}
	s.Repair.Injections = inj
	s.Repair.Success = ratio(succ, inj)
	s.Repair.NoRegression = ratio(noReg, succ)
	s.Repair.FalseRepair = ratio(falseRep, inj)
	for f, n := range faultInj {
		s.Repair.ByFault[f] = ratio(faultSucc[f], n)
	}
	return s
}

// failTag buckets a verdict's reasons into the four root causes the write-up reports.
// failTag 把裁决原因归入写法里报告的四类根因。
func failTag(reasons string) string {
	r := strings.ToLower(reasons)
	switch {
	case r == "":
		return "unknown"
	case strings.Contains(r, "no workflow") || strings.Contains(r, "no run"):
		return "structure" // nothing (or nothing runnable) was built
	case strings.Contains(r, "want") && strings.Contains(r, "call"):
		return "code" // the graph ran but the function did not deliver
	case strings.Contains(r, "order") || strings.Contains(r, "must not be called"):
		return "wiring" // branches / ordering wrong
	case strings.Contains(r, "body lacks"):
		return "mapping" // delivered, but the payload mapping is wrong
	default:
		return "other"
	}
}

// Markdown renders the Summary as the table that goes into the write-up.
// Markdown 把 Summary 渲染为写入文档的表。
func Markdown(s Summary) string {
	var b strings.Builder
	fmt.Fprintf(&b, "## evalbench · model `%s`\n\n", s.Model)
	fmt.Fprintf(&b, "| Lane | Metric | Value |\n|---|---|---|\n")
	fmt.Fprintf(&b, "| build | tasks / runs | %d / %d |\n", s.Build.Tasks, s.Build.Runs)
	fmt.Fprintf(&b, "| build | Pass@1 | %s |\n", fmtRatio(s.Build.Pass1))
	fmt.Fprintf(&b, "| build | Pass@3 | %s |\n", fmtRatio(s.Build.Pass3))
	for _, tier := range []string{"T1", "T2", "T3", "T4"} {
		if t, ok := s.Build.ByTier[tier]; ok {
			fmt.Fprintf(&b, "| build | %s Pass@1 / Pass@3 | %s / %s |\n", tier, fmtRatio(t.Pass1), fmtRatio(t.Pass3))
		}
	}
	fmt.Fprintf(&b, "| build | mean structure Jaccard | %.2f |\n", s.Build.Structure)
	fmt.Fprintf(&b, "| build | stable tasks (Pass@3 on every rep) | %d |\n", len(s.Build.StableTask))
	fmt.Fprintf(&b, "| repair | injections | %d |\n", s.Repair.Injections)
	fmt.Fprintf(&b, "| repair | success | %s |\n", fmtRatio(s.Repair.Success))
	fmt.Fprintf(&b, "| repair | no-regression (of successes) | %s |\n", fmtRatio(s.Repair.NoRegression))
	fmt.Fprintf(&b, "| repair | false repair | %s |\n", fmtRatio(s.Repair.FalseRepair))
	faults := make([]string, 0, len(s.Repair.ByFault))
	for f := range s.Repair.ByFault {
		faults = append(faults, f)
	}
	sort.Strings(faults)
	for _, f := range faults {
		fmt.Fprintf(&b, "| repair | %s | %s |\n", f, fmtRatio(s.Repair.ByFault[f]))
	}
	if len(s.Build.FailTags) > 0 {
		b.WriteString("\n失败归因（Pass@3 未通过的 run）：\n\n| tag | runs |\n|---|---|\n")
		tags := make([]string, 0, len(s.Build.FailTags))
		for t := range s.Build.FailTags {
			tags = append(tags, t)
		}
		sort.Strings(tags)
		for _, t := range tags {
			fmt.Fprintf(&b, "| %s | %d |\n", t, s.Build.FailTags[t])
		}
	}
	return b.String()
}

func fmtRatio(r Ratio) string {
	if r.Den == 0 {
		return "n/a"
	}
	return fmt.Sprintf("%.1f%% (%d/%d)", r.Pct, r.Num, r.Den)
}
