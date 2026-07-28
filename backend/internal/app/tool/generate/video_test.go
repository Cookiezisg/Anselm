package generate

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
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

// TestVideo_DashScopeSubmitPollFetch drives the whole async chain against a fake wan upstream: the
// MANDATORY async header on submit (and its absence on the poll), wan2.7's resolution+ratio shape
// (never the retired `size`), the six-state vocabulary normalized to phases, and the artifact
// fetched from a BARE pre-signed url — with NO auth header, because sending one can make the object
// store reject it.
//
// 对假 wan 上游驱动整条异步链:提交上的**强制**异步头(与轮询上它的缺席)、wan2.7 的 resolution+ratio
// 形(绝不发已退休的 `size`)、六态词表归一成 phase、从**裸**预签名 url 取回产物且**不带**鉴权头——
// 带上可能被对象存储拒绝。
func TestVideo_DashScopeSubmitPollFetch(t *testing.T) {
	var submitAsync, pollAsync, artifactAuth string
	var params map[string]any
	polls := 0
	var origin string
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case strings.HasSuffix(r.URL.Path, "/video-synthesis"):
			submitAsync = r.Header.Get("X-DashScope-Async")
			var body map[string]any
			_ = json.NewDecoder(r.Body).Decode(&body)
			params, _ = body["parameters"].(map[string]any)
			_ = json.NewEncoder(w).Encode(map[string]any{"output": map[string]any{"task_id": "task_1"}})
		case strings.Contains(r.URL.Path, "/tasks/"):
			pollAsync = r.Header.Get("X-DashScope-Async")
			polls++
			if polls >= 2 {
				_ = json.NewEncoder(w).Encode(map[string]any{"output": map[string]any{
					"task_status": "SUCCEEDED", "video_url": origin + "/artifact.mp4"}})
				return
			}
			_ = json.NewEncoder(w).Encode(map[string]any{"output": map[string]any{"task_status": "RUNNING"}})
		default:
			artifactAuth = r.Header.Get("Authorization")
			w.Header().Set("Content-Type", "video/mp4")
			_, _ = w.Write([]byte("mp4-bytes"))
		}
	}))
	defer srv.Close()
	origin = srv.URL
	up := &fakeUploader{}
	out, err := videoTool(t, videoRouter(t, "qwen", srv.URL, srv.Client()), up).
		Execute(context.Background(), `{"prompt":"a cat","seconds":5}`)
	if err != nil {
		t.Fatalf("execute: %v", err)
	}
	if submitAsync != "enable" {
		t.Fatalf("submit async header = %q — without it the API refuses the call outright", submitAsync)
	}
	if pollAsync != "" {
		t.Fatalf("the poll must NOT carry the async header, got %q", pollAsync)
	}
	if params["resolution"] != "720P" || params["ratio"] != "16:9" {
		t.Fatalf("wan2.7 must send resolution+ratio, got %v", params)
	}
	if _, hasSize := params["size"]; hasSize {
		t.Fatalf("wan2.7 must NOT send the retired `size` field: %v", params)
	}
	if artifactAuth != "" {
		t.Fatalf("a bare pre-signed url must be fetched with NO auth header, got %q", artifactAuth)
	}
	if polls < 2 {
		t.Fatalf("polls = %d — the loop must keep asking until a terminal state", polls)
	}
	var receipt map[string]any
	if err := json.Unmarshal([]byte(out), &receipt); err != nil {
		t.Fatalf("receipt not JSON: %v (%s)", err, out)
	}
	if receipt["source"] != "generate_video" || receipt["provider"] != "qwen" || receipt["seconds"] != float64(5) {
		t.Fatalf("receipt = %v", receipt)
	}
	if !strings.HasSuffix(up.last.Filename, ".mp4") {
		t.Fatalf("artifact filename = %q, want .mp4", up.last.Filename)
	}
}

