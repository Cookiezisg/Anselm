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
	voicedomain "github.com/sunweilin/anselm/backend/internal/domain/voice"
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
	// nativeFrom DERIVES the generation origin from the credential's own chat base URL; nil means
	// the credential's base URL already is the generation origin.
	//
	// Deriving rather than hardcoding is not a style choice — it is the only way the user's REGION
	// survives. DashScope serves Beijing, Singapore and per-workspace domains, a key is valid on
	// exactly ONE of them, and nothing in the key says which. A hardcoded origin therefore sends a
	// Singapore key to Beijing and gets a 401 that reads as "your key is bad" (真机实证:同一把 key
	// 北京 401、新加坡 200)。The chat base URL is the one place the user already told us where they
	// live, so generation follows it.
	//
	// nativeFrom 从凭证自己的聊天 base URL **派生**生成 origin;nil = 凭证 base URL 本身就是生成 origin。
	//
	// 派生而非硬编码不是风格选择——它是用户的**区域**得以幸存的唯一方式。DashScope 有北京、新加坡与
	// 逐 workspace 三种域,一把 key 只在**其中一个**上有效,而 key 本身不说是哪个。硬编码 origin 因此会
	// 把新加坡的 key 送去北京,换回一个读作「你的 key 不对」的 401(真机实证:同一把 key 北京 401、
	// 新加坡 200)。聊天 base URL 是用户**已经**告诉过我们他在哪儿的唯一位置,故生成跟着它走。
	nativeFrom func(credBaseURL string) string
}

// dashScopeNative strips the OpenAI-compatible path off a DashScope base URL, leaving the origin
// its NATIVE api (`/api/v1/services/…`) lives on — the same host, a different path.
//
// dashScopeNative 把 DashScope base URL 上的 OpenAI 兼容路径剥掉,留下其**原生** api
// (`/api/v1/services/…`)所在的 origin——同一台主机、不同路径。
func dashScopeNative(credBaseURL string) string {
	u := strings.TrimRight(strings.TrimSpace(credBaseURL), "/")
	u = strings.TrimSuffix(u, "/compatible-mode/v1")
	if u == "" {
		// No credential base at all: fall back to the international host rather than Beijing —
		// a mainland account reaches it too, while the reverse is not true for an intl key.
		// 完全没有凭证 base:回落**国际**域而非北京——大陆账号也能到它,反之对国际 key 不成立。
		return "https://dashscope-intl.aliyuncs.com"
	}
	return strings.TrimRight(u, "/")
}

// imageProviders is the closed set of direct-connection image-capable providers, plus the managed
// gateway. Order of imageProviderOrder decides the unconfigured-scenario fallback preference.
//
// imageProviders 是直连图像家的封闭集 + 受管网关。imageProviderOrder 的顺序决定未配置场景的兜底偏好。
var imageProviders = map[string]providerSpec{
	"anselm": {},
	"openai": {defaultModel: "gpt-image-2"},
	"google": {defaultModel: "gemini-3.1-flash-image-preview"},
	"qwen":   {defaultModel: "qwen-image-2.0", nativeFrom: dashScopeNative},
	"zhipu":  {defaultModel: "cogview-4"},
}

var imageProviderOrder = []string{"anselm", "openai", "google", "qwen", "zhipu"}

// speechProviders is the closed set of direct-connection speech-capable providers, plus the
// managed gateway. It is hand-written for a sharper reason than the image table: the capability
// catalog CANNOT discover any of it: `TrimUpstreamCatalog` keeps only models that can ANSWER IN
// TEXT, and a pure-TTS model answers in audio — so it is not in the catalog and there is nothing to
// read even if we wanted to. (That clause survived H12-b's widening precisely because it is about
// whether a chat can happen at all, unlike `tool_call`, which became a carried fact.)
//
// speechProviders 是直连语音家的封闭集 + 受管网关。它手写的理由比图像表更硬:能力目录**发现不了**
// 它的任何一项——`TrimUpstreamCatalog` 只留**能用文本作答**的模型,而纯 TTS 模型用**音频**作答,故它
// 根本不在目录里、即使想读也无物可读。(这一条在 H12-b 放宽时**留了下来**,恰恰因为它讲的是「一场聊天
// 到底能不能发生」——不像 `tool_call`,那一条已变成随行的事实。)
var speechProviders = map[string]providerSpec{
	"anselm": {},
	"openai": {defaultModel: "gpt-4o-mini-tts"},
	"google": {defaultModel: "gemini-2.5-flash-preview-tts"}, // generation shares the chat origin
	"qwen":   {defaultModel: "qwen3-tts-flash", nativeFrom: dashScopeNative},
	"zhipu":  {defaultModel: "glm-tts"},
}

var speechProviderOrder = []string{"anselm", "openai", "qwen", "zhipu", "google"}

