package llm

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	deviceproofinfra "github.com/sunweilin/anselm/backend/internal/infra/deviceproof"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Desktop-side image-generation dialects (WRK-082 批B). Five ways keys can physically generate an
// image, one neutral result: raw bytes + mime. The tool layer owns routing and persistence; this
// file owns each provider's wire only. Sizes arrive as provider-appropriate strings picked by
// ImageSizeFor (P12: the tool exposes a 3-value aspect enum, dialects own concrete resolutions).
//
// 桌面侧图像生成方言(批B)。key 物理上出图的五条 wire,一个中立结果:裸字节 + mime。工具层管路由
// 与落盘;本文件只管各家 wire。尺寸经 ImageSizeFor 译成各家词表(P12:工具只暴露三值 aspect 枚举,
// 方言层拥有具体分辨率)。

// ErrImageGenFailed is the neutral sentinel for a generation the upstream refused or broke on;
// Message carries the human-facing cause (LLM reads it, S20).
//
// ErrImageGenFailed 是上游拒绝/失败的中立 sentinel;Message 携人话原因(LLM 读它,S20)。
var ErrImageGenFailed = errorspkg.New(errorspkg.KindUnavailable, "IMAGE_GEN_FAILED", "image generation failed")

// GeneratedImage is one produced artifact, bytes in hand.
//
// GeneratedImage 是一件已到手的产物。
type GeneratedImage struct {
	Bytes []byte
	Mime  string
}

// imageGenBudget bounds one whole generation (sync upstreams run tens of seconds).
// imageGenBudget 界一次完整生成(同步上游十秒量级)。
const imageGenBudget = 150 * time.Second

// imageMaxBytes caps a downloaded/decoded artifact (defense against a hostile URL).
// imageMaxBytes 封顶下载/解码产物(防恶意 URL)。
const imageMaxBytes = 32 << 20

// ImageSizeFor translates the tool's aspect enum into the provider's concrete size vocabulary
// ("" = the provider takes no size parameter).
//
// ImageSizeFor 把工具的 aspect 枚举译成该家具体尺寸词表(""=该家无尺寸参数)。
func ImageSizeFor(provider, aspect string) string {
	type sizes struct{ square, landscape, portrait string }
	table := map[string]sizes{
		"openai": {"1024x1024", "1536x1024", "1024x1536"},
		"zhipu":  {"1024x1024", "1440x720", "720x1440"},
		"qwen":   {"1024*1024", "1344*768", "768*1344"},
		"anselm": {"1024x1024", "1344x768", "768x1344"},
	}
	s, ok := table[provider]
	if !ok {
		return ""
	}
	switch aspect {
	case "landscape":
		return s.landscape
	case "portrait":
		return s.portrait
	default:
		return s.square
	}
}

// GenerateImageAnselm calls the managed gateway's images endpoint. installID rides the deviceproof
// header (the transport signs the exact body); the returned 24h OSS URL is downloaded through the
// same client (the transport passes unmarked requests through untouched).
//
// GenerateImageAnselm 打受管网关 images 端点。installID 走 deviceproof 头(transport 对精确 body
// 签名);返回的 24h OSS URL 经同一 client 下载(transport 对未标记请求原样透传)。
func GenerateImageAnselm(ctx context.Context, httpc *http.Client, baseURL, installID, prompt, size string) (GeneratedImage, error) {
	ctx, cancel := context.WithTimeout(ctx, imageGenBudget)
	defer cancel()
	body, _ := json.Marshal(map[string]any{"prompt": prompt, "size": size, "n": 1})
	req, err := newImageRequest(ctx, strings.TrimRight(baseURL, "/")+"/images/generations", body)
	if err != nil {
		return GeneratedImage{}, err
	}
	req.Header.Set(deviceproofinfra.HeaderInstallID, installID)
	raw, err := doImageRequest(httpc, req, "anselm")
	if err != nil {
		return GeneratedImage{}, err
	}
	var wire struct {
		Data []struct {
			URL string `json:"url"`
		} `json:"data"`
	}
	if err := json.Unmarshal(raw, &wire); err != nil || len(wire.Data) == 0 || wire.Data[0].URL == "" {
		return GeneratedImage{}, fmt.Errorf("%w: gateway returned no artifact url", ErrImageGenFailed)
	}
	return downloadImage(ctx, httpc, wire.Data[0].URL)
}

