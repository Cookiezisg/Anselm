package generate

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"image"
	"image/png"
	"net/http"
	"net/http/httptest"
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

type fakeUploader struct{ last *attachmentdomain.Attachment }

func (f *fakeUploader) Upload(_ context.Context, filename, mime string, data []byte) (*attachmentdomain.Attachment, error) {
	f.last = &attachmentdomain.Attachment{
		ID: "att_generated0001", Filename: filename, MimeType: mime, SizeBytes: int64(len(data)),
	}
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
		if !r.ImageAvailable(context.Background()) {
			t.Fatal("available must be true with an explicit route")
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

// TestExecute_EndToEndOpenAI drives the whole tool against a fake OpenAI upstream: b64 artifact →
// uploaded attachment → receipt JSON with real dimensions.
//
// TestExecute_EndToEndOpenAI 对假 OpenAI 上游全链驱动工具:b64 产物 → 落附件 → 带真实尺寸的
// receipt JSON。
func TestExecute_EndToEndOpenAI(t *testing.T) {
	var buf bytes.Buffer
	if err := png.Encode(&buf, image.NewRGBA(image.Rect(0, 0, 7, 5))); err != nil {
		t.Fatal(err)
	}
	pngBytes := buf.Bytes()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/images/generations" {
			t.Errorf("path = %s", r.URL.Path)
		}
		var req map[string]any
		_ = json.NewDecoder(r.Body).Decode(&req)
		if req["model"] != "gpt-image-2" || req["size"] != "1536x1024" {
			t.Errorf("wire = %v, want default model + landscape size", req)
		}
		_ = json.NewEncoder(w).Encode(map[string]any{
			"data": []map[string]any{{"b64_json": base64.StdEncoding.EncodeToString(pngBytes)}},
		})
	}))
	defer srv.Close()

	router := routerWith(
		fakePicker{err: modeldomain.ErrNotConfigured},
		fakeKeys{creds: map[string]apikeydomain.Credentials{"aki_o": {Provider: "openai", Key: "sk", BaseURL: srv.URL + "/v1"}}},
		fakeProbes{rows: []apikeydomain.ProbedKey{{ID: "aki_o", Provider: "openai", TestStatus: apikeydomain.TestStatusOK}}},
	)
	up := &fakeUploader{}
	tools := GenerateTools(router, up)
	if len(tools) != 1 || tools[0].Tool.Name() != "generate_image" {
		t.Fatalf("family = %v", tools)
	}
	out, err := tools[0].Tool.Execute(context.Background(), `{"prompt":"a lighthouse","aspect":"landscape"}`)
	if err != nil {
		t.Fatalf("execute: %v", err)
	}
	var receipt map[string]any
	if err := json.Unmarshal([]byte(out), &receipt); err != nil {
		t.Fatalf("receipt not JSON: %v (%s)", err, out)
	}
	if receipt["attachmentId"] != "att_generated0001" || receipt["mime"] != "image/png" ||
		receipt["provider"] != "openai" || receipt["source"] != "generate_image" {
		t.Fatalf("receipt = %v", receipt)
	}
	if receipt["width"] != float64(7) || receipt["height"] != float64(5) {
		t.Fatalf("dims = %v×%v, want 7×5 sniffed from real bytes", receipt["width"], receipt["height"])
	}
	if up.last == nil || !strings.HasPrefix(up.last.Filename, "generated-") {
		t.Fatalf("uploaded = %+v", up.last)
	}
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
