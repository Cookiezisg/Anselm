package llm

import (
	"sort"
	"strings"
	"sync"
)

// Dialect is a WIRE protocol — the shape of the request body, the auth scheme, the streaming
// grammar. There are five, and 173 upstream providers speak them between them.
//
// **The catalog names an SDK PACKAGE, not a protocol, and reading `npm` as a protocol name is the
// single mistake this file exists to prevent.** 137 of the 173 publish `@ai-sdk/openai-compatible`;
// the remaining 36 publish their own package — `@ai-sdk/groq`, `xai`, `togetherai`, `cerebras`,
// `deepinfra`, `@openrouter/…` — while speaking the SAME OpenAI-compatible wire. Taking those names
// at face value would invent two dozen dialects that do not exist and leave every one of them
// unimplemented.
//
// Dialect 是**线缆协议**——请求体形状、鉴权方案、流式文法。一共五条,而 173 家上游用它们说话。
//
// **目录给的是 SDK 包名、不是协议名,而把 `npm` 当协议名读正是本文件存在所要防的那一个错误。**
// 173 家里 137 家发 `@ai-sdk/openai-compatible`;其余 36 家各自发了个包——`@ai-sdk/groq`、`xai`、
// `togetherai`、`cerebras`、`deepinfra`、`@openrouter/…`——说的却是**同一条** OpenAI 兼容线缆。
// 照字面收下那些名字,会凭空发明二十几条**并不存在**的方言,并让它们每一条都没有实现。
type Dialect string

const (
	DialectOpenAICompat Dialect = "openai-compatible"
	DialectAnthropic    Dialect = "anthropic"
	DialectGoogle       Dialect = "google"
	// DialectAzure speaks OpenAI's body over a different URL shape (deployment in the path + an
	// `api-version` query) with an `api-key` header — see azure.go.
	// DialectAzure 用**不同的 URL 形状**(deployment 在路径 + `api-version` query)与 `api-key` 头讲
	// OpenAI 的 body——见 azure.go。
	DialectAzure Dialect = "azure"
	// DialectVertex is Google Cloud Vertex AI. It is its own dialect for a reason the CATALOG states
	// outright: its `env` is PROJECT + LOCATION + `GOOGLE_APPLICATION_CREDENTIALS`, i.e. a
	// service-account JSON file — not an API key. Routing it to the ordinary Gemini provider (which
	// sends a key) would 401 every time, and the message would read like the user's key was wrong
	// when the truth is that Vertex does not take keys at all. See vertex.go: the credential is a
	// file and the token has to be minted, while the wire itself (`…/endpoints/openapi`) is ordinary
	// OpenAI-compatible.
	//
	// DialectVertex 是 Google Cloud Vertex AI。它**自成一条方言**,理由**目录自己直说了**:它的 `env`
	// 是 PROJECT + LOCATION + `GOOGLE_APPLICATION_CREDENTIALS`——一个**服务账号 JSON 文件**、不是 API
	// key。把它路由到普通 Gemini provider(那个是发 key 的)会**每次都 401**,而消息读起来像是用户的
	// key 错了——真相是 Vertex **根本不收 key**。见 vertex.go:凭证是文件、token 要现换,而线缆本身
	// (`…/endpoints/openapi`)是普通的 OpenAI 兼容。
	DialectVertex Dialect = "vertex"
)

