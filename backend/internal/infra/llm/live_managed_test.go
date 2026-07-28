package llm

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"

	deviceproofinfra "github.com/sunweilin/anselm/backend/internal/infra/deviceproof"
)

// live_managed_test.go — the REAL-MONEY acceptance for the managed free tier (WRK-082 H3/H7).
//
// It is the only test in this repo that talks to the production gateway with real credentials and
// spends real money, so it is gated behind EVALS_MANAGED=1 and never runs in `make verify`. Point
// it at a deployment with ANSELM_GATEWAY_URL (default: production).
//
// What it exists to answer is a question no mock can: **does the whole chain work on the real
// thing?** Every layer below has been proven against a fake — and a fake agrees with whatever the
// code believes. This one asks the gateway that is actually deployed, using a device key it just
// generated, exactly as a user's first launch would.
//
// live_managed_test.go —— 受管免费档的**真钱验收**(H3/H7)。
//
// 它是本仓唯一一个用真凭证连生产网关、花真钱的测试,故由 EVALS_MANAGED=1 门控、绝不进 `make verify`。
// 用 ANSELM_GATEWAY_URL 指向某个部署(默认:生产)。
//
// 它存在是为了回答一个 mock 回答不了的问题:**在真东西上,整条链到底通不通?** 下面每一层都已在假件上
// 证过——而假件总是同意代码所相信的一切。这一个问它的是**真正部署着的**那个网关,用一把刚生成的设备
// 密钥,与一个用户首次启动时**一模一样**。

func liveGateway(t *testing.T) (baseURL, installID string, httpc *http.Client) {
	t.Helper()
	if os.Getenv("EVALS_MANAGED") != "1" {
		t.Skip("set EVALS_MANAGED=1 to run the real-money managed-tier acceptance")
	}
	baseURL = strings.TrimRight(os.Getenv("ANSELM_GATEWAY_URL"), "/")
	if baseURL == "" {
		baseURL = "https://api.anselm.website/v1"
	}

	// An EPHEMERAL device key: a fresh install every run, which is exactly the shape of a first
	// launch. Reusing a stored key would let a run pass on quota some earlier run had already
	// established.
	// **临时**设备密钥:每次跑都是一次全新 install,这正是首次启动的形状。复用一把存下来的密钥,会让
	// 一次运行靠着**上一次**已经建立好的额度通过。
	signer, err := deviceproofinfra.LoadOrCreate(context.Background(), "", noopEncryptor{})
	if err != nil {
		t.Fatalf("device key: %v", err)
	}
	// Install goes through the SAME proof transport as everything after it. Registration is not an
	// exception to device proof — it is the first request that has to carry one, and sending it
	// bare answers 401 with no hint that a signature was what was missing.
	// 注册与其后的一切走**同一条** proof transport。登记不是 device proof 的例外——它是**第一个**必须
	// 带签名的请求,裸着送出去会答 401,而那个 401 一个字也没提缺的是签名。
	httpc = NewHTTPClient()
	httpc.Timeout = 8 * time.Minute
	httpc.Transport = deviceproofinfra.NewTransport(httpc.Transport, signer)

	res, err := NewInstallClient(httpc, signer.PublicKey()).Install(
		context.Background(), baseURL, signer.Thumbprint(), "anselm-acceptance/1.0")
	if err != nil {
		t.Fatalf("install at %s: %v", baseURL, err)
	}
	t.Logf("installed: %s (monthly quota %d, resets %s)", res.InstallID, res.MonthlyQuota, res.ResetAt)
	return baseURL, res.InstallID, httpc
}

// TestLiveManaged_CapabilitiesAdvertised is the cheapest of the three and the one that catches the
// most: a capability that is coded, tested and deployed but left switched OFF in the deploy env is
// invisible to every test that does not ask the running deployment. That happened — IMAGE_ENABLED
// and SPEECH_ENABLED were never written into build-stage.sh at all.
//
// TestLiveManaged_CapabilitiesAdvertised 是三者里最便宜、也是抓得最多的一个:一个写完了、测过了、
// 部署了、却在部署 env 里**没打开**的能力,对任何不去问「正在跑的那个部署」的测试都是隐形的。
// 这件事**真的发生过**——IMAGE_ENABLED 与 SPEECH_ENABLED 从来就没被写进 build-stage.sh。
func TestLiveManaged_CapabilitiesAdvertised(t *testing.T) {
	baseURL, installID, httpc := liveGateway(t)

	raw := liveGET(t, httpc, baseURL+"/models", installID)
	var wire struct {
		Data []struct {
			ID                 string `json:"id"`
			AnselmCapabilities struct {
				ImageGeneration  *struct{ Available bool } `json:"image_generation"`
				SpeechGeneration *struct{ Available bool } `json:"speech_generation"`
				VideoGeneration  *struct{ Available bool } `json:"video_generation"`
			} `json:"anselm_capabilities"`
		} `json:"data"`
	}
	if err := json.Unmarshal(raw, &wire); err != nil || len(wire.Data) == 0 {
		t.Fatalf("models response unreadable: %s (%v)", raw, err)
	}
	caps := wire.Data[0].AnselmCapabilities
	for name, profile := range map[string]*struct{ Available bool }{
		"image_generation":  caps.ImageGeneration,
		"speech_generation": caps.SpeechGeneration,
		"video_generation":  caps.VideoGeneration,
	} {
		if profile == nil {
			t.Fatalf("%s absent from the deployed capability surface: %s", name, raw)
		}
		if !profile.Available {
			t.Fatalf("%s is deployed but NOT AVAILABLE — the capability is off in the deploy env", name)
		}
	}
	t.Logf("all three generation capabilities are live on %s", baseURL)
}