// videoProviders is the closed set of video-capable providers, `anselm` first like its two
// siblings. Video IS in the free tier: the user overturned the earlier reading with "视频要进免费档的。
// 我们要的是一个端到端的完整多模态" and set the allowance at 10 clips a day. A user with no key of
// their own can ask for a video and get one.
//
// OpenAI is absent for a different reason (代拍 D2): its Videos API was announced for removal on
// 2026-09-24. A driver with eight weeks of life would be built, reviewed and deleted without ever
// earning its keep.
//
// videoProviders 是视频家的封闭集,`anselm` 与另两个兄弟一样排在**第一**。视频**在**免费档里:用户
// 推翻了先前那个读法——「视频要进免费档的。我们要的是一个端到端的完整多模态」——并把额度定在一天
// 10 条。一个自己一把 key 都没有的用户,现在开口要视频就能拿到。
// OpenAI 缺席的理由不同(代拍 D2):其 Videos API 已公告 2026-09-24 下线,一个只剩八周寿命的 driver
// 会被建、被复审、被删掉,却从没挣回自己的成本。
var videoProviders = map[string]providerSpec{
	"anselm": {},
	"qwen":   {defaultModel: "wan2.7-t2v", nativeFrom: dashScopeNative},
	"google": {defaultModel: "veo-3.1-fast-generate-preview"}, // generation shares the chat origin
}

var videoProviderOrder = []string{"anselm", "qwen", "google"}

// ErrNoVideoRoute — no key on this workspace can generate video (the ErrNoImageRoute twin).
var ErrNoVideoRoute = errorspkg.New(errorspkg.KindUnprocessable, "VIDEO_NO_ROUTE", "no configured key can generate video")

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

// ErrNoEditRoute — the resolved image route's provider has no reachable edit dialect. Distinct from
// ErrNoImageRoute on purpose: "you have no image key" and "your image key's provider cannot edit"
// are different facts, and collapsing them would send a user hunting for a key they already have.
//
// ErrNoEditRoute——解析出的图像路由那一家**没有**够得着的改图方言。刻意与 ErrNoImageRoute 分开:
// 「你没有出图 key」与「你的出图 key 那家不会改图」是两个不同的事实,合并它们会让用户去找一把他已经
// 有了的 key。
var ErrNoEditRoute = errorspkg.New(errorspkg.KindUnprocessable, "IMAGE_NO_EDIT_ROUTE", "the configured image provider cannot edit images")

// ErrNoVoiceCloneRoute — no key on this workspace can enroll a voice. Voice cloning is narrower
// than speech: a key that speaks does not necessarily clone.
//
// ErrNoVoiceCloneRoute——本 workspace 没有任何 key 能登记音色。克隆比合成窄:会说话的 key 未必会克隆。
var ErrNoVoiceCloneRoute = errorspkg.New(errorspkg.KindUnprocessable, "VOICE_NO_CLONE_ROUTE", "no configured key can clone voices")

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

// Fetcher is the attachment READ port (satisfied by *attachmentapp.Service) — the half the
// X→X tools need (WRK-082 H9). Editing an image, animating one, and cloning a voice all begin by
// reading bytes the user already has, and reading them through the same service that wrote them
// keeps workspace isolation and the blob layout in exactly one place.
//
// Fetcher 是附件的**读**端口(由 *attachmentapp.Service 满足)——X→X 三工具要的那一半(H9)。改图、
// 让图动起来、克隆音色,都从「读用户已有的字节」开始;经**写它们的同一个服务**去读,使 workspace 隔离
// 与 blob 布局只存在于一个地方。
type Fetcher interface {
	Download(ctx context.Context, id string) (*attachmentdomain.Attachment, []byte, error)
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

	// Media uploads a sample through the managed resumable route and returns the gateway's own
	// RELATIVE lease reference. Only voice enrollment uses it — the one upstream that will not take
	// bytes. Optional (nil in tests); the enrollment path checks it.
	// Media 经受管断点上传把样本传上去,返回网关自己的**相对** lease 引用。只有音色登记用它——那个唯一
	// 不肯收字节的上游。可选(测试为 nil);登记路径自己判。
	Media *llminfra.MediaClient

	// Voices turns the NAME a person chose into the id the provider actually knows.
	//
	// **Without it the whole cloning feature is decorative**, and it is decorative in the most
	// expensive way: enrollment succeeds, costs money, and produces a row — and then every attempt to
	// speak in that voice fails at the upstream, because the name `narrator` means something to us
	// and nothing to DashScope. The real-money acceptance found exactly that: enroll → OK, speak →
	// SPEECH_GEN_FAILED. The store had `GetByName` all along, documented as「解析成上游 id」, and
	// nothing called it.
	//
	// It sits on the ROUTER rather than in the tool because read-aloud must resolve identically: the
	// two speech entry points share `synthesize`, and a translation on only one of them would make a
	// voice work when the model speaks and fail when the user presses play.
	//
	// Voices 把**人取的名字**变成**供应商真正认识的 id**。
	//
	// **没有它,整个克隆功能就是装饰**,而且是最贵的那种装饰:登记成功、花掉真钱、落下一行——然后每一次
	// 用那个音色说话都在上游失败,因为 `narrator` 这个名字对**我们**有意义、对 DashScope 什么也不是。
	// 真钱验收抓到的正是这个:登记 → OK,说话 → SPEECH_GEN_FAILED。store 里 `GetByName` 一直都在、
	// 注释还写着「解析成上游 id」,而**没有任何人调用它**。
	//
	// 它挂在 **Router** 上而非工具里,因为朗读必须**同样**解析:两个语音入口共用 `synthesize`,只在其中
	// 一个上做翻译,会让同一个音色「模型说话时能用、用户按播放键时失败」。
	Voices voicedomain.Repository
}

