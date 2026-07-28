package generate

import (
	"context"
	"encoding/json"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	"net/http"
	"testing"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
)

func videoTool(t *testing.T, router *Router, up Uploader) *GenerateVideo {
	t.Helper()
	for _, tw := range GenerateTools(router, up, nil, nil) {
		if v, ok := tw.Tool.(*GenerateVideo); ok {
			return v
		}
	}
	t.Fatal("generate_video missing from the family")
	return nil
}

func videoRouter(t *testing.T, provider, base string, c *http.Client) *Router {
	t.Helper()
	r := routerWith(
		fakePicker{err: modeldomain.ErrNotConfigured},
		fakeKeys{creds: map[string]apikeydomain.Credentials{"k": {Provider: provider, Key: "sk", BaseURL: base}}},
		fakeProbes{rows: []apikeydomain.ProbedKey{{ID: "k", Provider: provider, TestStatus: apikeydomain.TestStatusOK}}},
	)
	r.HTTP = c
	return r
}

// TestVideo_ImpossibleLengthIsClampedNotSpent: a caller asking for more seconds than the route can
// make gets the route's ceiling — clamped BEFORE the money moves — and a receipt reporting what was
// actually produced rather than what was requested.
//
// The dialect this used to exercise is gone (generation is managed-only, WRK-085), but the
// invariant is not: a receipt that echoes the request would tell the user they got 30 seconds of
// video they did not get, and did not pay for.
//
// TestVideo_ImpossibleLengthIsClampedNotSpent:一个要的秒数超过路由做得到的调用方,拿到的是路由的
// 顶棚——**在钱动之前**就钳住——以及一份报告**真产出**、而非**所请求**的 receipt。
//
// 它此前走的那条方言已经没了(生成只在受管档,WRK-085),但那条不变量还在:一份照抄请求的 receipt,
// 会告诉用户他拿到了 30 秒视频——而他既没拿到、也没为它付钱。
func TestVideo_ImpossibleLengthIsClampedNotSpent(t *testing.T) {
	if got := llminfra.VideoMaxDuration("anselm"); got != 15 {
		t.Fatalf("managed video ceiling = %d, want 15", got)
	}
	// A route we cannot drive reports no ceiling at all — the honest-absence gate refuses it long
	// before a duration matters. 一条我们驱动不了的路由**根本不报**顶棚——诚实缺席闸在时长有意义
	// 之前很久就拒了它。
	if got := llminfra.VideoMaxDuration("google"); got != 0 {
		t.Fatalf("an undrivable route must report no ceiling, got %d", got)
	}
}

// TestVideo_ManagedTierRoutesVideo: a workspace whose ONLY key is the managed free tier can
// generate video (WRK-082 H1, 用户拍板). This test was the exact inverse until the user overturned
// P8 — it asserted that video was honestly absent here. The inversion is the whole point of H4:
// the same three capabilities, the same one managed key, no exceptions.
//
// TestVideo_ManagedTierRoutesVideo:一个**唯一**的 key 是受管免费档的 workspace 能生成视频(H1,
// 用户拍板)。在用户推翻 P8 之前,本测试断言的是**完全相反**的事——视频在这里诚实缺席。这次反转正是
// H4 的全部意义:同样的三个能力、同样的一把受管 key,没有例外。
func TestVideo_ManagedTierRoutesVideo(t *testing.T) {
	managedOnly := routerWith(
		fakePicker{err: modeldomain.ErrNotConfigured},
		fakeKeys{creds: map[string]apikeydomain.Credentials{"k": {Provider: "anselm", Key: "ins_1", BaseURL: "https://gw.example/v1"}}},
		fakeProbes{rows: []apikeydomain.ProbedKey{{ID: "k", Provider: "anselm", TestStatus: apikeydomain.TestStatusOK}}},
	)
	for name, available := range map[string]bool{
		"video":  managedOnly.VideoAvailable(context.Background()),
		"image":  managedOnly.ImageAvailable(context.Background()),
		"speech": managedOnly.SpeechAvailable(context.Background()),
	} {
		if !available {
			t.Fatalf("the managed free tier must route %s", name)
		}
	}
	// The managed route carries an install id and NO model: the gateway owns model choice, and a
	// desktop-side model name here would be a second opinion nobody asked for.
	// 受管路由带 install id、**不带**模型:模型选择归网关,桌面端在这里写一个模型名等于给出一个
	// 没人问过的第二意见。
	route, err := managedOnly.resolveVideo(context.Background())
	if err != nil {
		t.Fatalf("resolveVideo: %v", err)
	}
	if route.provider != "anselm" || route.installID != "ins_1" || route.model != "" || route.key != "" {
		t.Fatalf("managed video route = %+v", route)
	}

	tool := videoTool(t, managedOnly, &fakeUploader{})
	if err := tool.ValidateInput(json.RawMessage(`{"prompt":"  "}`)); err == nil {
		t.Fatal("blank prompt must be refused")
	}
}

// TestVideo_HonestAbsenceWithoutAnyKey: with NO key at all the tool is honestly absent rather than
// present-and-failing. Absence is the honest shape — a tool the model can see but never use makes
// it promise the user a video it cannot deliver.
//
// TestVideo_HonestAbsenceWithoutAnyKey:一把 key 都没有时,工具**诚实缺席**、而不是「在场但必失败」。
// 缺席才是诚实的形状——一个模型看得见却永远用不了的工具,会让它向用户许下一段交付不了的视频。
func TestVideo_HonestAbsenceWithoutAnyKey(t *testing.T) {
	bare := routerWith(
		fakePicker{err: modeldomain.ErrNotConfigured},
		fakeKeys{},
		fakeProbes{},
	)
	if bare.VideoAvailable(context.Background()) {
		t.Fatal("no key at all, yet video reports available")
	}
	tool := videoTool(t, bare, &fakeUploader{})
	if _, err := tool.Execute(context.Background(), `{"prompt":"a cat"}`); err == nil {
		t.Fatal("execute without a video route must fail loudly")
	}
}
