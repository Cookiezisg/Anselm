package llm

import (
	"context"
	"fmt"
	"iter"
	"net/http"
	"sync/atomic"
	"time"

	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
)

// Provider is one LLM wire dialect: it owns how a Request becomes an HTTP request (body
// shape, auth headers, base-url + path) and how the response becomes the typed
// StreamEvent stream. Identity (Name / DefaultBaseURL) drives registry lookup and
// base-url resolution. Each provider implements this fully self-contained.
//
// Provider 是一种 LLM wire 方言：负责 Request→HTTP 请求（body 形状、auth 头、
// base-url+path）与响应→StreamEvent 流。Name / DefaultBaseURL 供注册表查找与 base-url
// 解析。每个 provider 完整自包含地实现它。
type Provider interface {
	Name() string
	DefaultBaseURL() string
	BuildRequest(ctx context.Context, req Request) (*http.Request, error)
	ParseStream(ctx context.Context, resp *http.Response, req Request) iter.Seq[StreamEvent]

	// DescribeModels parses this provider's raw /models probe body (archived by apikey) into
	// ModelInfo, each carrying its native configurable knobs. Rich providers (gemini/moonshot/
	// openrouter) read specs+knobs from the payload; lean ones (openai/deepseek/...) read ids and
	// fill specs+knobs from their own static table. Pure parsing, no network.
	//
	// DescribeModels 解析本家 /models 探测原始返回（apikey 存档）为 ModelInfo，每个带原生可调旋钮。
	// 富家（gemini/moonshot/openrouter）从载荷读规格+旋钮，贫家读 id 并用自家静态表补。纯解析、不联网。
	DescribeModels(rawProbe string) ([]ModelInfo, error)
}

// providerClient adapts a Provider to Client by running the shared transport iron-law
// (build → do → status-map → parse). It is the single copy of request/response plumbing
// every Provider funnels through, plus a per-event idle timer for dead-socket detection.
//
// providerClient 把 Provider 适配成 Client：跑共享传输铁律（build → do → status-map →
// parse），是所有 Provider 共用的唯一请求/响应管道，外加逐事件 idle 计时器探测死连接。
type providerClient struct {
	provider Provider
	http     *http.Client
}

func (c *providerClient) Stream(ctx context.Context, req Request) iter.Seq[StreamEvent] {
	return func(yield func(StreamEvent) bool) {
		// Two complementary guards cancel streamCtx (ctx cancellation — user stop / turn timeout —
		// stays the primary control):
		//   - idle timer: a dead-socket detector that RESETS on every event, so a healthy long stream
		//     (deep reasoning, big generation) never trips it.
		//   - total cap: a wall clock that does NOT reset, bounding a model that keeps emitting events
		//     without ever converging (a pathological reasoning / empty-delta loop) — without it the
		//     idle timer resets forever, the turn wedges in `streaming`, CPU pins, and graceful
		//     shutdown blocks (round-2 vision lane).
		//
		// 两个互补守卫取消 streamCtx（ctx 取消——用户 stop / turn 超时——仍是主控）：
		//   - idle 计时器：死连接探测，每个事件重置，健康长流永不触发。
		//   - 总墙钟：不随事件重置，封顶持续滴事件却永不收敛的模型（病态 reasoning / 空 delta 循环）——
		//     没有它，idle 计时器永久重置，回合永困 `streaming`、CPU 钉死、graceful shutdown 阻塞（round-2 vision lane）。
		streamCtx, cancel := context.WithCancel(ctx)
		defer cancel()
		idle := time.Duration(limitspkg.Current().Timeout.LLMIdleSec) * time.Second
		var timer *time.Timer
		if idle > 0 {
			timer = time.AfterFunc(idle, cancel)
			defer timer.Stop()
		}
		var cappedTotal atomic.Bool
		if maxStream := time.Duration(limitspkg.Current().Timeout.LLMStreamMaxSec) * time.Second; maxStream > 0 {
			total := time.AfterFunc(maxStream, func() { cappedTotal.Store(true); cancel() })
			defer total.Stop()
		}

		httpReq, err := c.provider.BuildRequest(streamCtx, req)
		if err != nil {
			yield(StreamEvent{Type: EventError, Err: err})
			return
		}
		resp, ok := doRequest(c.http, httpReq, "llm."+c.provider.Name(), yield)
		if !ok {
			return
		}
		defer resp.Body.Close()

		for ev := range c.provider.ParseStream(streamCtx, resp, req) {
			if timer != nil {
				timer.Reset(idle)
			}
			if !yield(ev) {
				return
			}
		}

		// If one of OUR timers fired (streamCtx cancelled while the parent ctx is still alive), the
		// stream failed mid-flight — surface it as a provider error instead of a phantom user-cancel
		// (which would mislabel the turn). Distinguish the two so the agent's error is accurate: a
		// total-cap trip means the model never converged; an idle trip means the socket went silent.
		//
		// 若我们的计时器之一触发（streamCtx 取消而父 ctx 仍活），流中途失败——报 provider 错，而非伪装成
		// 用户取消（会误标该回合）。区分二者使 agent 见到的错准确：总墙钟触发=模型不收敛；idle 触发=连接静默。
		if streamCtx.Err() != nil && ctx.Err() == nil {
			if cappedTotal.Load() {
				maxStream := time.Duration(limitspkg.Current().Timeout.LLMStreamMaxSec) * time.Second
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("%w: llm.%s: stream exceeded the %s total budget without converging", ErrProviderError, c.provider.Name(), maxStream)})
			} else {
				yield(StreamEvent{Type: EventError, Err: fmt.Errorf("%w: llm.%s: no stream activity for %s (connection appears dead)", ErrProviderError, c.provider.Name(), idle)})
			}
		}
	}
}

