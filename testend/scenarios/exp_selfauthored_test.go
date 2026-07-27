package scenarios

import (
	"testing"
)

// EXPERIMENT (WRK-082, not a permanent scenario): does ADR 0017's producer filter — "the generating
// model gets a receipt, never its own pixels" — cause `qwen3-vl-plus` to re-call generate_image?
//
// The loop was observed once (a workflow agent node burning ten real images) and seven controls ruled
// out our wording and formatting. None of the seven fed the BYTES back, which is the one thing ADR
// 0017 takes away: after drawing, the model's only evidence of success is a JSON receipt with no
// picture in it.
//
// Arm A = current code. Arm B = same run with mediaref.SelfAuthored patched to return false locally.
// The number printed is calls to DashScope's generation path in ONE chat turn.
//
// 实验(非常驻场景):ADR 0017 的产地过滤——「生成的那一轮只拿 receipt、永远拿不到自己的像素」——是不是
// `qwen3-vl-plus` 重复调用 generate_image 的原因?那次循环(一个 workflow agent 节点烧掉十张真图)之后
// 跑过七组对照,排除了我们这侧的措辞与格式;而**七组里没有一组是把字节喂回去**,那恰恰是 ADR 0017 拿走
// 的唯一一样东西:画完之后,模型手里唯一的「成功证据」是一段没有图的 JSON。
//
// A 组=当前代码;B 组=同一份跑法,本地把 mediaref.SelfAuthored 改成恒 false。打印的数字是**一个 chat
// 回合内**打到 DashScope 生成路径的次数。
func TestExpSelfAuthoredLoop(t *testing.T) {
	wc, rec, _ := liveQwen(t, "exp-selfauthored")

	// Bound the blast radius: without this the control arm can burn MaxSteps images at ~¥0.25 each.
	// 把爆炸半径钳住:不设这个,对照组能按 MaxSteps 烧掉那么多张,每张约 ¥0.25。
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)

	convID := convCreate(t, wc, "自点产物回喂实验")
	mid := sendMsg(t, wc, convID, "画一座黄昏的红色灯塔,然后用一句话说说你画了什么。")
	turn := waitTurn(t, wc, convID, mid, 240000)

	gen := rec.CallsTo(dashScopeGenPath)
	t.Logf("RESULT status=%s errCode=%s imageCalls=%d modelRequests=%d",
		turn.Status, turn.ErrorCode, gen, len(rec.DumpsFor(liveModel)))
}