// resolveVoice maps a local voice name to its upstream id, and passes anything else through
// UNCHANGED — preset voices are not rows in our table, and rewriting them would break every
// synthesis that never involved cloning at all.
//
// resolveVoice 把本地音色名映射成上游 id,其余一律**原样透传**——预置音色不是我们表里的行,改写它们会
// 弄坏每一次**根本不涉及克隆**的合成。
func (r *Router) resolveVoice(ctx context.Context, voice string) string {
	name := strings.TrimSpace(voice)
	if r.Voices == nil || name == "" {
		return voice
	}
	v, err := r.Voices.GetByName(ctx, name)
	if err != nil || v == nil || v.UpstreamID == "" {
		return voice
	}
	return v.UpstreamID
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
	if spec.nativeFrom != nil {
		baseURL = spec.nativeFrom(baseURL)
	}
	return genRoute{provider: provider, model: model, key: key, baseURL: baseURL}, nil
}

// ImageAvailable reports whether generate_image should exist for this request (honest absence).
//
// ImageAvailable 报告 generate_image 本次请求该不该存在(诚实缺席)。
// **Managed only (WRK-085, 「写」留给自己).** Every generation capability needs a dialect we hand-write
// and keep current — and every wire surprise this project has paid for landed on that side: one
// vendor serving two tool-argument conventions from two hostnames, TTS available only over a duplex
// WebSocket, voice enrollment refusing bytes and demanding a fetchable URL. BYOK keeps「读」(text and
// multimodal INPUT), whose capability comes from the catalog and whose dialect is the one shape every
// provider agrees on.
//
// **只在受管档(WRK-085,「写」留给自己)。** 每一个生成能力都要一条我们手写并持续跟进的方言——而本项目
// 为之付过钱的每一次线缆意外都落在那一侧:同一家供应商在两个主机名上服务两种工具参数约定、TTS 只在
// 双工 WebSocket 上、音色登记拒收字节只要可取的 URL。BYOK 留下的是**「读」**(文本与多模态**输入**),
// 它的能力来自目录、它的方言是所有供应商唯一一致的那个形状。
func (r *Router) ImageAvailable(ctx context.Context) bool {
	route, err := r.resolveImage(ctx)
	return err == nil && route.provider == "anselm"
}

// generate dispatches one image generation over the resolved route.
//
// generate 在解析出的路由上派发一次图像生成。
func (r *Router) generate(ctx context.Context, route genRoute, prompt, aspect string) (llminfra.GeneratedImage, error) {
	size := llminfra.ImageSizeFor(route.provider, aspect)
	img, err := r.generateDispatch(ctx, route, prompt, size)
	return img, err
}

func (r *Router) generateDispatch(ctx context.Context, route genRoute, prompt, size string) (llminfra.GeneratedImage, error) {
	// **One branch, because there is one route (WRK-085).** Generation is managed-only: its dialects
	// are hand-written and every wire surprise this project paid for landed on that side. A switch
	// with dead arms would read as「we support four vendors」to the next person.
	// **一个分支,因为只剩一条路(WRK-085)。** 生成只在受管档:它的方言全靠手写,而本项目为之付过钱的
	// 每一次线缆意外都落在那一侧。留一个带死分支的 switch,会让下一个人读成「我们支持四家」。
	if route.provider != "anselm" {
		return llminfra.GeneratedImage{}, ErrNoImageRoute
	}
	return llminfra.GenerateImageAnselm(ctx, r.HTTP, route.baseURL, route.installID, prompt, size)
}

