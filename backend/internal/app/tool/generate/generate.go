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

// providerSpec is one provider's hand-written generation entry (代拍 B6: models.dev's
// generation-side coverage is too thin to follow — P1's jurisdiction is the CHAT catalog). Shared
// by every generation capability: the shape of "which model, on which origin" does not vary by
// modality, and a second copy of it would be the first place the two drift.
//
// providerSpec 是一家手写生成条目(代拍 B6:models.dev 生成侧覆盖太薄,P1 辖区是聊天目录)。**各生成
// 能力共用**:「用哪个模型、在哪个 origin」的形状不随模态变化,而抄第二份就是两者开始漂移的地方。
type providerSpec struct {
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
var imageProviders = map[string]providerSpec{
	"anselm": {},
	"openai": {defaultModel: "gpt-image-2"},
	"google": {defaultModel: "gemini-3.1-flash-image-preview"},
	"qwen":   {defaultModel: "qwen-image-2.0", nativeBase: "https://dashscope.aliyuncs.com"},
	"zhipu":  {defaultModel: "cogview-4"},
}

var imageProviderOrder = []string{"anselm", "openai", "google", "qwen", "zhipu"}

// speechProviders is the closed set of direct-connection speech-capable providers, plus the
// managed gateway. It is hand-written for a sharper reason than the image table: the capability
// catalog CANNOT discover any of it. `TrimUpstreamCatalog`'s chat predicate keeps only models with
// tool_call and text output, which filters every pure-TTS model out of the catalog entirely — so
// there is nothing to read even if we wanted to.
//
// speechProviders 是直连语音家的封闭集 + 受管网关。它手写的理由比图像表更硬:能力目录**发现不了**
// 它的任何一项——`TrimUpstreamCatalog` 的 chat 谓词只留有 tool_call 且输出含文本的模型,这把每个
// 纯 TTS 模型整个滤出了目录,故即使想读也无物可读。
var speechProviders = map[string]providerSpec{
	"anselm": {},
	"openai": {defaultModel: "gpt-4o-mini-tts"},
	"google": {defaultModel: "gemini-2.5-flash-preview-tts", nativeBase: "https://generativelanguage.googleapis.com/v1beta"},
	"qwen":   {defaultModel: "qwen3-tts-flash", nativeBase: "https://dashscope.aliyuncs.com"},
	"zhipu":  {defaultModel: "glm-tts"},
}

var speechProviderOrder = []string{"anselm", "openai", "qwen", "zhipu", "google"}

// defaultVoiceFor is each dialect's default voice. A voice name is NOT portable across providers
// (Cherry exists only at DashScope, coral only at OpenAI, Kore only at Gemini), so an unset voice
// must resolve per route rather than carry one global string — sending "Cherry" to OpenAI is a
// 400, and that failure would look like "speech is broken" rather than "wrong voice name".
//
// defaultVoiceFor 是各方言的默认音色。音色名**不跨家通用**(Cherry 只在 DashScope、coral 只在
// OpenAI、Kore 只在 Gemini),故未设音色必须**按路由**解析、而不是带一个全局串——把 "Cherry" 发给
// OpenAI 是一个 400,而那次失败看起来会像「语音坏了」而不是「音色名不对」。
func defaultVoiceFor(provider string) string {
	switch provider {
	case "openai":
		return "coral"
	case "google":
		return "Kore"
	case "qwen":
		return "Cherry"
	case "zhipu":
		return "tongtong"
	default:
		return "" // managed: the gateway fills its own configured default / 受管:网关填自己的默认
	}
}

// ErrNoImageRoute — no key on this workspace can generate images. The tool is not injected in
// this state (honest absence); the sentinel exists for the direct-call race.
//
// ErrNoImageRoute——本 workspace 没有任何 key 能出图。此态下工具不注入(诚实缺席);sentinel 为
// 直接调用的竞态而存在。
var ErrNoImageRoute = errorspkg.New(errorspkg.KindUnprocessable, "IMAGE_NO_ROUTE", "no configured key can generate images")

// ErrNoSpeechRoute — no key on this workspace can synthesize speech (the ErrNoImageRoute twin).
//
// ErrNoSpeechRoute——本 workspace 没有任何 key 能合成语音(ErrNoImageRoute 的孪生)。
var ErrNoSpeechRoute = errorspkg.New(errorspkg.KindUnprocessable, "SPEECH_NO_ROUTE", "no configured key can synthesize speech")

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

// genRoute is one resolved way to generate (any modality).
// genRoute 是一条解析出的生成路由(任意模态)。
type genRoute struct {
	provider  string
	model     string
	key       string // API key (direct) — never logged / API key(直连)——绝不入日志
	baseURL   string
	installID string // managed gateway only / 仅受管网关
}

// resolveImage picks the route. Explicit scenario config wins; otherwise managed-first fallback.
//
// resolveImage 选路。显式场景配置优先;否则受管优先兜底。
func (r *Router) resolveImage(ctx context.Context) (genRoute, error) {
	return r.resolveIn(ctx, modeldomain.ScenarioImage, imageProviders, imageProviderOrder, ErrNoImageRoute)
}

// resolveIn is the shared routing law for every generation capability: the workspace's explicit
// scenario default wins (§3.2), else fall back over tested keys in the capability's own preference
// order, managed gateway first (zero-config free tier). The CAPABILITY varies only in its scenario,
// its provider table and its no-route sentinel — everything else (probe filtering, first-key-per-
// provider, a stale probe row not killing the whole fallback) is one law, and a second copy of it
// is where image and speech would silently start behaving differently.
//
// resolveIn 是各生成能力共用的选路法则:workspace 显式场景默认优先(§3.2),否则在已探测 key 上按
// 该能力自己的偏好序兜底、受管网关优先(免费档零配置)。**能力**之间只差场景、provider 表与无路
// sentinel 三样——其余(探测过滤、每家取第一把、陈旧探测行不拖垮整条兜底)是一条法则,而抄第二份
// 正是图像与语音会开始静默地表现不同的地方。
func (r *Router) resolveIn(
	ctx context.Context,
	scenario string,
	specs map[string]providerSpec,
	order []string,
	noRoute error,
) (genRoute, error) {
	if r == nil || r.Picker == nil || r.Keys == nil || r.Probes == nil {
		return genRoute{}, noRoute
	}
	if ref, err := r.Picker.Pick(ctx, scenario); err == nil && !ref.IsZero() {
		creds, err := r.Keys.ResolveCredentialsByID(ctx, ref.APIKeyID)
		if err != nil {
			return genRoute{}, fmt.Errorf("%s scenario key: %w", scenario, err)
		}
		return r.routeIn(specs, noRoute, creds.Provider, ref.ModelID, creds.Key, creds.BaseURL)
	}
	probed, err := r.Probes.ListProbed(ctx)
	if err != nil {
		return genRoute{}, fmt.Errorf("%s fallback: %w", scenario, err)
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
	for _, provider := range order {
		pk, ok := byProvider[provider]
		if !ok {
			continue
		}
		creds, err := r.Keys.ResolveCredentialsByID(ctx, pk.ID)
		if err != nil {
			continue // a stale probe row must not kill the whole fallback / 陈旧探测行不拖垮整条兜底
		}
		return r.routeIn(specs, noRoute, provider, "", creds.Key, creds.BaseURL)
	}
	return genRoute{}, noRoute
}

func (r *Router) routeIn(specs map[string]providerSpec, noRoute error, provider, model, key, baseURL string) (genRoute, error) {
	spec, ok := specs[provider]
	if !ok {
		return genRoute{}, fmt.Errorf("%w: provider %q", noRoute, provider)
	}
	if provider == "anselm" {
		// The managed row's "key" IS the public install id; the gateway owns model choice.
		// 受管行的「key」即公开 install id;模型选择归网关。
		return genRoute{provider: provider, baseURL: baseURL, installID: key}, nil
	}
	if model == "" || model == llminfra.AnselmModelID {
		model = spec.defaultModel
	}
	if spec.nativeBase != "" {
		baseURL = spec.nativeBase
	}
	return genRoute{provider: provider, model: model, key: key, baseURL: baseURL}, nil
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
func (r *Router) generate(ctx context.Context, route genRoute, prompt, aspect string) (llminfra.GeneratedImage, error) {
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

// resolveSpeech picks the speech route (the resolveImage twin, same law, its own table).
//
// resolveSpeech 选语音路(resolveImage 的孪生,同一法则、自己的表)。
func (r *Router) resolveSpeech(ctx context.Context) (genRoute, error) {
	return r.resolveIn(ctx, modeldomain.ScenarioSpeech, speechProviders, speechProviderOrder, ErrNoSpeechRoute)
}

// SpeechAvailable reports whether generate_speech should exist for this request (honest absence).
//
// SpeechAvailable 报告 generate_speech 本次请求该不该存在(诚实缺席)。
func (r *Router) SpeechAvailable(ctx context.Context) bool {
	_, err := r.resolveSpeech(ctx)
	return err == nil
}

// synthesize speaks one whole text over the resolved route, splitting it into per-provider-sized
// chunks and rejoining the audio. The chunking lives HERE rather than in the tool because the
// limit is a property of the ROUTE, and here rather than in the gateway because a gateway-side
// split would make one reservation cover N upstream calls (代拍 C5).
//
// synthesize 在解析出的路由上说完整段文本:按该家上限切块、再把音频接回来。切块住在**这里**而非
// 工具层,因为上限是**路由**的属性;住在这里而非网关,因为网关侧切块会让一次预留覆盖 N 次上游调用
// (代拍 C5)。
func (r *Router) synthesize(ctx context.Context, route genRoute, text, voice string) (llminfra.GeneratedAudio, error) {
	if voice == "" {
		voice = defaultVoiceFor(route.provider)
	}
	chunks := llminfra.SplitSpeechText(text, llminfra.SpeechChunkLimit(route.provider))
	if len(chunks) == 0 {
		return llminfra.GeneratedAudio{}, ErrTextRequired
	}
	parts := make([]llminfra.GeneratedAudio, 0, len(chunks))
	for _, chunk := range chunks {
		part, err := r.synthesizeChunk(ctx, route, chunk, voice)
		if err != nil {
			// One failed chunk fails the utterance: half a sentence read aloud is worse than an
			// honest error, and the partial chunks were already billed either way.
			// 一块失败即整段失败:念半句话比诚实报错更糟,而已成的块无论如何都已计费。
			return llminfra.GeneratedAudio{}, err
		}
		parts = append(parts, part)
	}
	return llminfra.ConcatAudio(parts)
}

func (r *Router) synthesizeChunk(ctx context.Context, route genRoute, text, voice string) (llminfra.GeneratedAudio, error) {
	switch route.provider {
	case "anselm":
		return llminfra.GenerateSpeechAnselm(ctx, r.HTTP, route.baseURL, route.installID, text, voice)
	case "openai", "zhipu":
		return llminfra.GenerateSpeechOpenAIForm(ctx, r.HTTP, route.provider, route.baseURL, route.key, route.model, text, voice)
	case "qwen":
		return llminfra.GenerateSpeechDashScope(ctx, r.HTTP, route.baseURL, route.key, route.model, text, voice)
	case "google":
		return llminfra.GenerateSpeechGemini(ctx, r.HTTP, route.baseURL, route.key, route.model, text, voice)
	default:
		return llminfra.GeneratedAudio{}, ErrNoSpeechRoute
	}
}

// GenerateTools builds the family over its route + persistence dependencies. The returned slice is
// what bootstrap's CapabilityTools closure filters per request.
//
// GenerateTools 在路由 + 落盘依赖上构建本族。返回切片由 bootstrap 的 CapabilityTools 闭包逐请求过滤。
func GenerateTools(router *Router, attachments Uploader) []ToolWithAvailability {
	return []ToolWithAvailability{
		{Tool: &GenerateImage{router: router, attachments: attachments}, Available: router.ImageAvailable},
		{Tool: &GenerateSpeech{router: router, attachments: attachments}, Available: router.SpeechAvailable},
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
// extFor maps an artifact mime to a filename extension. The audio arms are not cosmetic: the
// extension is what a desktop file manager and a player use to decide how to open the file, and a
// WAV landing as `.png` is a file the user cannot play by double-clicking it.
//
// extFor 把产物 mime 映到扩展名。音频那几支不是装饰:扩展名决定文件管理器与播放器怎么打开它,一个
// 落成 `.png` 的 WAV 是用户双击打不开的文件。
func extFor(mime string) string {
	switch mime {
	case "image/jpeg":
		return "jpg"
	case "image/webp":
		return "webp"
	case "audio/wav", "audio/x-wav", "audio/wave":
		return "wav"
	case "audio/mpeg", "audio/mp3":
		return "mp3"
	case "audio/ogg", "audio/opus":
		return "ogg"
	case "audio/aac":
		return "aac"
	case "audio/flac", "audio/x-flac":
		return "flac"
	default:
		if strings.HasPrefix(mime, "audio/") {
			// An unknown audio subtype must not become a .png; keep the subtype as the extension.
			// 未知音频子类型不得变成 .png;拿子类型当扩展名。
			return strings.TrimPrefix(mime, "audio/")
		}
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
