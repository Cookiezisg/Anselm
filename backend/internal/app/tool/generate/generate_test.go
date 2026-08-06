package generate

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"net/http"
	"strings"
	"testing"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
)

type fakePicker struct {
	ref modeldomain.ModelRef
	err error
}

func (f fakePicker) Pick(context.Context, string) (modeldomain.ModelRef, error) {
	if f.err != nil {
		return modeldomain.ModelRef{}, f.err
	}
	return f.ref, nil
}

type fakeKeys struct {
	creds map[string]apikeydomain.Credentials
}

func (f fakeKeys) ResolveCredentialsByID(_ context.Context, id string) (apikeydomain.Credentials, error) {
	c, ok := f.creds[id]
	if !ok {
		return apikeydomain.Credentials{}, fmt.Errorf("key %s not found", id)
	}
	return c, nil
}

type fakeProbes struct{ rows []apikeydomain.ProbedKey }

func (f fakeProbes) ListProbed(context.Context) ([]apikeydomain.ProbedKey, error) { return f.rows, nil }

type fakeUploader struct {
	last *attachmentdomain.Attachment
	// Data keeps the uploaded BYTES: for audio the joined stream is the thing under test, and a
	// row with only a byte count cannot prove the chunks were rejoined into one playable file.
	// Data 留下上传的**字节**:音频这边被测的正是那条拼好的流,而只有字节数的行证明不了「块被接成
	// 了一个可播放文件」。
	Data []byte
}

func (f *fakeUploader) Upload(_ context.Context, filename, mime string, data []byte) (*attachmentdomain.Attachment, error) {
	f.last = &attachmentdomain.Attachment{
		ID: "att_generated0001", Filename: filename, MimeType: mime, SizeBytes: int64(len(data)),
	}
	f.Data = data
	return f.last, nil
}

func routerWith(picker modeldomain.ModelPicker, keys CredsResolver, probes apikeydomain.ProbeReader) *Router {
	return &Router{Picker: picker, Keys: keys, Probes: probes, HTTP: http.DefaultClient}
}