// edit dispatches one image EDIT over the image route. It resolves through resolveImage on purpose:
// editing is the image scenario, so a workspace that configured an image key has configured this
// too — asking users to pick a second key for "the same provider, one more content chunk" would be
// a configuration surface invented by our code rather than by the upstream.
//
// The provider table is narrower than generation's, though, and that is the honest part: only qwen
// ships a reachable edit dialect today (官方文档核准 H9 第0步), so every other provider answers
// ErrNoEditRoute and the tool goes ABSENT rather than failing at call time.
//
// edit 在**图像路由**上派发一次改图。刻意经 resolveImage 解析:改图**就是**图像场景,故配好出图 key
// 的 workspace 也就配好了它——为「同一家、多一个 content 块」再要用户挑一把 key,是我们的代码而非上游
// 发明出来的配置面。
//
// 但**能改图的家比能出图的少**,而那正是诚实的那一半:今天只有 qwen 有够得着的改图方言(H9 第0步官方
// 文档核准),故其余各家一律答 ErrNoEditRoute、工具**整个缺席**,而不是到调用时才失败。
func (r *Router) edit(ctx context.Context, route genRoute, prompt, aspect string, source llminfra.DataURL) (llminfra.GeneratedImage, error) {
	size := llminfra.ImageSizeFor(route.provider, aspect)
	var (
		img llminfra.GeneratedImage
		err error
	)
	if route.provider != "anselm" {
		return llminfra.GeneratedImage{}, ErrNoEditRoute
	}
	img, err = llminfra.EditImageAnselm(ctx, r.HTTP, route.baseURL, route.installID, prompt, size, source)
	return img, err
}

// EditAvailable reports whether an edit route resolves — the honest-absence gate for `edit_image`.
//
// EditAvailable 报告改图路由是否解析得出——`edit_image` 的诚实缺席闸。
// **Managed only (WRK-085, 「写」留给自己).** Every generation capability needs a dialect we hand-write
// and keep current — and every wire surprise this project has paid for landed on that side: one
// vendor serving two tool-argument conventions from two hostnames, TTS available only over a duplex
// WebSocket, voice enrollment refusing bytes and demanding a fetchable URL. BYOK keeps「读」(text and
// multimodal INPUT), whose capability comes from the catalog and whose dialect is the one shape every
// provider agrees on.
//
// **只在受管档(WRK-085,「写」留给自己)。** 每一个生成能力都要一条我们手写并持续跟进的方言——而本项目
// 为之付过钱的每一次线缆意外都落在那一侧:同一家供应商在两个主机名上服务两种工具参数约定、TTS 只在
// 双工 WebSocket 上、音色登记拒收字节只要可取的 URL。BYOK 留下的是**「读」**(文本与多模态**输入**),
// 它的能力来自目录、它的方言是所有供应商唯一一致的那个形状。
func (r *Router) EditAvailable(ctx context.Context) bool {
	route, err := r.resolveImage(ctx)
	return err == nil && route.provider == "anselm"
}

// editModelFor resolves the model an EDIT is posted to. On DashScope that is the generation model
// itself: `qwen-image-2.0` is documented as "生成与编辑的融合" and答应了两次真钱验证 (2026-07-28,
// same model, generate then edit, both 200 with an image back).
//
// **The separate `qwen-image-edit*` ids are being retired** (console marks the Plus/Max editing
// models 即将下线), so keeping a second constant would have meant maintaining a model id that is
// scheduled to disappear, in order to do a job the model we already call does natively.
//
// A non-DashScope route keeps whatever its own credential names — the caller passes the resolved
// generation model, and this function's job is only to say "the same one".
//
// editModelFor 解析一次**改图**该投给哪个模型。在 DashScope 上,那就是生成模型自己:`qwen-image-2.0`
// 官方描述即「生成与编辑的融合」,并且两次真钱验证都成立(2026-07-28,同一模型先生成后改图,两次 200
// 且都回来一张图)。
//
// **单独的 `qwen-image-edit*` 那几个 id 正在退役**(控制台把 Plus/Max 改图模型标为「即将下线」),故
// 留着第二个常量,等于为了做一件我们已经在调的模型**原生就会做**的事,去维护一个排期消失的 model id。
//
// 非 DashScope 的路由保留它自己凭证里的名字——调用方传进来的就是解析好的生成模型,本函数的职责只是
// 说一句「就是同一个」。
func editModelFor(genModel string) string { return genModel }

// resolveSpeech picks the speech route (the resolveImage twin, same law, its own table).
//
// resolveSpeech 选语音路(resolveImage 的孪生,同一法则、自己的表)。
func (r *Router) resolveSpeech(ctx context.Context) (genRoute, error) {
	return r.resolveIn(ctx, modeldomain.ScenarioSpeech, speechProviders, speechProviderOrder, ErrNoSpeechRoute)
}