// providerRegistry maps a Config.Provider name to its Provider, one self-contained entry per
// provider. Unknown names fall back to the OpenAI-compat default in lookupProvider — they all
// speak /chat/completions.
//
// providerRegistry 把 Config.Provider name 映射到 Provider，每个 provider 注册为一条自包含
// 条目。未知 name 在 lookupProvider 回落 OpenAI-compat 默认——它们都讲 /chat/completions。
var providerRegistry = buildProviderRegistry()

func buildProviderRegistry() map[string]Provider {
	return map[string]Provider{
		"openai":     newOpenAIProvider(),
		"anthropic":  newAnthropicProvider(),
		"google":     newGeminiProvider(),
		"deepseek":   newDeepSeekProvider(),
		"qwen":       newQwenProvider(),
		"zhipu":      newZhipuProvider(),
		"moonshot":   newMoonshotProvider(),
		"openrouter": newOpenRouterProvider(),
		"ollama":     newOllamaProvider(),
		"azure":      newAzureProvider(),
		"custom":     newCustomProvider(),
		"anselm":     newAnselmProvider(),
	}
}

// lookupProvider resolves the Provider for a Config; "custom" + anthropic-compatible
// routes to the anthropic dialect, every other unknown name falls back to OpenAI-compat.
//
// lookupProvider 按 Config 解析 Provider；"custom"+anthropic-compatible 路由到 anthropic
// 方言，其余未知 name 回落 OpenAI-compat。
func lookupProvider(cfg Config) Provider {
	if cfg.Provider == "custom" && cfg.APIFormat == "anthropic-compatible" {
		return providerRegistry["anthropic"]
	}
	if p, ok := providerRegistry[cfg.Provider]; ok {
		return p
	}
	// A catalog id that names a family we DID hand-write a spec for resolves to that spec, not to a
	// synthesized one. Without this hop the hand-written qwen / zhipu / moonshot providers become
	// unreachable the moment the app starts offering catalog ids (`alibaba` / `zhipuai` /
	// `moonshotai`) instead of our own names — and「unreachable」is not a cosmetic loss:
	//
	//   - their KNOB SPELLINGS die. A synthesized provider carries [compatKnobs], so a qwen model
	//     would be sent `reasoning_effort` — a parameter name qwen never declared. That is the exact
	//     failure the knob design exists to prevent: a 400 that reads like「这个模型坏了」.
	//   - their ENCODER dies. The synthesized spec has no `encode` at all, so `MaxTokens` would
	//     simply never reach the wire.
	//   - their WIRE MASK narrows to text+image, silently un-advertising modalities they can carry.
	//
	// 一个目录 id,若它命名的正是我们**手写过 spec** 的那一家,就解析到那份 spec、而不是合成一个。
	// 没有这一跳,手写的 qwen / zhipu / moonshot 三家会在「app 开始下发目录 id(`alibaba` /
	// `zhipuai` / `moonshotai`)而不是我们自己的名字」的那一刻起变得**够不着**——而「够不着」
	// 不是外观上的损失:
	//
	//   - 它们的**旋钮拼法**死了。合成的 provider 带的是 [compatKnobs],于是一个 qwen 模型会收到
	//     `reasoning_effort`——一个 qwen 从没声明过的参数名。那正是旋钮这套设计存在的理由所要挡的
	//     失败:一个读起来像「这个模型坏了」的 400。
	//   - 它们的**编码器**死了。合成的 spec **根本没有** `encode`,故 `MaxTokens` 永远到不了线缆。
	//   - 它们的**线缆掩码**收窄成文本+图,静默地不再宣称自己扛得动的模态。
	if key, ok := registryKeyForCatalogID[cfg.Provider]; ok {
		if p, ok := providerRegistry[key]; ok {
			return p
		}
	}
	// The long tail: any of the ~160 catalog providers this build has no hand-written spec for gets
	// one synthesized from its `npm` dialect. Falling through to OpenAI as before would have been a
	// guess with no evidence behind it; this is a guess with the catalog behind it, and the app
	// layer already refused the key if the dialect were one we cannot speak.
	// 长尾:约 160 家本构建没有手写 spec 的目录 provider,由它的 `npm` 方言**合成**一个。像从前那样
	// 一路跌到 OpenAI,是一个背后什么证据都没有的猜测;这个猜测背后有目录,而且方言若是我们说不了的
	// 那种,app 层在建 key 时就已经拒过了。
	if p, ok := catalogSynthesized(cfg.Provider); ok {
		return p
	}
	return providerRegistry["openai"]
}

