// selfiter_confirm_f1_test.go — CONFIRM step for finding F1 (get_function/edit-by-name affordance
// gap). F1 was seen once (T2); a real model is non-deterministic, so before fixing we probe the
// SAME problem from multiple angles: three variants each force the agent to act on a function BY
// NAME (different phrasings / different verbs). If the agent reaches for a name where an fn_ id is
// required (invents a param / errors / needs a recovery round-trip) across variants, F1 is
// systematic, not a fluke — then we fix. Re-run these same tests after the fix to measure before/
// after (LOG.md F1). Gated by EVALS=1. Dumps: /tmp/anselm_selfiter/confirm_f1_*.json.
//
// selfiter_confirm_f1_test.go —— finding F1（get_function/按名查 affordance 缺口）的 CONFIRM 步。
// F1 只见过一次（T2），真模型非确定，故修前从多角度复测同一问题：三个变体各以不同措辞/动词逼 agent
// **按名字**操作一个函数。若跨变体都出现"该用 fn_ id 却抓名字"（发明参数/报错/要恢复回合），则 F1 系统性、
// 非偶发——才修。修后重跑这些同样的测做 before/after（见 LOG.md F1）。EVALS=1 门控。
package golden

import "testing"

// ── V1: 按名字取源码（get_function by name）─────────────────────────────────
func TestConfirmF1_GetByName(t *testing.T) {
	outDir := trajOut(t)
	wc := evalWS(t)
	wc.POST("/api/v1/functions", map[string]any{
		"name": "slugify_text", "description": "lowercase a string and replace spaces with dashes",
		"code": "def slugify_text(s: str) -> dict:\n    return {\"slug\": s.lower().replace(\" \", \"-\")}\n",
	}).OK(t, nil)
	conv := newConv(t, wc, "confirm f1: get by name")
	defer dumpTrajectory(t, wc, conv, outDir, "confirm_f1_get")
	say(t, wc, conv, "Show me the exact current source code of my function named `slugify_text`.", 180000)
}

// ── V2: 按名字编辑（edit_function by name，需先 name→id）──────────────────────
func TestConfirmF1_EditByName(t *testing.T) {
	outDir := trajOut(t)
	wc := evalWS(t)
	wc.POST("/api/v1/functions", map[string]any{
		"name": "adder_fn", "description": "add two integers",
		"code": "def adder_fn(a: int, b: int) -> dict:\n    return {\"sum\": a + b}\n",
	}).OK(t, nil)
	conv := newConv(t, wc, "confirm f1: edit by name")
	defer dumpTrajectory(t, wc, conv, outDir, "confirm_f1_edit")
	say(t, wc, conv,
		"Edit my function named `adder_fn` so it also accepts a third integer c and adds it to the sum, "+
			"then run it with a=1, b=2, c=3.", 180000)
}

// ── V3: 按名字问参数/返回（get_function by name）──────────────────────────────
func TestConfirmF1_ParamsByName(t *testing.T) {
	outDir := trajOut(t)
	wc := evalWS(t)
	wc.POST("/api/v1/functions", map[string]any{
		"name": "greeter_fn", "description": "greet a person by name",
		"code": "def greeter_fn(name: str) -> dict:\n    return {\"msg\": \"Hi \" + name}\n",
	}).OK(t, nil)
	conv := newConv(t, wc, "confirm f1: params by name")
	defer dumpTrajectory(t, wc, conv, outDir, "confirm_f1_params")
	say(t, wc, conv, "What input parameters does my function `greeter_fn` accept, and what does it return?", 180000)
}