// npmDialects maps the SDK package names that mean a NON-OpenAI wire. Everything absent from this
// table is OpenAI-compatible — which is the honest default, not a guess of last resort: it is what
// 137 providers declare outright and what the other unlisted ones demonstrably do.
//
// npmDialects 列出「意味着**非** OpenAI 线缆」的那些 SDK 包名。不在表里的一律 OpenAI 兼容——那是
// **诚实的默认**、不是走投无路的猜测:它是 137 家直接声明的东西,也是其余未列出者实际在做的事。
var npmDialects = map[string]Dialect{
	"@ai-sdk/anthropic":               DialectAnthropic,
	"@ai-sdk/google":                  DialectGoogle,
	"@ai-sdk/azure":                   DialectAzure,
	"@ai-sdk/google-vertex":           DialectVertex,
	"@ai-sdk/google-vertex/anthropic": DialectVertex,
	// **`@ai-sdk/amazon-bedrock` is NOT listed, and that is the correction, not an oversight.**
	// The package speaks Bedrock's Converse API over SigV4 — a body and a binary event-stream of its
	// own — so reading the package name as the protocol says "a third full dialect, write 600 lines".
	// But Bedrock also serves an OpenAI-compatible Chat Completions endpoint at
	// `https://bedrock-runtime.{region}.amazonaws.com/openai/v1`, authenticated by a plain BEARER
	// token (`AWS_BEARER_TOKEN_BEDROCK`, which is why that variable is in the catalog's own env
	// list). 116 models, zero new code, one base URL the user pastes.
	//
	// The lesson generalises: `npm` says WHICH SDK EXISTS, not WHAT THE PROVIDER CAN SPEAK. When it
	// points away from OpenAI, that is worth checking too — this file already warns against reading
	// it as a protocol name; the warning cuts both ways.
	//
	// **`@ai-sdk/amazon-bedrock` 不在表里,而这是一处订正、不是疏漏。** 那个包讲的是 Bedrock 的
	// Converse API + SigV4——自己的 body、自己的二进制 event-stream——故把包名当协议读,得出的结论是
	// 「第三条完整方言,写 600 行」。但 Bedrock **同时**在
	// `https://bedrock-runtime.{region}.amazonaws.com/openai/v1` 上提供 OpenAI 兼容的 Chat
	// Completions,鉴权是**普通 bearer**(`AWS_BEARER_TOKEN_BEDROCK`——正因如此那个变量才出现在目录
	// 自己的 env 列表里)。116 个模型、零新代码、一个用户粘贴的 base URL。
	//
	// 这条教训是通用的:`npm` 说的是**存在哪个 SDK**、不是**这家能说什么**。当它**指向 OpenAI 之外**
	// 时,同样值得去查一下——本文件本来就警告过别把它当协议名读,而那句警告**两个方向都成立**。
}

// DialectForNPM resolves a catalog `npm` value to the wire we would speak.
//
// DialectForNPM 把目录的 `npm` 值解析成我们要说的那条线缆。
func DialectForNPM(npm string) Dialect {
	if d, ok := npmDialects[strings.TrimSpace(npm)]; ok {
		return d
	}
	return DialectOpenAICompat
}

// Speakable reports whether this build can actually talk to a dialect. Azure and Bedrock are named
// but not yet implemented; a provider on one of them must be refused UP FRONT, with the reason,
// rather than accepted and then failing at the last hop.
//
// Speakable 报告本构建到底说不说得了某条方言。Azure 与 Bedrock 已命名但尚未实现;落在它们上的
// provider 必须**当场**被拒并说明理由,而不是先收下、再在最后一跳失败。
func (d Dialect) Speakable() bool {
	switch d {
	case DialectOpenAICompat, DialectAnthropic, DialectGoogle, DialectAzure, DialectVertex:
		return true
	default:
		return false
	}
}

// curatedProviders are the upstreams this app ships a hand-written spec for: their knob tables,
// their base URLs and their quirks were written against their own docs, and several were exercised
// against a real key. Everything else in the catalog is reached by the mechanical `npm` mapping.
//
// **This is evidence, not configuration.** It records what we have actually built against — which
// is exactly what the UI needs in order to tell「你的 key 不对」apart from「这家我们没试过」. It
// must not grow into a list of "supported providers": the other ~160 are supported, they are just
// not vouched for.
//
// curatedProviders 是本 app **手写过 spec** 的那些上游:它们的旋钮表、base URL 与怪癖是照着各自官方
// 文档写的,其中几家还用真 key 跑过。目录里其余各家由机械的 `npm` 映射抵达。
//
// **这是证据、不是配置。** 它记录的是我们**真正照着建过**的东西——而那正是 UI 用来分辨「你的 key 不对」
// 与「这家我们没试过」所需要的。它**不得**长成一张「支持的供应商」名单:另外约 160 家**也是支持的**,
// 只是我们不为它们背书。
var curatedProviders = map[string]bool{
	"openai":     true,
	"anthropic":  true,
	"google":     true,
	"deepseek":   true,
	"alibaba":    true,
	"moonshotai": true,
	"zhipuai":    true,
	"openrouter": true,
}