// TestLiveManaged_ImageAndSpeech spends real money on one image and one short utterance, and
// downloads both artifacts to prove the relayed URL is genuinely fetchable — a URL that parses is
// not a URL that works.
//
// TestLiveManaged_ImageAndSpeech 花真钱生成一张图与一小段话,并把两个产物**下载下来**,以证明直通的
// URL 是真的取得回来——一个解析得了的 URL 不等于一个用得了的 URL。
func TestLiveManaged_ImageAndSpeech(t *testing.T) {
	baseURL, installID, httpc := liveGateway(t)

	img := GenerateImageAnselm
	got, err := img(context.Background(), httpc, baseURL, installID, "a lighthouse at dusk, painterly", "1024x1024")
	if err != nil {
		t.Fatalf("managed image generation: %v", err)
	}
	if len(got.Bytes) == 0 || !strings.HasPrefix(got.Mime, "image/") {
		t.Fatalf("image artifact = %d bytes, mime %q", len(got.Bytes), got.Mime)
	}
	t.Logf("image: %d bytes, %s", len(got.Bytes), got.Mime)

	// Omit voice deliberately: the managed gateway owns the model-specific default. Sending the
	// former qwen3-tts preset (Cherry) here would turn this product acceptance into a stale-provider
	// test — qwen-audio-3.0 correctly rejects that name.
	// 刻意不传 voice:受管网关拥有模型专属默认值。把旧 qwen3-tts 的 Cherry 塞进这里,会把产品验收
	// 变成过期 provider 测试——qwen-audio-3.0 正确地拒绝它。
	audio, err := GenerateSpeechAnselm(context.Background(), httpc, baseURL, installID, "这是一次真钱验收。", "")
	if err != nil {
		t.Fatalf("managed speech synthesis: %v", err)
	}
	if len(audio.Bytes) == 0 {
		t.Fatal("speech artifact is empty")
	}
	t.Logf("speech: %d bytes, %s", len(audio.Bytes), audio.Mime)
}

// TestLiveManaged_Video is the expensive one: a real clip, submitted and polled to a terminal state
// through the gateway's own two-request contract, then downloaded. It is also the only place the
// artifact download of the video path runs against a real https origin.
//
// TestLiveManaged_Video 是最贵的一个:一条真片子,经网关自己的两次请求契约提交并轮询到终态,然后下载。
// 它也是视频路径的产物下载**唯一**一次跑在真 https origin 上的地方。
func TestLiveManaged_Video(t *testing.T) {
	baseURL, installID, httpc := liveGateway(t)

	req := VideoRequest{Prompt: "a paper boat drifting down a rain gutter", DurationSec: 5, Aspect: "landscape", Resolution: "720p"}
	job, err := SubmitVideoAnselm(context.Background(), httpc, baseURL, installID, req)
	if err != nil {
		t.Fatalf("managed video submit: %v", err)
	}
	t.Logf("submitted, handle %s", job.Handle)

	deadline := time.Now().Add(8 * time.Minute)
	for {
		if time.Now().After(deadline) {
			t.Fatalf("video never reached a terminal state within the budget (handle %s)", job.Handle)
		}
		time.Sleep(VideoPollInterval("anselm"))
		st, err := PollVideoAnselm(context.Background(), httpc, baseURL, installID, job.Handle)
		if err != nil {
			t.Fatalf("poll: %v", err)
		}
		t.Logf("phase %s", st.Phase)
		if st.Phase == VideoFailed {
			t.Fatalf("the managed gateway reported a failed generation: %s", st.Reason)
		}
		if st.Phase != VideoSucceeded {
			continue
		}
		video, err := FetchVideoArtifact(context.Background(), httpc, st.Artifact)
		if err != nil {
			t.Fatalf("artifact download: %v", err)
		}
		if len(video.Bytes) == 0 || !strings.HasPrefix(video.Mime, "video/") {
			t.Fatalf("video artifact = %d bytes, mime %q", len(video.Bytes), video.Mime)
		}
		t.Logf("video: %d bytes, %s", len(video.Bytes), video.Mime)
		return
	}
}

func liveGET(t *testing.T, httpc *http.Client, url, installID string) []byte {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set(deviceproofinfra.HeaderInstallID, installID)
	resp, err := httpc.Do(req)
	if err != nil {
		t.Fatalf("GET %s: %v", url, err)
	}
	defer func() { _ = resp.Body.Close() }()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("GET %s: HTTP %d: %s", url, resp.StatusCode, raw)
	}
	return raw
}

// noopEncryptor satisfies the signer's encryptor dependency for the ephemeral (no data dir) path,
// where nothing is ever written or read back.
//
// noopEncryptor 满足 signer 在**临时**(无数据目录)路径上的加密器依赖,那条路上什么都不写、也不读回。
type noopEncryptor struct{}

func (noopEncryptor) Encrypt(_ context.Context, p []byte) ([]byte, error) { return p, nil }
func (noopEncryptor) Decrypt(_ context.Context, c []byte) ([]byte, error) {
	return nil, fmt.Errorf("noopEncryptor: nothing to decrypt")
}