// SpeechAvailable reports whether generate_speech should exist for this request (honest absence).
//
// SpeechAvailable 报告 generate_speech 本次请求该不该存在(诚实缺席)。
// **Managed only (WRK-085, 「写」留给自己).** Every generation capability needs a dialect we hand-write
// and keep current — and every wire surprise this project has paid for landed on that side: one
// vendor serving two tool-argument conventions from two hostnames, TTS available only over a duplex
// WebSocket, voice enrollment refusing bytes and demanding a fetchable URL. BYOK keeps「读」(text and
// multimodal INPUT), whose capability comes from the catalog and whose dialect is the one shape every
// provider agrees on.
//
// **只在受管档(WRK-085,「写」留给自己)。** 每一个生成能力都要一条我们手写并持续跟进的方言——而本项目
// 为之付过钱的每一次线缆意外都落在那一侧:同一家供应商在两个主机名上服务两种工具参数约定、TTS 只在
// 双工 WebSocket 上、音色登记拒收字节只要可取的 URL。BYOK 留下的是**「读」**(文本与多模态**输入**),
// 它的能力来自目录、它的方言是所有供应商唯一一致的那个形状。
func (r *Router) SpeechAvailable(ctx context.Context) bool {
	route, err := r.resolveSpeech(ctx)
	return err == nil && route.provider == "anselm"
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
	// **An unset voice stays unset.** The managed gateway fills its own configured default, and its
	// voice names belong to the model it actually calls (qwen-audio-3.0's carry a `_v3.6` suffix and
	// it rejects the older family's names outright). Guessing one here would send a name the upstream
	// may not know, and that failure reads as「speech is broken」rather than「wrong voice name」.
	// **不设音色就让它空着。** 受管网关会填自己配置的默认值,而那些音色名属于**它真正调用的那个模型**
	// (qwen-audio-3.0 的名字带 `_v3.6` 后缀,且它**直接拒绝**旧家族那套名字)。在这里猜一个,等于发出
	// 一个上游可能不认识的名字,而那次失败读起来像「语音坏了」、不像「音色名不对」。
	voice = r.resolveVoice(ctx, voice)
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
	out, err := llminfra.ConcatAudio(parts)
	return out, err
}

func (r *Router) synthesizeChunk(ctx context.Context, route genRoute, text, voice string) (llminfra.GeneratedAudio, error) {
	if route.provider != "anselm" {
		return llminfra.GeneratedAudio{}, ErrNoSpeechRoute
	}
	return llminfra.GenerateSpeechAnselm(ctx, r.HTTP, route.baseURL, route.installID, text, voice)
}

// SynthesizeSpeech is the read-aloud entry point: the SAME routing and synthesis the tool uses,
// exposed for callers that are not an LLM (WRK-082 P10 — the message action row reads a message
// aloud without spending a single token). It returns the audio plus the route's identity, which
// the caller needs for its cache key: the same text in a different voice is a different artifact.
//
// SynthesizeSpeech 是朗读入口:与工具**同一套**选路与合成,暴露给非 LLM 的调用方(P10——消息动作排
// 读出一条消息,不花一个 token)。它连同音频返回路由身份,因为调用方的缓存键需要它:同一段文字换个
// 音色就是另一件产物。
func (r *Router) SynthesizeSpeech(ctx context.Context, text, voice string) (llminfra.GeneratedAudio, string, string, string, error) {
	route, err := r.resolveSpeech(ctx)
	if err != nil {
		return llminfra.GeneratedAudio{}, "", "", "", err
	}
	audio, err := r.synthesize(ctx, route, text, voice)
	if err != nil {
		return llminfra.GeneratedAudio{}, "", "", "", err
	}
	return audio, route.provider, route.model, voice, nil
}

// SpeechRouteIdentity answers WHICH route a synthesis would take, without calling any upstream.
// Read-aloud needs it to build its cache key before spending anything: the identity is part of
// the key, so without a no-cost way to learn it, every repeat listen would have to synthesize
// first and only then discover it could have been served from disk.
//
// SpeechRouteIdentity 答出一次合成**会走**哪条路由,不打任何上游。朗读要用它在花钱之前构造缓存键:
// 身份是键的一部分,故若没有一条零成本的途径知道它,每次重听都得先合成、然后才发现本可以从盘上取。
func (r *Router) SpeechRouteIdentity(ctx context.Context, voice string) (string, string, string, error) {
	route, err := r.resolveSpeech(ctx)
	if err != nil {
		return "", "", "", err
	}
	// The identity carries the RESOLVED voice, because the cache key is built from it: a voice
	// deleted and re-enrolled under the same name is a different voice upstream, and a key that
	// only knew the name would serve the old one's audio forever.
	// 身份带的是**解析后**的音色,因为缓存键由它构成:一个被删掉、又用同一个名字重新登记的音色,在上游
	// 是**另一个**音色,而一个只认得名字的键会永远端出旧那个的音频。
	return route.provider, route.model, r.resolveVoice(ctx, voice), nil
}