// TestRoute_FiveBatteries walks the routing contract: explicit config / managed fallback / BYOK
// fallback / no route at all / a configured provider with no image capability.
//
// TestRoute_FiveBatteries 走路由契约五电池:显式配置 / 受管兜底 / BYOK 兜底 / 全无路由 /
// 配置指向无图像能力家。
func TestRoute_FiveBatteries(t *testing.T) {
	notConfigured := fakePicker{err: modeldomain.ErrNotConfigured}

	t.Run("explicit config wins", func(t *testing.T) {
		r := routerWith(
			fakePicker{ref: modeldomain.ModelRef{APIKeyID: "aki_1", ModelID: "gpt-image-2"}},
			fakeKeys{creds: map[string]apikeydomain.Credentials{"aki_1": {Provider: "openai", Key: "sk", BaseURL: "https://api.openai.com/v1"}}},
			fakeProbes{},
		)
		route, err := r.resolveImage(context.Background())
		if err != nil || route.provider != "openai" || route.model != "gpt-image-2" {
			t.Fatalf("route = %+v, %v", route, err)
		}
		// **Resolving is not the same as being available (WRK-085).** The picker still honours an
		// explicit BYOK choice — that resolution logic is shared with chat and must keep working —
		// but generation is managed-only, so the tool must not exist for this route. Claiming it
		// would put a model in the position of promising something that fails at the last hop,
		// after the user has already written a prompt.
		// **解析得出 ≠ 可用(WRK-085)。** 选择器仍然尊重用户显式选的 BYOK 模型——那段解析逻辑与 chat
		// 共用、必须继续工作——但生成只在受管档,故这条路由上工具**不该存在**。照样宣称,等于让模型去许
		// 一个**在最后一跳才失败**的诺,而那时用户已经写完提示词了。
		if r.ImageAvailable(context.Background()) {
			t.Fatal("generation is managed-only; a BYOK route must report the tool absent")
		}
	})

	t.Run("managed fallback first", func(t *testing.T) {
		r := routerWith(notConfigured,
			fakeKeys{creds: map[string]apikeydomain.Credentials{
				"aki_m": {Provider: "anselm", Key: "ins_pub", BaseURL: "https://api.anselm.website/v1"},
				"aki_o": {Provider: "openai", Key: "sk", BaseURL: "https://api.openai.com/v1"},
			}},
			fakeProbes{rows: []apikeydomain.ProbedKey{
				{ID: "aki_o", Provider: "openai", TestStatus: apikeydomain.TestStatusOK},
				{ID: "aki_m", Provider: "anselm", TestStatus: apikeydomain.TestStatusOK},
			}},
		)
		route, err := r.resolveImage(context.Background())
		if err != nil || route.provider != "anselm" || route.installID != "ins_pub" {
			t.Fatalf("route = %+v, %v — managed row must win the fallback", route, err)
		}
	})

	t.Run("byok fallback with default model", func(t *testing.T) {
		r := routerWith(notConfigured,
			fakeKeys{creds: map[string]apikeydomain.Credentials{"aki_z": {Provider: "zhipu", Key: "zk", BaseURL: "https://open.bigmodel.cn/api/paas/v4"}}},
			fakeProbes{rows: []apikeydomain.ProbedKey{
				{ID: "aki_d", Provider: "deepseek", TestStatus: apikeydomain.TestStatusOK},
				{ID: "aki_z", Provider: "zhipu", TestStatus: apikeydomain.TestStatusOK},
			}},
		)
		route, err := r.resolveImage(context.Background())
		if err != nil || route.provider != "zhipu" || route.model != "cogview-4" {
			t.Fatalf("route = %+v, %v — zhipu with its default model", route, err)
		}
	})

	t.Run("no route → honest absence", func(t *testing.T) {
		r := routerWith(notConfigured,
			fakeKeys{},
			fakeProbes{rows: []apikeydomain.ProbedKey{{ID: "aki_d", Provider: "deepseek", TestStatus: apikeydomain.TestStatusOK}}},
		)
		if _, err := r.resolveImage(context.Background()); err == nil {
			t.Fatal("want ErrNoImageRoute")
		}
		if r.ImageAvailable(context.Background()) {
			t.Fatal("available must be false with only text-capable keys")
		}
	})

	t.Run("configured provider without image capability", func(t *testing.T) {
		r := routerWith(
			fakePicker{ref: modeldomain.ModelRef{APIKeyID: "aki_d", ModelID: "deepseek-v4-flash"}},
			fakeKeys{creds: map[string]apikeydomain.Credentials{"aki_d": {Provider: "deepseek", Key: "dk", BaseURL: "https://api.deepseek.com"}}},
			fakeProbes{},
		)
		if _, err := r.resolveImage(context.Background()); err == nil {
			t.Fatal("deepseek route must fail — provider has no image generation")
		}
	})
}

// TestValidateInput_ClosedShape: prompt required + bounded, aspect enum closed.
func TestValidateInput_ClosedShape(t *testing.T) {
	tool := &GenerateImage{}
	for name, args := range map[string]string{
		"empty prompt":   `{"prompt":"  "}`,
		"bad aspect":     `{"prompt":"p","aspect":"wide"}`,
		"oversized":      fmt.Sprintf(`{"prompt":%q}`, strings.Repeat("字", 2001)),
		"malformed json": `{`,
	} {
		if err := tool.ValidateInput(json.RawMessage(args)); err == nil {
			t.Errorf("%s: want validation error", name)
		}
	}
	if err := tool.ValidateInput(json.RawMessage(`{"prompt":"a cat"}`)); err != nil {
		t.Errorf("valid input rejected: %v", err)
	}
}

func TestLocalizedEditPromptPreservesUnmentionedContent(t *testing.T) {
	got := localizedEditPrompt("Change the red circle to blue")
	if !strings.HasPrefix(got, "Change the red circle to blue\n\n") {
		t.Fatalf("prompt lost the user's instruction: %q", got)
	}
	for _, phrase := range []string{"background", "composition", "texture", "object count", "only the requested change"} {
		if !strings.Contains(strings.ToLower(got), phrase) {
			t.Errorf("prompt missing preservation guard %q: %q", phrase, got)
		}
	}
}

