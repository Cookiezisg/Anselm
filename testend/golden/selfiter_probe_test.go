// selfiter_probe_test.go is the seed of the self-iteration loop's capture layer: run the REAL
// agent (deepseek-v4-flash) on a task, then dump the FULL trajectory — every tool_call (name +
// args), tool_result, the system prompt the agent actually saw (where tool descriptions live),
// the final entity state, and token usage — to disk for an out-of-band LLM judge (Claude) to read
// and grade against an expectation. Unlike the J-journeys (code-based end-state asserts only),
// this captures the *path*, not just the goal state. Gated by EVALS=1 (real model, real tokens)
// via the package TestMain. Dump dir: $SELFITER_OUT or /tmp/anselm_selfiter.
//
// selfiter_probe_test.go 是自迭代 loop「捕获层」的种子：让真 agent（deepseek-v4-flash）跑一个任务，
// 然后把**整条轨迹**——每个 tool_call（名 + 参数）、tool_result、agent 真看到的 system prompt（工具
// 描述住这）、最终实体态、token 账单——落盘，供带外 LLM 判官（Claude）读取并按预期判分。不同于 J 旅程
// （只 code-based 判终态），这里抓的是**路径**而非只是目标态。EVALS=1 门控（真模型真烧 token）。
package golden

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/sunweilin/anselm/testend/harness"
)

// trajOut is the on-disk dump dir; fixed (not t.TempDir) so the judge can read it after the run.
//
// trajOut 是落盘目录；固定路径（非 t.TempDir）以便判官在跑完后读取。
func trajOut(t *testing.T) string {
	t.Helper()
	d := os.Getenv("SELFITER_OUT")
	if d == "" {
		d = "/tmp/anselm_selfiter"
	}
	if err := os.MkdirAll(d, 0o755); err != nil {
		t.Fatalf("mkdir %s: %v", d, err)
	}
	return d
}

// writeJSON pretty-prints raw envelope data to outDir/tag.name.json (best-effort; never fails the test).
//
// writeJSON 把裸 envelope data 美化写到 outDir/tag.name.json（best-effort，绝不让测试失败）。
func writeJSON(path string, raw json.RawMessage) {
	out := []byte(raw)
	var v any
	if json.Unmarshal(raw, &v) == nil {
		if b, err := json.MarshalIndent(v, "", "  "); err == nil {
			out = b
		}
	}
	_ = os.WriteFile(path, out, 0o644)
}

// dumpTrajectory captures the full agent path for one conversation. Uses Try (no Fatalf) so it is
// safe to defer — even if the turn times out, whatever ran so far is still written.
//
// dumpTrajectory 捕获一个对话的完整 agent 路径。用 Try（不 Fatalf），故可 defer——即使回合超时，
// 已跑到的部分仍被写下。
func dumpTrajectory(t *testing.T, wc *harness.Client, convID, outDir, tag string) {
	t.Helper()
	get := func(name, path string) {
		if r, err := wc.Try("GET", path, nil); err == nil && r != nil {
			writeJSON(filepath.Join(outDir, tag+"."+name+".json"), r.Data)
		}
	}
	get("messages", "/api/v1/conversations/"+convID+"/messages?limit=200")
	get("systemprompt", "/api/v1/conversations/"+convID+"/system-prompt-preview")
	get("usage", "/api/v1/conversations/"+convID+"/usage")
	get("functions", "/api/v1/functions")
	get("handlers", "/api/v1/handlers")
	t.Logf("[selfiter] trajectory dumped: %s/%s.*.json", outDir, tag)
}

// ── Task A: 从零造 function 并调通（tool-call 选择/参数/顺序 + build/sandbox 引擎）────────────
// 预期（判官按此评）：先 create_function（ops 写对、代码合法）→ 再 run_function（args a=2,b=3）
// → 报出结果 5。double-check / 先列工具 / envfix 自愈重试都算可接受，只要收敛到对。
func TestSelfIter_BuildRunFunction(t *testing.T) {
	outDir := trajOut(t)
	wc := evalWS(t)
	conv := newConv(t, wc, "selfiter: build & run add")
	defer dumpTrajectory(t, wc, conv, outDir, "buildrun")
	say(t, wc, conv,
		"Create a Python function named `add` that takes two integers a and b and returns "+
			`{"sum": a+b}. Then run it with a=2 and b=3 and tell me the result.`, 240000)
}

// ── Task B: 修一个埋雷 function（诊断 + edit_function + 恢复动态）──────────────────────────────
// 预期：诊断未定义变量 → edit_function 改成 n*2 → run/verify n=4 得 8。模型若先 run 看报错再修
// （double-check）完全 OK——正是要看它能否从自己/已有的错里恢复。
func TestSelfIter_FixBuggyFunction(t *testing.T) {
	outDir := trajOut(t)
	wc := evalWS(t)
	wc.POST("/api/v1/functions", map[string]any{
		"name": "buggy_double", "description": "double a number (has a bug)",
		"code": "def buggy_double(n: int) -> dict:\n    return {\"out\": n * undefined_factor}\n",
	}).OK(t, nil)
	conv := newConv(t, wc, "selfiter: fix buggy_double")
	defer dumpTrajectory(t, wc, conv, outDir, "fixbuggy")
	say(t, wc, conv,
		"The function buggy_double is broken — it references an undefined variable. "+
			`Fix it so it returns n doubled as {"out": n*2}, then verify it works on n=4.`, 240000)
}