// ProviderInfo is one catalog provider as the app layer needs it: enough to render a card, prefill
// a form and decide whether a key can be created at all.
//
// ProviderInfo 是 app 层需要的「一家目录 provider」:够渲一张卡、预填一张表,并决定这把 key 到底能
// 不能建。
type ProviderInfo struct {
	ID      string
	Name    string
	BaseURL string // may be empty — most first-party providers hard-code it in their SDK
	Dialect Dialect
	Curated bool
	Models  int
}

// CatalogProviders lists every provider in the active catalog, sorted by id.
//
// CatalogProviders 列出当前目录里的每一家,按 id 排序。
func CatalogProviders() []ProviderInfo {
	cat := currentCatalog.Load()
	out := make([]ProviderInfo, 0, len(cat.Providers))
	for id, p := range cat.Providers {
		out = append(out, ProviderInfo{
			ID:      id,
			Name:    p.Name,
			BaseURL: p.API,
			Dialect: DialectForNPM(p.NPM),
			Curated: curatedProviders[id],
			Models:  len(p.Models),
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}

// CatalogProvider returns one provider by catalog id (or by OUR alias for it).
//
// CatalogProvider 按目录 id(或我们给它的别名)返回一家。
func CatalogProvider(id string) (ProviderInfo, bool) {
	key := catalogKey(id)
	cat := currentCatalog.Load()
	p, ok := cat.Providers[key]
	if !ok {
		return ProviderInfo{}, false
	}
	return ProviderInfo{
		ID:      key,
		Name:    p.Name,
		BaseURL: p.API,
		Dialect: DialectForNPM(p.NPM),
		Curated: curatedProviders[key],
		Models:  len(p.Models),
	}, true
}

// catalogBuilt caches the providers synthesized from catalog rows, so a long-tail key does not
// rebuild its dialect on every request.
//
// catalogBuilt 缓存从目录行合成出来的 provider,使长尾 key 不必每个请求重建自己的方言。
var catalogBuilt sync.Map // catalog id -> Provider

// catalogSynthesized builds a Provider for a catalog id this build has no hand-written spec for.
// It is the whole point of H12-c: ~160 providers become reachable without ~160 files.
//
// The synthesized spec is deliberately minimal — the floor of the OpenAI-compatible dialect, no
// knobs, no per-model quirks. A knob we invented for a provider we have never called would be a
// promise made on its behalf.
//
// catalogSynthesized 为一个本构建没有手写 spec 的目录 id 构造 Provider。它就是 H12-c 的全部要点:
// 约 160 家**不必写 160 个文件**就能到达。
//
// 合成出来的 spec **刻意最小**——OpenAI 兼容方言的地板,无旋钮、无逐模型怪癖。为一家我们从没调用过的
// 供应商发明一个旋钮,是**替它**许下的承诺。
func catalogSynthesized(id string) (Provider, bool) {
	info, ok := CatalogProvider(id)
	if !ok || !info.Dialect.Speakable() {
		return nil, false
	}
	if p, hit := catalogBuilt.Load(info.ID); hit {
		return p.(Provider), true
	}
	var built Provider
	switch info.Dialect {
	case DialectAnthropic:
		built = newAnthropicProvider()
	case DialectGoogle:
		built = newGeminiProvider()
	case DialectAzure:
		built = newAzureProvider()
	case DialectVertex:
		built = newVertexProvider()
	default:
		built = &compatProvider{spec: compatSpec{
			name:    info.ID,
			baseURL: func() string { return info.BaseURL },
			// The floor: text and images. A long-tail provider's per-model modalities still come
			// from the catalog, and the projection is catalog ∧ mask — so a model the catalog says
			// reads video simply does not advertise it here, which is the honest answer for a
			// dialect whose video shape we have never seen.
			// 地板:文本与图。长尾家的逐模型模态仍来自目录,而投影是 目录 ∧ 掩码——故一个目录说会读
			// 视频的模型在这里**不会**宣称它,那是对「一条我们从没见过其视频形状的方言」的诚实回答。
			wire: partMask{image: true},
			describe: func(raw string) ([]ModelInfo, error) {
				return describeFromSpecs(catalogSpecs(info.ID, compatKnobs), raw, partMask{image: true}), nil
			},
		}}
	}
	actual, _ := catalogBuilt.LoadOrStore(info.ID, built)
	return actual.(Provider), true
}
