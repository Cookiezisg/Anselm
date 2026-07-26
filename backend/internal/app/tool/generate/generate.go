// Package generate is the generation tool family (WRK-082 批B): tools that turn a text
// instruction into media through the workspace's generation scenario routes. Tools here are
// CAPABILITY tools — injected per request only when a route physically exists (honest absence,
// §3.5): the chat host asks Router.ImageAvailable(ctx) through the CapabilityTools seam, so a
// key added or removed mid-session changes the toolset on the very next step, no restart.
//
// Package generate 是生成工具族(批B):把文字指令经 workspace 生成场景路由变成媒体的工具。
// 本族是**能力工具**——仅当路由物理存在时逐请求注入(诚实缺席,§3.5):chat host 经
// CapabilityTools 缝问 Router.ImageAvailable(ctx),key 的增删下一步即生效、零重启。
package generate

import (
	"bytes"
	"context"
	"fmt"
	"image"
	_ "image/jpeg" // dimensions sniffing for the receipt / receipt 尺寸嗅探
	_ "image/png"
	"net/http"
	"strings"
	"time"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// imageProviderSpec is one provider's hand-written image-generation entry (代拍 B6: models.dev's
// generation-side coverage is too thin to follow — P1's jurisdiction is the CHAT catalog).
//
// imageProviderSpec 是一家手写图像生成条目(代拍 B6:models.dev 生成侧覆盖太薄,P1 辖区是聊天目录)。
type imageProviderSpec struct {
	defaultModel string
	// nativeBase overrides the credential's BaseURL for providers whose generation API lives on a
	// different origin than their chat API ("" = use the credential's BaseURL).
	// nativeBase 覆盖凭证 BaseURL——生成 API 与聊天 API 不同 origin 的家用(""=用凭证 BaseURL)。
	nativeBase string
}

// imageProviders is the closed set of direct-connection image-capable providers, plus the managed
// gateway. Order of imageProviderOrder decides the unconfigured-scenario fallback preference.
//
// imageProviders 是直连图像家的封闭集 + 受管网关。imageProviderOrder 的顺序决定未配置场景的兜底偏好。
var imageProviders = map[string]imageProviderSpec{
	"anselm": {},
	"openai": {defaultModel: "gpt-image-2"},
	"google": {defaultModel: "gemini-3.1-flash-image-preview"},
	"qwen":   {defaultModel: "qwen-image-2.0", nativeBase: "https://dashscope.aliyuncs.com"},
	"zhipu":  {defaultModel: "cogview-4"},
}

var imageProviderOrder = []string{"anselm", "openai", "google", "qwen", "zhipu"}

// ErrNoImageRoute — no key on this workspace can generate images. The tool is not injected in
// this state (honest absence); the sentinel exists for the direct-call race.
//
// ErrNoImageRoute——本 workspace 没有任何 key 能出图。此态下工具不注入(诚实缺席);sentinel 为
// 直接调用的竞态而存在。
var ErrNoImageRoute = errorspkg.New(errorspkg.KindUnprocessable, "IMAGE_NO_ROUTE", "no configured key can generate images")

// CredsResolver is the apikey port (satisfied by *apikeyapp.Service).
type CredsResolver interface {
	ResolveCredentialsByID(ctx context.Context, id string) (apikeydomain.Credentials, error)
}

// Uploader is the attachment landing port (satisfied by *attachmentapp.Service): bytes in, a
// first-class attachment row out — the artifact enters the ONE media store (不变量②).
//
// Uploader 是附件落盘端口(*attachmentapp.Service 结构满足):字节进、一等附件行出——产物进
// **唯一一间库**(不变量②)。
type Uploader interface {
	Upload(ctx context.Context, filename, mime string, data []byte) (*attachmentdomain.Attachment, error)
}

// Router resolves which key/dialect serves a generation scenario: the explicit workspace default
// first (§3.2), else the managed gateway row, else the first tested key of an image-capable
// provider (P7).
//
// Router 解析生成场景由哪把 key/方言承接:先 workspace 显式默认(§3.2),再受管网关行,再首个
// 已探测通过的图像家 key(P7)。
type Router struct {
	Picker modeldomain.ModelPicker
	Keys   CredsResolver
	Probes apikeydomain.ProbeReader
	HTTP   *http.Client
}

// imageRoute is one resolved way to generate.
type imageRoute struct {
	provider  string
	model     string
	key       string // API key (direct) — never logged / API key(直连)——绝不入日志
	baseURL   string
	installID string // managed gateway only / 仅受管网关
}

// resolveImage picks the route. Explicit scenario config wins; otherwise managed-first fallback.
//
// resolveImage 选路。显式场景配置优先;否则受管优先兜底。
func (r *Router) resolveImage(ctx context.Context) (imageRoute, error) {
	if r == nil || r.Picker == nil || r.Keys == nil || r.Probes == nil {
		return imageRoute{}, ErrNoImageRoute
	}
	if ref, err := r.Picker.Pick(ctx, modeldomain.ScenarioImage); err == nil && !ref.IsZero() {
		creds, err := r.Keys.ResolveCredentialsByID(ctx, ref.APIKeyID)
		if err != nil {
			return imageRoute{}, fmt.Errorf("image scenario key: %w", err)
		}
		return r.routeFor(creds.Provider, ref.ModelID, creds.Key, creds.BaseURL)
	}
	// Unconfigured: fall back over tested keys, managed gateway first (zero-config free tier).
	// 未配置:在已探测 key 上兜底,受管网关优先(免费档零配置)。
	probed, err := r.Probes.ListProbed(ctx)
	if err != nil {
		return imageRoute{}, fmt.Errorf("image fallback: %w", err)
	}
	byProvider := map[string]apikeydomain.ProbedKey{}
	for _, pk := range probed {
		if pk.TestStatus != apikeydomain.TestStatusOK {
			continue
		}
		if _, seen := byProvider[pk.Provider]; !seen {
			byProvider[pk.Provider] = pk
		}
	}
	for _, provider := range imageProviderOrder {
		pk, ok := byProvider[provider]
		if !ok {
			continue
		}
		creds, err := r.Keys.ResolveCredentialsByID(ctx, pk.ID)
		if err != nil {
			continue // a stale probe row must not kill the whole fallback / 陈旧探测行不拖垮整条兜底
		}
		return r.routeFor(provider, "", creds.Key, creds.BaseURL)
	}
	return imageRoute{}, ErrNoImageRoute
}

func (r *Router) routeFor(provider, model, key, baseURL string) (imageRoute, error) {
	spec, ok := imageProviders[provider]
	if !ok {
		return imageRoute{}, fmt.Errorf("%w: provider %q has no image generation", ErrNoImageRoute, provider)
	}
	if provider == "anselm" {
		// The managed row's "key" IS the public install id; the gateway owns model choice.
		// 受管行的「key」即公开 install id;模型选择归网关。
		return imageRoute{provider: provider, baseURL: baseURL, installID: key}, nil
	}
	if model == "" || model == llminfra.AnselmModelID {
		model = spec.defaultModel
	}
	if spec.nativeBase != "" {
		baseURL = spec.nativeBase
	}
	return imageRoute{provider: provider, model: model, key: key, baseURL: baseURL}, nil
}

// ImageAvailable reports whether generate_image should exist for this request (honest absence).
//
// ImageAvailable 报告 generate_image 本次请求该不该存在(诚实缺席)。
func (r *Router) ImageAvailable(ctx context.Context) bool {
	_, err := r.resolveImage(ctx)
	return err == nil
}

// generate dispatches one image generation over the resolved route.
//
// generate 在解析出的路由上派发一次图像生成。
func (r *Router) generate(ctx context.Context, route imageRoute, prompt, aspect string) (llminfra.GeneratedImage, error) {
	size := llminfra.ImageSizeFor(route.provider, aspect)
	switch route.provider {
	case "anselm":
		return llminfra.GenerateImageAnselm(ctx, r.HTTP, route.baseURL, route.installID, prompt, size)
	case "openai":
		return llminfra.GenerateImageOpenAI(ctx, r.HTTP, route.baseURL, route.key, route.model, prompt, size)
	case "google":
		return llminfra.GenerateImageGemini(ctx, r.HTTP, route.baseURL, route.key, route.model, prompt)
	case "qwen":
		return llminfra.GenerateImageDashScope(ctx, r.HTTP, route.baseURL, route.key, route.model, prompt, size)
	case "zhipu":
		return llminfra.GenerateImageZhipu(ctx, r.HTTP, route.baseURL, route.key, route.model, prompt, size)
	default:
		return llminfra.GeneratedImage{}, ErrNoImageRoute
	}
}

// GenerateTools builds the family over its route + persistence dependencies. The returned slice is
// what bootstrap's CapabilityTools closure filters per request.
//
// GenerateTools 在路由 + 落盘依赖上构建本族。返回切片由 bootstrap 的 CapabilityTools 闭包逐请求过滤。
func GenerateTools(router *Router, attachments Uploader) []ToolWithAvailability {
	return []ToolWithAvailability{
		{Tool: &GenerateImage{router: router, attachments: attachments}, Available: router.ImageAvailable},
	}
}

// ToolWithAvailability pairs a tool with its per-request existence predicate.
//
// ToolWithAvailability 把工具与其逐请求存在谓词配对。
type ToolWithAvailability struct {
	Tool      toolapp.Tool
	Available func(ctx context.Context) bool
}

// extFor maps a mime to the artifact filename extension.
func extFor(mime string) string {
	switch mime {
	case "image/jpeg":
		return "jpg"
	case "image/webp":
		return "webp"
	default:
		return "png"
	}
}

// sniffDims best-effort reads pixel dimensions for the receipt (png/jpeg; 0,0 = unknown).
//
// sniffDims 尽力读像素尺寸入 receipt(png/jpeg;0,0=未知)。
func sniffDims(data []byte) (w, h int) {
	cfg, _, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return 0, 0
	}
	return cfg.Width, cfg.Height
}

func artifactFilename(mime string) string {
	return fmt.Sprintf("generated-%s.%s", time.Now().UTC().Format("20060102-150405"), extFor(mime))
}

func normalizedAspect(aspect string) (string, error) {
	switch strings.TrimSpace(aspect) {
	case "", "square":
		return "square", nil
	case "landscape":
		return "landscape", nil
	case "portrait":
		return "portrait", nil
	default:
		return "", fmt.Errorf("aspect must be one of square, landscape, portrait")
	}
}