// resolveVideo picks the video route (the resolveImage twin, same law, its own table).
func (r *Router) resolveVideo(ctx context.Context) (genRoute, error) {
	return r.resolveIn(ctx, modeldomain.ScenarioVideo, videoProviders, videoProviderOrder, ErrNoVideoRoute)
}

// VideoAvailable reports whether generate_video should exist for this request (honest absence).
// **Managed only (WRK-085, 「写」留给自己).** Every generation capability needs a dialect we hand-write
// and keep current — and every wire surprise this project has paid for landed on that side: one
// vendor serving two tool-argument conventions from two hostnames, TTS available only over a duplex
// WebSocket, voice enrollment refusing bytes and demanding a fetchable URL. BYOK keeps「读」(text and
// multimodal INPUT), whose capability comes from the catalog and whose dialect is the one shape every
// provider agrees on.
//
// **只在受管档(WRK-085,「写」留给自己)。** 每一个生成能力都要一条我们手写并持续跟进的方言——而本项目
// 为之付过钱的每一次线缆意外都落在那一侧:同一家供应商在两个主机名上服务两种工具参数约定、TTS 只在
// 双工 WebSocket 上、音色登记拒收字节只要可取的 URL。BYOK 留下的是**「读」**(文本与多模态**输入**),
// 它的能力来自目录、它的方言是所有供应商唯一一致的那个形状。
func (r *Router) VideoAvailable(ctx context.Context) bool {
	route, err := r.resolveVideo(ctx)
	return err == nil && route.provider == "anselm"
}

// VideoProgress is the callback a caller uses to surface waiting. It receives an honest STATUS
// LINE, never a percentage: neither supported provider reports one, and synthesizing "elapsed ÷
// estimated" would park a bar at 99% for minutes (Veo's own documented range is 11s–6min). A bar
// that lies is worse than a line that says how long it has been waiting.
//
// VideoProgress 是调用方用来把「在等」显示出来的回调。它收到的是**诚实的状态行**、绝不是百分比:
// 两家都不报进度,而用「已耗时÷预估」合成会让进度条在 99% 停几分钟(Veo 自己文档给的区间是 11 秒到
// 6 分钟)。一个撒谎的进度条比一行「已等多久」更糟。
type VideoProgress func(line string)

// EnrollVoice registers a reference clip as a named voice upstream and returns the id synthesis
// will pass as `voice`. It resolves through the SPEECH route: cloning belongs to the speech
// scenario, and a key that can speak is the only kind that could ever clone.
//
// EnrollVoice 把一段参考音频在上游登记成具名音色,返回合成时作为 `voice` 传的那个 id。它经**语音**
// 路由解析:克隆属于语音场景,而会说话的 key 是唯一有可能会克隆的那种。
func (r *Router) EnrollVoice(ctx context.Context, name, mime string, data []byte) (provider, upstreamID string, err error) {
	route, err := r.resolveSpeech(ctx)
	if err != nil {
		return "", "", err
	}
	// **Managed only, and that is a property of the upstream rather than a product choice.**
	// `voice-enrollment` accepts no bytes — only an address it can fetch (真机实测). A direct-connect
	// user's audio lives in this loopback sidecar behind a bearer token, so there is no address to
	// give: the capability is not merely unimplemented here, it is unreachable. The gateway can do
	// it because it owns a public media host of its own.
	//
	// **只在受管档,而这是上游的属性、不是产品选择。** `voice-enrollment` 不收字节——只收一个它能取的
	// 地址(真机实测)。直连用户的音频住在这个回环 sidecar 的 bearer 之后,**根本没有地址可给**:这个
	// 能力在这里不是「没实现」,是**够不着**。网关做得到,因为它自己拥有一台公开媒体主机。
	if route.provider != "anselm" || r.Media == nil {
		return "", "", ErrNoVoiceCloneRoute
	}
	// Upload first, then name the lease. The client never supplies a host — see EnrollVoiceAnselm.
	// 先上传、再指名 lease。客户端从不提供 host——见 EnrollVoiceAnselm。
	fetchPath, err := r.Media.Upload(ctx, route.baseURL, route.installID, mime, data)
	if err != nil {
		return "", "", err
	}
	leaseID, err := llminfra.LeaseIDFromFetchPath(fetchPath)
	if err != nil {
		return "", "", err
	}
	id, err := llminfra.EnrollVoiceAnselm(ctx, r.HTTP, route.baseURL, route.installID, name, leaseID)
	return route.provider, id, err
}