// registryKeyForCatalogID is [catalogProviderMap] read backwards — models.dev's id on the left, our
// own name on the right — plus the one row that is not a rename:
//
// `moonshotai-cn` is a SECOND catalog provider for the same product (Kimi), listing the identical
// ten models against the `.cn` host. It is not an alias of our `moonshot` name, so it cannot live in
// [catalogProviderMap]; but it is the same wire, with the same knob spellings, so routing it to the
// same hand-written spec is the answer the evidence supports. Its address differs and that is
// already handled — the base URL rides on the key row, not on the spec.
//
// registryKeyForCatalogID 是 [catalogProviderMap] 反着读——左边 models.dev 的 id、右边我们自己的
// 名字——外加**一条不是改名**的行:
//
// `moonshotai-cn` 是**同一个产品**(Kimi)的**第二个**目录条目,对着 `.cn` 主机列着一模一样的十个
// 模型。它不是我们 `moonshot` 这个名字的别名,故进不了 [catalogProviderMap];但它是**同一条线缆、
// 同一套旋钮拼法**,故把它路由到同一份手写 spec 是证据支持的答案。地址不同这件事已经有人管了——
// base URL 骑在 key 行上、不在 spec 上。
var registryKeyForCatalogID = buildRegistryKeyForCatalogID()

func buildRegistryKeyForCatalogID() map[string]string {
	out := map[string]string{"moonshotai-cn": "moonshot"}
	for ours, upstream := range catalogProviderMap {
		out[upstream] = ours
	}
	return out
}