// TestVideo_GeminiCarriesTheKeyOnFetch: the opposite half of the same trap. Google's artifact uri
// REQUIRES the api key on fetch, while DashScope's must not carry one — "got a url, therefore I can
// download it" is false for both, in opposite directions.
//
// 同一个陷阱的另一半。Google 的产物 uri 取回时**必须**带 api key,而 DashScope 的**不能**带——
// 「拿到 url 就能下」对两家都不成立,且不成立的方向相反。
func TestVideo_GeminiCarriesTheKeyOnFetch(t *testing.T) {
	var sentDuration, artifactKey string
	var origin string
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case strings.Contains(r.URL.Path, "predictLongRunning"):
			var body map[string]any
			_ = json.NewDecoder(r.Body).Decode(&body)
			params, _ := body["parameters"].(map[string]any)
			sentDuration, _ = params["durationSeconds"].(string)
			_ = json.NewEncoder(w).Encode(map[string]any{"name": "models/veo/operations/op1"})
		case strings.Contains(r.URL.Path, "/operations/"):
			_ = json.NewEncoder(w).Encode(map[string]any{
				"done": true,
				"response": map[string]any{"generateVideoResponse": map[string]any{
					"generatedSamples": []any{map[string]any{"video": map[string]any{"uri": origin + "/file.mp4"}}},
				}},
			})
		default:
			artifactKey = r.Header.Get("x-goog-api-key")
			w.Header().Set("Content-Type", "video/mp4")
			_, _ = w.Write([]byte("mp4-bytes"))
		}
	}))
	defer srv.Close()
	origin = srv.URL
	if _, err := videoTool(t, videoRouter(t, "google", srv.URL, srv.Client()), &fakeUploader{}).
		Execute(context.Background(), `{"prompt":"a cat","seconds":8}`); err != nil {
		t.Fatalf("execute: %v", err)
	}
	if sentDuration != "8" {
		t.Fatalf("durationSeconds = %q, want the STRING \"8\" this wire requires", sentDuration)
	}
	if artifactKey != "sk" {
		t.Fatalf("gemini artifact fetch must carry the api key, got %q", artifactKey)
	}
}

// TestVideo_ImpossibleLengthIsClampedNotSpent: Veo caps at 8 seconds, so a 30-second ask is CLAMPED
// to what the route can do rather than sent up to buy an upstream rejection — and the receipt
// reports the length actually made, never the one that was asked for.
//
// Veo 封顶 8 秒,故 30 秒的请求被**钳**到本路由做得到的长度、而不是送上去买一个上游拒绝——且 receipt
// 报的是**真正做出来**的长度、绝不是被请求的那个。
func TestVideo_ImpossibleLengthIsClampedNotSpent(t *testing.T) {
	var sentDuration string
	var origin string
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case strings.Contains(r.URL.Path, "predictLongRunning"):
			var body map[string]any
			_ = json.NewDecoder(r.Body).Decode(&body)
			params, _ := body["parameters"].(map[string]any)
			sentDuration, _ = params["durationSeconds"].(string)
			_ = json.NewEncoder(w).Encode(map[string]any{"name": "models/veo/operations/op1"})
		case strings.Contains(r.URL.Path, "/operations/"):
			_ = json.NewEncoder(w).Encode(map[string]any{
				"done": true,
				"response": map[string]any{"generateVideoResponse": map[string]any{
					"generatedSamples": []any{map[string]any{"video": map[string]any{"uri": origin + "/file.mp4"}}},
				}},
			})
		default:
			w.Header().Set("Content-Type", "video/mp4")
			_, _ = w.Write([]byte("mp4-bytes"))
		}
	}))
	defer srv.Close()
	origin = srv.URL
	up := &fakeUploader{}
	out, err := videoTool(t, videoRouter(t, "google", srv.URL, srv.Client()), up).
		Execute(context.Background(), `{"prompt":"a cat","seconds":30}`)
	if err != nil {
		t.Fatalf("execute: %v", err)
	}
	if sentDuration != "8" {
		t.Fatalf("durationSeconds sent = %q, want the route's 8-second cap", sentDuration)
	}
	var receipt map[string]any
	_ = json.Unmarshal([]byte(out), &receipt)
	if receipt["seconds"] != float64(8) {
		t.Fatalf("receipt reports %v seconds — it must report what was MADE, not what was asked", receipt["seconds"])
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
