package scenarios

import (
	"encoding/base64"
	"testing"
)

// TestLiveMedia_GeneratedImageFedBackOnce is the RELAPSE GUARD for ADR 0020, and the reason it must
// run against a real model: the defect it guards cannot exist in a mock. A scripted model follows
// its script whether or not it can see the picture; only a real one, handed a pictureless receipt,
// concludes the generation failed and orders another (the ADR 0017 producer veto did exactly that —
// 4 generation calls to MAX_STEPS with the veto on, 1 call and a clean finish with it off, twice
// each, zero disagreement). So the assertion is the money counter itself: ONE turn, ONE upstream
// generation call, and a completed finish. If someone reintroduces a veto between the tool_result
// and the model — by source, by modality, by "optimization" — this is the test that goes red.
//
// TestLiveMedia_GeneratedImageFedBackOnce 是 ADR 0020 的**复发守卫**,也是它必须打真模型的原因:它守的
// 缺陷在 mock 里**无法存在**——脚本化模型看不看得见图都照本宣科;只有真模型会在拿到没有图的 receipt 时
// 断定生成失败、再点一次(ADR 0017 的产地否决当年正是如此——否决开 4 次出图撞 MAX_STEPS,否决关 1 次
// 干净收工,各跑两遍零分歧)。故断言就是**花钱计数器本身**:一个回合、一次上游出图调用、completed 收尾。
// 谁要是在 tool_result 与模型之间重新引入一道否决——按产地、按模态、按「优化」——先红的就是这条。
func TestLiveMedia_GeneratedImageFedBackOnce(t *testing.T) {
	t.Parallel()
	wc, rec, _ := liveQwen(t, "live-fedback-once")

	// Bound the blast radius: if the guard DOES catch a relapse, the loop must burn 4 images, not 25.
	// 钳住爆炸半径:守卫真抓到复发时,循环烧 4 张、不是 25 张。
	wc.PATCH("/api/v1/limits", map[string]any{"agent": map[string]any{"maxSteps": 4}}).OK(t, nil)

	convID := convCreate(t, wc, "回喂守卫")
	mid := sendMsg(t, wc, convID, "画一座黄昏的红色灯塔,然后用一句话说说你画了什么。")
	turn := waitTurn(t, wc, convID, mid, 240000)

	if gen := rec.CallsTo(dashScopeGenPath); gen != 1 {
		traceModel(t, rec)
		t.Fatalf("generation calls in one turn = %d, want exactly 1 — a re-draw loop means the model "+
			"never saw its own artifact (ADR 0020 relapse)", gen)
	}
	if turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	// And the confirmation signal is real: some model request after the tool call carries the
	// artifact's actual bytes as a native image part — the receipt alone was the whole disease.
	// 确认信号是真的:工具调用之后的某次模型请求里,带着产物**真实字节**的原生 image part——
	// 只有 receipt 没有图,正是整场病。
	attID := attachmentFrom(t, turn, "generate_image")
	content := wc.DoRaw("GET", "/api/v1/attachments/"+attID+"/content", "", nil)
	if content.Status != 200 || !bytes2IsImage(content.Raw) {
		t.Fatalf("artifact must round-trip as a real image: HTTP %d, %d bytes", content.Status, len(content.Raw))
	}
	b64 := base64.StdEncoding.EncodeToString(content.Raw)
	for _, d := range rec.Dumps() {
		if d.HasImagePart(b64) {
			return
		}
	}
	traceModel(t, rec)
	t.Fatal("the generated image never reached the model as pixels — the confirmation signal is missing")
}