// EditImageAnselm edits through the managed gateway (WRK-082 H9). The source rides as a base64
// data URL in the request body — the SAME shape ADR 0011 mandates for every managed media input:
// the gateway refuses anything carrying a scheme or host, because a fetchable address is the SSRF
// primitive that shape constraint exists to remove.
//
// EditImageAnselm 经受管网关改图(H9)。源图以 base64 data URL 走在请求体里——与 ADR 0011 为**每一种**
// 受管媒体输入规定的**同一形状**:网关拒收任何带 scheme 或 host 的东西,因为「可取回的地址」正是那条
// 形状约束要拿掉的 SSRF 原语。
func EditImageAnselm(ctx context.Context, httpc *http.Client, baseURL, installID, prompt, size string, source DataURL) (GeneratedImage, error) {
	ctx, cancel := context.WithTimeout(ctx, imageGenBudget)
	defer cancel()
	body, _ := json.Marshal(map[string]any{
		"prompt": prompt, "size": size, "n": 1, "image": source.String(),
	})
	req, err := newImageRequest(ctx, strings.TrimRight(baseURL, "/")+"/images/edits", body)
	if err != nil {
		return GeneratedImage{}, err
	}
	req.Header.Set(deviceproofinfra.HeaderInstallID, installID)
	raw, err := doImageRequest(httpc, req, "anselm")
	if err != nil {
		return GeneratedImage{}, err
	}
	var wire struct {
		Data []struct {
			URL string `json:"url"`
		} `json:"data"`
	}
	if err := json.Unmarshal(raw, &wire); err != nil || len(wire.Data) == 0 || wire.Data[0].URL == "" {
		return GeneratedImage{}, fmt.Errorf("%w: gateway returned no artifact url", ErrImageGenFailed)
	}
	return downloadImage(ctx, httpc, wire.Data[0].URL)
}

func imageDashScope(ctx context.Context, httpc *http.Client, nativeBase, key, model, prompt, size string, source *DataURL) (GeneratedImage, error) {
	ctx, cancel := context.WithTimeout(ctx, imageGenBudget)
	defer cancel()
	content := []map[string]any{}
	if source != nil {
		// Image FIRST, text second — the documented order, and the one every multimodal model reads
		// as "here is the thing, here is what to do with it".
		// **先图后文**——文档给的顺序,也是每个多模态模型读作「这是那个东西、这是要对它做的事」的顺序。
		content = append(content, map[string]any{"image": source.String()})
	}
	content = append(content, map[string]any{"text": prompt})
	payload := map[string]any{
		"model": model,
		"input": map[string]any{
			"messages": []map[string]any{{"role": "user", "content": content}},
		},
		"parameters": map[string]any{"size": size, "n": 1, "watermark": false},
	}
	body, _ := json.Marshal(payload)
	req, err := newImageRequest(ctx, strings.TrimRight(nativeBase, "/")+"/api/v1/services/aigc/multimodal-generation/generation", body)
	if err != nil {
		return GeneratedImage{}, err
	}
	req.Header.Set("Authorization", "Bearer "+key)
	raw, err := doImageRequest(httpc, req, "qwen")
	if err != nil {
		return GeneratedImage{}, err
	}
	var wire struct {
		Output struct {
			Choices []struct {
				Message struct {
					Content []struct {
						Image string `json:"image"`
					} `json:"content"`
				} `json:"message"`
			} `json:"choices"`
		} `json:"output"`
	}
	if err := json.Unmarshal(raw, &wire); err != nil {
		return GeneratedImage{}, fmt.Errorf("%w: dashscope response undecodable", ErrImageGenFailed)
	}
	for _, c := range wire.Output.Choices {
		for _, chunk := range c.Message.Content {
			if chunk.Image != "" {
				return downloadImage(ctx, httpc, chunk.Image)
			}
		}
	}
	return GeneratedImage{}, fmt.Errorf("%w: dashscope returned no artifact url", ErrImageGenFailed)
}

func newImageRequest(ctx context.Context, u string, body []byte) (*http.Request, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, u, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrImageGenFailed, err)
	}
	req.Header.Set("Content-Type", "application/json")
	return req, nil
}