// DeleteVoice removes an upstream registration. Called BEFORE the local row goes, because the row
// is the only thing that knows the upstream id.
//
// DeleteVoice 删掉一个上游登记。在本地行消失**之前**调用,因为那一行是唯一知道上游 id 的东西。
func (r *Router) DeleteVoice(ctx context.Context, provider, upstreamID string) error {
	route, err := r.resolveSpeech(ctx)
	if err != nil {
		return err
	}
	// Managed only, mirroring enrollment: every row that can exist was created there.
	// 只在受管档,与登记互为镜像:能存在的每一行都是在那里创建的。
	if provider != "anselm" {
		return ErrNoVoiceCloneRoute
	}
	return llminfra.DeleteVoiceAnselm(ctx, r.HTTP, route.baseURL, route.installID, upstreamID)
}

// VoiceCloneAvailable reports whether an enrollment route resolves (honest-absence gate).
//
// **Managed only.** `voice-enrollment` will not take bytes — it fetches an address (真机实测). A
// direct-connect user's audio sits in this loopback sidecar behind a bearer token, so there is no
// address to hand over: the capability is unreachable there, not merely unimplemented. Claiming the
// tool anyway would put a model in the position of promising something that fails at the last hop,
// after the user has already picked a clip and named a voice.
//
// VoiceCloneAvailable 报告登记路由是否解析得出(诚实缺席闸)。
//
// **只在受管档。** `voice-enrollment` 不肯收字节——它去**取一个地址**(真机实测)。直连用户的音频坐在
// 这个回环 sidecar 的 bearer 之后,**没有地址可递**:那个能力在那里是**够不着**、不是「没实现」。照样
// 宣称有这个工具,等于让模型去许一个**在最后一跳才失败**的诺——而那时用户已经挑好了片子、起好了名字。
func (r *Router) VoiceCloneAvailable(ctx context.Context) bool {
	route, err := r.resolveSpeech(ctx)
	if err != nil {
		return false
	}
	return route.provider == "anselm" && r.Media != nil
}

// VideoEditAvailable reports whether an image-to-video route resolves (honest-absence gate for
// `animate_image`). Only qwen ships a reachable i2v dialect today.
//
// VideoEditAvailable 报告图生视频路由是否解析得出(`animate_image` 的诚实缺席闸)。今天只有 qwen 有
// 够得着的 i2v 方言。
// **Managed only (WRK-085, 「写」留给自己).** Every generation capability needs a dialect we hand-write
// and keep current — and every wire surprise this project has paid for landed on that side: one
// vendor serving two tool-argument conventions from two hostnames, TTS available only over a duplex
// WebSocket, voice enrollment refusing bytes and demanding a fetchable URL. BYOK keeps「读」(text and
// multimodal INPUT), whose capability comes from the catalog and whose dialect is the one shape every
// provider agrees on.
//
// **只在受管档(WRK-085,「写」留给自己)。** 每一个生成能力都要一条我们手写并持续跟进的方言——而本项目
// 为之付过钱的每一次线缆意外都落在那一侧:同一家供应商在两个主机名上服务两种工具参数约定、TTS 只在
// 双工 WebSocket 上、音色登记拒收字节只要可取的 URL。BYOK 留下的是**「读」**(文本与多模态**输入**),
// 它的能力来自目录、它的方言是所有供应商唯一一致的那个形状。
func (r *Router) VideoEditAvailable(ctx context.Context) bool {
	route, err := r.resolveVideo(ctx)
	return err == nil && route.provider == "anselm"
}

