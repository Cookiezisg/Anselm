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

// TestLiveMedia_SpendLedgerRecordsRealMoney is H10's acceptance, and it has to be real money for
// the same reason the ledger exists: a mocked generation books a mocked row, which proves the
// plumbing and nothing about whether the ledger sees what the user is actually charged for. Here a
// real image is generated against a real key, and the projection must show ONE image with a
// non-zero estimate — units counted, money estimated, exactly the two-part honesty contract.
//
// TestLiveMedia_SpendLedgerRecordsRealMoney 是 H10 的验收,而它必须是真钱,理由与台账存在的理由相同:
// 一次 mock 生成记一行 mock 账,证明的是管道通、而非台账是否看得见用户**真正被收费**的那件事。这里用
// 真 key 真出一张图,投影必须显示**一张图 + 非零估算**——用量数出来、金额是估算,恰是那份两半的诚实契约。
func TestLiveMedia_SpendLedgerRecordsRealMoney(t *testing.T) {
	t.Parallel()
	wc, _, _ := liveQwen(t, "live-spend")

	var before struct {
		Rows []struct {
			Category string `json:"category"`
			Units    int64  `json:"units"`
			EstPUSD  int64  `json:"estPUSD"`
		} `json:"rows"`
		Estimated bool `json:"estimated"`
	}
	wc.GET("/api/v1/spend").OK(t, &before)
	if len(before.Rows) != 0 {
		t.Fatalf("a fresh workspace must have an empty ledger, got %+v", before.Rows)
	}
	// The envelope stamps `estimated` so no client can read the money without reading that it is
	// an estimate. 信封盖 `estimated`,使任何客户端都无法只读钱数而不读「这是估算」。
	if !before.Estimated {
		t.Fatal("the spend envelope must declare estimated:true even when empty")
	}

	convID := convCreate(t, wc, "支出台账验收")
	mid := sendMsg(t, wc, convID, "画一座黄昏的红色灯塔,然后用一句话说说你画了什么。")
	if turn := waitTurn(t, wc, convID, mid, 240000); turn.Status != "completed" {
		t.Fatalf("turn must complete, got %s err=%s/%s", turn.Status, turn.ErrorCode, turn.ErrorMessage)
	}

	var after struct {
		Rows []struct {
			Category string `json:"category"`
			Provider string `json:"provider"`
			Units    int64  `json:"units"`
			EstPUSD  int64  `json:"estPUSD"`
		} `json:"rows"`
	}
	wc.GET("/api/v1/spend").OK(t, &after)
	if len(after.Rows) != 1 {
		t.Fatalf("ledger rows = %+v, want exactly one image cell", after.Rows)
	}
	r := after.Rows[0]
	if r.Category != "image" || r.Provider != "qwen" || r.Units != 1 {
		t.Fatalf("row = %+v, want one qwen image", r)
	}
	// The price table knows qwen's image model, so a zero here means the estimate never ran —
	// which would leave the panel showing a dash for money that was really spent.
	// 价目表认识 qwen 的图像模型,故这里为 0 意味着估算根本没跑——面板会为**真花掉的钱**显示破折号。
	if r.EstPUSD <= 0 {
		t.Fatalf("est = %d, want a non-zero estimate for a priced model", r.EstPUSD)
	}
}