// doImageRequest runs one call and normalizes failures into ErrImageGenFailed with a bounded,
// human-facing reason (status + a short sanitized body excerpt — the LLM needs enough to adjust,
// F7; keys never appear in bodies).
//
// doImageRequest 跑一次调用,失败归一成 ErrImageGenFailed + 有界人话原因(状态 + 短净化 body
// 摘录——LLM 需要足够信息自调,F7;body 里不会有 key)。
func doImageRequest(httpc *http.Client, req *http.Request, provider string) ([]byte, error) {
	resp, err := httpc.Do(req)
	if err != nil {
		return nil, ErrImageGenFailed.WithDetails(map[string]any{"upstream": fmt.Sprintf("%s: %v", provider, err)})
	}
	defer func() { _ = resp.Body.Close() }()
	raw, err := io.ReadAll(io.LimitReader(resp.Body, imageMaxBytes))
	if err != nil {
		return nil, ErrImageGenFailed.WithDetails(map[string]any{"upstream": fmt.Sprintf("%s: read: %v", provider, err)})
	}
	if resp.StatusCode != http.StatusOK {
		excerpt := strings.TrimSpace(string(raw))
		if len(excerpt) > 300 {
			excerpt = excerpt[:300] + "…"
		}
		return nil, ErrImageGenFailed.WithDetails(map[string]any{"upstream": fmt.Sprintf("%s: HTTP %d: %s", provider, resp.StatusCode, excerpt)})
	}
	return raw, nil
}

// downloadImage fetches a returned artifact URL (https only) and sniffs its mime.
//
// downloadImage 拉取返回的产物 URL(仅 https),嗅探 mime。
func downloadImage(ctx context.Context, httpc *http.Client, rawURL string) (GeneratedImage, error) {
	u, err := url.Parse(rawURL)
	if err != nil || u.Scheme != "https" || u.Host == "" {
		return GeneratedImage{}, fmt.Errorf("%w: artifact url malformed", ErrImageGenFailed)
	}
	cctx, cancel := context.WithTimeout(ctx, imageGenBudget)
	defer cancel()
	req, err := http.NewRequestWithContext(cctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return GeneratedImage{}, fmt.Errorf("%w: %v", ErrImageGenFailed, err)
	}
	resp, err := httpc.Do(req)
	if err != nil {
		return GeneratedImage{}, fmt.Errorf("%w: artifact download: %v", ErrImageGenFailed, err)
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return GeneratedImage{}, fmt.Errorf("%w: artifact download: HTTP %d", ErrImageGenFailed, resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, imageMaxBytes+1))
	if err != nil || len(data) == 0 {
		return GeneratedImage{}, fmt.Errorf("%w: artifact download: %v", ErrImageGenFailed, err)
	}
	if len(data) > imageMaxBytes {
		return GeneratedImage{}, fmt.Errorf("%w: artifact exceeds the size cap", ErrImageGenFailed)
	}
	mime := resp.Header.Get("Content-Type")
	if mime == "" || strings.HasPrefix(mime, "application/octet-stream") {
		mime = http.DetectContentType(data)
	}
	if i := strings.IndexByte(mime, ';'); i > 0 {
		mime = strings.TrimSpace(mime[:i])
	}
	return GeneratedImage{Bytes: data, Mime: mime}, nil
}

// DataURL is a媒体 payload in the one shape every generation upstream accepts without a fetch:
// `data:<mime>;base64,<bytes>`. It exists as a TYPE rather than a bare string so a caller cannot
// accidentally hand a raw URL to a parameter that must never carry one — the whole reason the
// managed path refuses scheme/host inputs (ADR 0011) is that a fetchable address is an SSRF
// primitive, and the same discipline belongs on the direct path.
//
// DataURL 是一份媒体载荷,形状是每个生成上游都无需回取即可接受的那一种:`data:<mime>;base64,<字节>`。
// 它是一个**类型**而非裸字符串,好让调用方不可能把一个裸 URL 递进一个绝不该带 URL 的参数——受管路径
// 拒收 scheme/host(ADR 0011)的全部理由就是「可取回的地址是一个 SSRF 原语」,这条纪律在直连路径上同样成立。
type DataURL struct {
	Mime  string
	Bytes []byte
}

// String renders the data URL. An empty mime degrades to application/octet-stream rather than
// emitting `data:;base64,` — a malformed URL would fail upstream with a message about syntax
// instead of about the missing type.
//
// String 渲出 data URL。mime 为空时退化成 application/octet-stream、而非吐出 `data:;base64,`
// ——畸形 URL 会让上游报一个关于语法的错,而不是关于缺类型的错。
func (d DataURL) String() string {
	mime := d.Mime
	if mime == "" {
		mime = "application/octet-stream"
	}
	return "data:" + mime + ";base64," + base64.StdEncoding.EncodeToString(d.Bytes)
}