func TestApplyPreciseColorSwapPreservesBackground(t *testing.T) {
	const size = 32
	src := image.NewRGBA(image.Rect(0, 0, size, size))
	for y := 0; y < size; y++ {
		for x := 0; x < size; x++ {
			if x >= 8 && x < 24 && y >= 8 && y < 24 {
				src.SetRGBA(x, y, color.RGBA{R: 220, G: 20, B: 20, A: 255})
			} else {
				src.SetRGBA(x, y, color.RGBA{R: 250, G: 250, B: 250, A: 255})
			}
		}
	}
	var input bytes.Buffer
	if err := png.Encode(&input, src); err != nil {
		t.Fatal(err)
	}
	got, applied, err := applyPreciseColorSwap(input.Bytes(), "Change only the red circle to blue")
	if err != nil || !applied {
		t.Fatalf("precision swap = applied %v, err %v", applied, err)
	}
	out, _, err := image.Decode(bytes.NewReader(got))
	if err != nil {
		t.Fatal(err)
	}
	if got := color.NRGBAModel.Convert(out.At(0, 0)).(color.NRGBA); got != (color.NRGBA{R: 250, G: 250, B: 250, A: 255}) {
		t.Fatalf("background changed: %+v", got)
	}
	center := color.NRGBAModel.Convert(out.At(16, 16)).(color.NRGBA)
	if center.R > 40 || center.B < 100 {
		t.Fatalf("red source was not recolored to blue: %+v", center)
	}
}

// TestDashScopeNative_PreservesTheUsersRegion is a REGRESSION guard for a real 401 (2026-07-27):
// the generation dialects hardcoded the Beijing origin, so a Singapore key — valid, paid for, and
// working fine for chat — got "Incorrect API key provided" from every generate_* call. DashScope
// serves Beijing, Singapore and per-workspace domains; a key is valid on exactly ONE, and nothing
// in the key says which. The chat base URL is where the user already told us, so generation
// derives from it instead of guessing.
//
// 这是一次真实 401 的**回归**守卫(2026-07-27):生成方言把北京 origin 写死了,于是一把新加坡的 key
// ——合法、付过钱、聊天完全正常——在每一次 generate_* 上都收到「Incorrect API key provided」。
// DashScope 有北京、新加坡与逐 workspace 三种域,一把 key 只在**其中一个**上有效,而 key 本身不说是
// 哪个。聊天 base URL 是用户**已经**告诉过我们的地方,故生成从它派生、不去猜。
func TestDashScopeNative_PreservesTheUsersRegion(t *testing.T) {
	for name, tc := range map[string]struct{ credBase, wantNative string }{
		"singapore": {"https://dashscope-intl.aliyuncs.com/compatible-mode/v1", "https://dashscope-intl.aliyuncs.com"},
		"beijing":   {"https://dashscope.aliyuncs.com/compatible-mode/v1", "https://dashscope.aliyuncs.com"},
		"workspace": {"https://ws_abc.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1", "https://ws_abc.ap-southeast-1.maas.aliyuncs.com"},
		"trailing":  {"https://dashscope-intl.aliyuncs.com/compatible-mode/v1/", "https://dashscope-intl.aliyuncs.com"},
		"proxy":     {"https://my-proxy.internal/dashscope", "https://my-proxy.internal/dashscope"},
	} {
		if got := dashScopeNative(tc.credBase); got != tc.wantNative {
			t.Errorf("%s: dashScopeNative(%q) = %q, want %q", name, tc.credBase, got, tc.wantNative)
		}
	}
	// An empty base falls back to the INTERNATIONAL host, not Beijing: a mainland account can
	// reach it, while the reverse is not true for an international key — so this default fails
	// for fewer people.
	// 空 base 回落**国际**域而非北京:大陆账号到得了它,而反过来对国际 key 不成立——故这个默认值
	// 让更少的人失败。
	if got := dashScopeNative(""); got != "https://dashscope-intl.aliyuncs.com" {
		t.Errorf("empty base fell back to %q", got)
	}

	// And the route really carries it: every qwen generation table derives, none hardcodes.
	// 而路由真的带着它:qwen 的每张生成表都派生、无一硬编码。
	for name, table := range map[string]map[string]providerSpec{
		"image": imageProviders, "speech": speechProviders, "video": videoProviders,
	} {
		spec, ok := table["qwen"]
		if !ok {
			continue
		}
		if spec.nativeFrom == nil {
			t.Errorf("%s: qwen must DERIVE its generation origin, not inherit a hardcoded one", name)
		}
	}
}
