package generate

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
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

// TestVideo_ImpossibleLengthIsClampedOnWireAndReceipt verifies the product-facing invariant on
// the live managed route: a request above the route ceiling is reduced before submission, and the
// receipt reports the clip that was actually requested from the gateway.
func TestVideo_ImpossibleLengthIsClampedOnWireAndReceipt(t *testing.T) {
	var submittedSeconds float64
	var server *httptest.Server
	server = httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.Method == http.MethodPost && r.URL.Path == "/v1/videos/generations":
			if got := r.Header.Get("X-Anselm-Install-ID"); got != "sk" {
				t.Fatalf("managed install id = %q, want sk", got)
			}
			var body map[string]any
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				t.Fatalf("decode generation request: %v", err)
			}
			submittedSeconds, _ = body["seconds"].(float64)
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusAccepted)
			_, _ = w.Write([]byte(`{"id":"video-clamp-handle"}`))
		case r.Method == http.MethodGet && r.URL.Path == "/v1/videos/video-clamp-handle":
			w.Header().Set("Content-Type", "application/json")
			_, _ = w.Write([]byte(`{"status":"succeeded","url":"` + server.URL + `/artifact"}`))
		case r.Method == http.MethodGet && r.URL.Path == "/artifact":
			w.Header().Set("Content-Type", "video/mp4")
			_, _ = w.Write([]byte("fake-video-bytes"))
		default:
			t.Fatalf("unexpected gateway request: %s %s", r.Method, r.URL.Path)
		}
	}))
	defer server.Close()

	r := videoRouter(t, "anselm", server.URL+"/v1", server.Client())
	tool := videoTool(t, r, &fakeUploader{})
	receipt, err := tool.Execute(context.Background(), `{"prompt":"a paper boat","seconds":30}`)
	if err != nil {
		t.Fatalf("clamped video: %v", err)
	}
	if submittedSeconds != 15 {
		t.Fatalf("submitted seconds = %v, want managed ceiling 15", submittedSeconds)
	}
	var got map[string]any
	if err := json.Unmarshal([]byte(receipt), &got); err != nil {
		t.Fatalf("receipt is not JSON: %v", err)
	}
	if gotSeconds, _ := got["seconds"].(float64); gotSeconds != 15 {
		t.Fatalf("receipt seconds = %v, want the actual 15-second output", gotSeconds)
	}
}

// TestVideo_ContextTimeoutSaysTheUpstreamMayStillComplete locks the expensive-task failure
// contract: once the gateway accepted the job, cancelling this turn must not imply that the
// upstream job was cancelled. The user gets the durable error code and an honest recovery hint.
func TestVideo_ContextTimeoutSaysTheUpstreamMayStillComplete(t *testing.T) {
	var polls int
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodGet {
			polls++
			t.Fatalf("poll %d happened after the turn was cancelled", polls)
		}
		if r.Method != http.MethodPost || r.URL.Path != "/v1/videos/generations" {
			t.Fatalf("unexpected gateway request: %s %s", r.Method, r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusAccepted)
		_, _ = w.Write([]byte(`{"id":"video-timeout-handle"}`))
		// Let the accepted response reach the client, then cancel the local turn before its first
		// poll. The remote task is intentionally left running from the caller's perspective.
		time.AfterFunc(10*time.Millisecond, cancel)
	}))
	defer server.Close()

	r := videoRouter(t, "anselm", server.URL+"/v1", http.DefaultClient)
	tool := videoTool(t, r, &fakeUploader{})
	_, err := tool.Execute(ctx, `{"prompt":"a quiet paper boat","seconds":5}`)
	if err == nil {
		t.Fatal("cancelled video turn unexpectedly succeeded")
	}
	if !errors.Is(err, llminfra.ErrVideoGenFailed) {
		t.Fatalf("error = %v, want VIDEO_GEN_FAILED", err)
	}
	if !strings.Contains(err.Error(), "may still complete") {
		t.Fatalf("error = %q, want an honest upstream-continuation hint", err)
	}
	if polls != 0 {
		t.Fatalf("polls = %d, want no poll after the turn was cancelled", polls)
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
	if managedOnly.VideoEditAvailable(context.Background()) {
		t.Fatal("a managed gateway that only advertises video_generation must not expose animate_image")
	}

	i2v := routerWith(
		fakePicker{err: modeldomain.ErrNotConfigured},
		fakeKeys{creds: map[string]apikeydomain.Credentials{"k": {Provider: "anselm", Key: "ins_1", BaseURL: "https://gw.example/v1"}}},
		fakeProbes{rows: []apikeydomain.ProbedKey{{ID: "k", Provider: "anselm", TestStatus: apikeydomain.TestStatusOK,
			TestResponse: `{"data":[{"id":"anselm-auto","anselm_capabilities":{"version":1,"routing":"content","video_generation":{"available":true,"image_to_video":true}}}]}`}}},
	)
	if !i2v.VideoEditAvailable(context.Background()) {
		t.Fatal("explicit managed image_to_video capability must expose animate_image")
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