// generateVideo submits, polls to a terminal phase, and fetches the artifact. It is SYNCHRONOUS by
// decision (ADR 0013): the durable engine is for workflows, and an off-stage form would sever the
// artifact from the turn that asked for it.
//
// generateVideo 提交、轮询到终态、取回产物。**同步是决定**(ADR 0013):durable 引擎是给工作流的,
// 而离场形态会把产物与提出它的那一轮切断。
func (r *Router) generateVideo(ctx context.Context, route genRoute, req llminfra.VideoRequest, prog VideoProgress) (llminfra.GeneratedVideo, error) {
	if prog == nil {
		prog = func(string) {}
	}
	var (
		job llminfra.VideoJob
		err error
	)
	if route.provider != "anselm" {
		return llminfra.GeneratedVideo{}, ErrNoVideoRoute
	}
	job, err = llminfra.SubmitVideoAnselm(ctx, r.HTTP, route.baseURL, route.installID, req)
	if err != nil {
		return llminfra.GeneratedVideo{}, err
	}
	// The managed route has no model of its own to name — the gateway owns that choice — so the
	// line says the provider alone rather than printing an empty pair of parentheses.
	// 受管路由没有自己的模型可报——那个选择归网关——故这行只说 provider,而不是印一对空括号。
	if route.model == "" {
		prog(fmt.Sprintf("submitted to %s\n", route.provider))
	} else {
		prog(fmt.Sprintf("submitted to %s (%s)\n", route.provider, route.model))
	}

	// Ramp INTO the vendor's cadence rather than starting at it. A flat 15s first wait makes a job
	// that failed upstream validation — or one that finished fast — pay a full interval of silence
	// before anyone learns anything. Early polls are cheap; the vendor's documented interval is the
	// CEILING, which is what its rate-limit guidance is actually about.
	// **爬**到厂商的节奏、而不是一上来就用它。固定 15s 的首轮等待,会让一个在上游校验就失败的任务
	// ——或一个很快就好了的任务——先白付一整个周期的沉默。早期轮询很便宜;厂商文档给的间隔是**上限**,
	// 而它的限流建议说的正是上限。
	ceiling := llminfra.VideoPollInterval(route.provider)
	interval := 2 * time.Second
	started := time.Now()
	for {
		select {
		case <-ctx.Done():
			// The turn's wall clock ran out (or the user cancelled). The upstream job keeps going and
			// the money is already spent — say so rather than implying nothing happened.
			// 回合墙钟到点(或用户取消)。上游任务仍在跑、钱已经花了——说出来,别暗示什么都没发生。
			return llminfra.GeneratedVideo{}, fmt.Errorf("%w: gave up waiting after %s; the upstream job %s may still complete",
				llminfra.ErrVideoGenFailed, time.Since(started).Round(time.Second), job.Handle)
		case <-time.After(interval):
		}
		var st llminfra.VideoStatus
		st, err = llminfra.PollVideoAnselm(ctx, r.HTTP, route.baseURL, route.installID, job.Handle)
		if err != nil {
			return llminfra.GeneratedVideo{}, err
		}
		elapsed := time.Since(started).Round(time.Second)
		switch st.Phase {
		case llminfra.VideoSucceeded:
			prog(fmt.Sprintf("generated in %s, downloading…\n", elapsed))
			return llminfra.FetchVideoArtifact(ctx, r.HTTP, st.Artifact)
		case llminfra.VideoFailed:
			return llminfra.GeneratedVideo{}, fmt.Errorf("%w: %s", llminfra.ErrVideoGenFailed, st.Reason)
		default:
			prog(fmt.Sprintf("%s… (%s elapsed)\n", st.Phase, elapsed))
		}
		if interval < ceiling {
			if interval = interval * 3 / 2; interval > ceiling {
				interval = ceiling
			}
		}
	}
}

// GenerateTools builds the family over its route + persistence dependencies. The returned slice is
// what bootstrap's CapabilityTools closure filters per request.
//
// GenerateTools 在路由 + 落盘依赖上构建本族。返回切片由 bootstrap 的 CapabilityTools 闭包逐请求过滤。
func GenerateTools(router *Router, attachments Uploader, source Fetcher, voices voicedomain.Repository) []ToolWithAvailability {
	tools := []ToolWithAvailability{
		{Tool: &GenerateImage{router: router, attachments: attachments}, Available: router.ImageAvailable},
		{Tool: &GenerateSpeech{router: router, attachments: attachments}, Available: router.SpeechAvailable},
		{Tool: &GenerateVideo{router: router, attachments: attachments}, Available: router.VideoAvailable},
	}
	// The X→X family (WRK-082 H9) is appended rather than interleaved so the reading order matches
	// the capability order: everything above makes something from nothing, everything below changes
	// something that already exists.
	//
	// Each carries its OWN availability predicate, narrower than its generating sibling's — being
	// able to draw does not imply being able to edit, and a workspace whose provider cannot edit
	// must see no edit tool at all rather than one that exists and always fails (诚实缺席).
	//
	// X→X 一族(H9)**追加**而非交错,使阅读顺序对上能力顺序:上面全是「无中生有」,下面全是「改已有的」。
	//
	// 每个都带**自己的**可用性谓词,且比它的生成兄弟更窄——会画不等于会改,而家里不会改的 workspace
	// 应该**根本看不到**改图工具,而不是看到一个存在却必然失败的(诚实缺席)。
	tools = append(tools,
		ToolWithAvailability{
			Tool:      &EditImage{router: router, attachments: attachments, source: source},
			Available: router.EditAvailable,
		},
		ToolWithAvailability{
			Tool:      &AnimateImage{router: router, attachments: attachments, source: source},
			Available: router.VideoEditAvailable,
		},
	)
	// enroll_voice needs the voices repository, and a nil one means the assembly root did not wire
	// it — in which case the tool must be ABSENT rather than present-and-panicking.
	// enroll_voice 要 voices 仓储,而 nil 意味着装配根没接上——那时工具必须**缺席**,而不是「在场且会 panic」。
	if voices != nil {
		tools = append(tools, ToolWithAvailability{
			Tool:      &EnrollVoice{router: router, source: source, voices: voices},
			Available: router.VoiceCloneAvailable,
		})
	}
	return tools
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
	case "video/mp4":
		return "mp4"
	case "video/webm":
		return "webm"
	default:
		if strings.HasPrefix(mime, "video/") {
			return strings.TrimPrefix(mime, "video/")
		}
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