// ModelInfo is one usable model with its capability specs and configurable knobs, assembled by
// a Provider from its /models payload (+ static fallback). The model module aggregates these
// across a workspace's keys for the capabilities surface.
//
// ModelInfo 是一个可用模型及其能力规格与可调旋钮，由 Provider 从 /models 载荷(+静态兜底)装配。
// model 模块跨 workspace 的 key 聚合它们供 capabilities 面用。
type ModelInfo struct {
	ID            string `json:"id"`
	DisplayName   string `json:"displayName"`
	ContextWindow int    `json:"contextWindow"`
	MaxOutput     int    `json:"maxOutput"`
	// Route-specific input limits are set by capability-routing providers such
	// as Anselm. Zero means the model has one ordinary ContextWindow envelope.
	TextInputLimit       int  `json:"textInputLimit,omitempty"`
	MultimodalInputLimit int  `json:"multimodalInputLimit,omitempty"`
	Vision               bool `json:"vision"`     // accepts image input natively / 原生接收图片
	Video                bool `json:"video"`      // accepts native video input / 原生接收视频
	Audio                bool `json:"audio"`      // accepts native audio input / 原生接收音频
	NativeDocs           bool `json:"nativeDocs"` // accepts an inline document (PDF) natively / 原生接收内联文档(PDF)
	// Tools reports whether the model can call tools. A false here does NOT hide the model — it is
	// a good chat model and a useless agent, and the picker says so (H12-b). Hiding it used to be
	// the behaviour, and it was invisible: the model simply "was not there".
	// Tools 报告模型会不会调工具。false **不隐藏**这个模型——它是个好聊天模型、一个没用的 agent,
	// 而选择器直说(H12-b)。此前的行为是**藏起来**,且藏得看不见:那个模型就是「不在那儿」。
	Tools         bool  `json:"tools"`
	MaxMediaParts int   `json:"maxMediaParts,omitempty"` // 0 = provider-specific / no app-side cap；0=仅 provider 限制/无 app 侧上限
	MaxMediaBytes int64 `json:"maxMediaBytes,omitempty"` // total decoded bytes; 0 = no app-side cap / 解码字节总数；0=无 app 侧上限
	// MaxDistinctMediaKinds is an optional app-side guard for models whose native
	// multimodal contract permits only one distinct media kind (for example, Qwen3
	// Omni Flash accepts text plus image OR audio OR video, not several together).
	// Zero means the provider has not published a finite cross-kind constraint.
	//
	// MaxDistinctMediaKinds 是模型原生多模态契约的可选 app 侧闸；有些模型只允许
	// 一种不同媒体类型（例如 Qwen3 Omni Flash 是文字+图/音/视频三选一），不能把
	// Vision/Audio/Video 三个独立布尔值误读成任意组合都可用。零表示 provider 未发布
	// 有限的跨类型约束。
	MaxDistinctMediaKinds int    `json:"maxDistinctMediaKinds,omitempty"`
	Knobs                 []Knob `json:"knobs"`
}

// Knob describes one configurable parameter as a render-ready descriptor: a uniform container
// whose content is entirely native — key and values are each provider's own wire vocabulary,
// never translated or normalised. The frontend renders generically from it.
//
// Knob 把一个可配置参数描述成可渲染描述符：统一「容器」，内容全原生——key 与取值是各家自己的
// wire 词表，绝不翻译或归一。前端据此通用渲染。
type Knob struct {
	Key     string   `json:"key"`              // native param name, e.g. "reasoning_effort"
	Label   string   `json:"label"`            // display label
	Type    string   `json:"type"`             // control: "enum" | "int" | "bool"
	Values  []string `json:"values,omitempty"` // native enum values, e.g. ["high","max"]
	Default string   `json:"default,omitempty"`
}

// DescribeModels resolves the Provider for name and parses its raw probe body; unknown names
// fall back to the OpenAI-compat dialect (see lookupProvider).
//
// DescribeModels 按 name 解析 Provider 并解析其探测原始返回；未知 name 回落 OpenAI-compat。
func DescribeModels(provider, rawProbe string) ([]ModelInfo, error) {
	return lookupProvider(Config{Provider: provider}).DescribeModels(rawProbe)
}
