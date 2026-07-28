package apikey

import (
	"sort"
	"strings"

	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// ProviderCategory groups providers by integration kind (LLM vs search), for
// display grouping only — no selection logic hangs off it (that's downstream).
//
// ProviderCategory 按集成类别分组（LLM / 搜索），仅供展示分组——不挂任何选择逻辑（那在下游）。
type ProviderCategory string

const (
	CategoryLLM    ProviderCategory = "llm"
	CategorySearch ProviderCategory = "search"
)

// TestMethod enumerates how to probe a provider's connectivity (which endpoint +
// auth style). This is "how to knock", not "how to read the answer".
//
// TestMethod 枚举探测一家连通性的方式（哪个端点 + 认证）。这是「怎么敲门」，不是「怎么读回信」。
type TestMethod string

const (
	TestMethodGetModels        TestMethod = "get_models"
	TestMethodAnthropicModels  TestMethod = "anthropic_models"
	TestMethodGoogleListModels TestMethod = "google_list_models"
	TestMethodOllamaTags       TestMethod = "ollama_tags"
	TestMethodCustom           TestMethod = "custom"
	TestMethodAlwaysOK         TestMethod = "always_ok"
	TestMethodSearchPing       TestMethod = "search_ping"
	// TestMethodVertexToken mints an OAuth2 token from the service-account file and stops there.
	// It is the RIGHT probe for Vertex, not a fallback: minting is exactly the step that fails when
	// the credential is wrong, and Vertex has no model listing to fetch afterwards anyway.
	// TestMethodVertexToken 用服务账号文件铸一个 OAuth2 token,到此为止。它是 Vertex **正确的**探针、
	// 不是退路:凭证不对时失败的正是「铸」这一步,而 Vertex 之后本来也没有模型列表可拉。
	TestMethodVertexToken TestMethod = "vertex_token"
)

// CredentialKind tells the UI what the「key」field actually holds. Every provider but one takes a
// pasted string; Vertex takes a service-account JSON FILE, and a text box labelled「API key」is the
// wrong control for it — the user would go looking for a key that does not exist.
//
// CredentialKind 告诉 UI 那个「key」字段**实际装的是什么**。除一家外每家都收一个粘贴的字符串;Vertex
// 收的是一个服务账号 **JSON 文件**,而一个写着「API key」的文本框对它是**错的控件**——用户会去找一把
// **根本不存在**的 key。
type CredentialKind string

const (
	CredentialAPIKey             CredentialKind = "api_key"
	CredentialServiceAccountJSON CredentialKind = "service_account_json"
)

// ProviderMeta is what apikey needs to validate, connect to, and probe a
// provider — nothing about models or selection.
//
// ProviderMeta 是 apikey 校验、连接、探测一家所需——不含模型、不含选择。
type ProviderMeta struct {
	Name            string `json:"name"`
	DisplayName     string `json:"displayName"`
	DefaultBaseURL  string `json:"defaultBaseUrl,omitempty"`
	BaseURLRequired bool   `json:"baseUrlRequired"`
	// Managed marks a built-in, backend-provisioned provider whose credential is minted by the app
	// (not pasted by the user): its key row is created via CreateManaged (seeded probe archive, no
	// live test) and is immutable (Update rejects it). The free-tier Anselm gateway is the only one
	// today. The frontend uses this to keep it out of the manual "add a key" list.
	//
	// Managed 标记内置、由后端开通的 provider：凭证由 app 铸造（非用户粘贴），key 行经 CreateManaged
	// 创建（播种探测档案、不跑 live 探针）且不可编辑（Update 拒绝）。当前仅免费档 Anselm 网关。前端据此
	// 把它排除出手动「添加 key」列表。
	Managed    bool             `json:"managed"`
	TestMethod TestMethod       `json:"-"`
	Category   ProviderCategory `json:"category"`
	// Curated marks a provider this app ships a hand-written spec for (knob table, base URL, quirks
	// written against its own docs). The ~160 others come straight from models.dev and are reached by
	// the mechanical `npm` → dialect mapping: they work, but nothing here vouches for them, and the
	// UI needs that distinction to tell「你的 key 不对」apart from「这家我们没试过」(WRK-085 §7).
	// Curated 标记「本 app 手写过 spec」的家(旋钮表、base URL、怪癖照官方文档写)。另外约 160 家直接
	// 来自 models.dev、由机械的 `npm` → 方言映射抵达:它们**能用**,但这里不为它们背书,而 UI 需要这个
	// 区分才能把「你的 key 不对」与「这家我们没试过」分开(WRK-085 §7)。
	Curated bool `json:"curated"`
	// Dialect is the wire we would speak to it. A dialect this build cannot speak is refused at key
	// creation with its own reason — never accepted and then failed at the last hop.
	// Dialect 是我们要对它说的那条线缆。本构建说不了的方言在**建 key 时**以自己的理由被拒——绝不
	// 先收下、再在最后一跳失败。
	Dialect string `json:"dialect"`
	// BaseURLHint is a TEMPLATE the catalog published instead of a usable URL — four providers do
	// this (`https://${DATABRICKS_HOST}/ai-gateway/mlflow/v1` and friends), because their endpoint
	// contains the customer's own account or host name.
	//
	// It is deliberately NOT the prefilled value: submitted verbatim it produces a connect failure
	// whose message says nothing about the literal `${…}` still sitting in the field. As a HINT it is
	// the most useful thing on the form — it shows exactly where the account name goes.
	//
	// BaseURLHint 是目录发布的**模板**、不是一个能用的 URL——有四家这样(
	// `https://${DATABRICKS_HOST}/ai-gateway/mlflow/v1` 之类),因为它们的端点里含着**客户自己的**
	// 账号名或主机名。
	//
	// 它**刻意不是**预填值:原样提交会换来一次连接失败,而那条消息**只字不提**字段里still 躺着的
	// 那个字面 `${…}`。作为**提示**它则是表单上最有用的东西——它精确指出账号名该填在哪。
	BaseURLHint string `json:"baseUrlHint,omitempty"`
	// Credential names what the key field holds — see [CredentialKind].
	// Credential 说明 key 字段装的是什么——见 [CredentialKind]。
	Credential CredentialKind `json:"credential"`
}

// localProviders are the entries models.dev does NOT describe, and each is absent for a reason
// rather than by omission:
//
//   - the four search providers — not LLM providers at all;
//   - `ollama` — a LOCAL daemon, so there is no hosted service for a catalog to list (models.dev has
//     `ollama-cloud` and `lmstudio`, which are different things);
//   - `custom` — any endpoint the user names, which is by definition not in a registry;
//   - `mock` — our own test fixture;
//   - `anselm` — our own managed gateway.
//
// Everything else comes from the catalog. This map must not grow a row for a provider models.dev
// already describes: that is precisely the hand-maintained table H12-c removed.
//
// localProviders 是 models.dev **不描述**的那些条目,而每一条的缺席都有理由、不是遗漏:
//
//   - 四个搜索家——根本不是 LLM 供应商;
//   - `ollama`——**本地** daemon,没有可供目录收录的托管服务(models.dev 有 `ollama-cloud` 与
//     `lmstudio`,那是别的东西);
//   - `custom`——用户随手指名的任意端点,按定义不在任何注册表里;
//   - `mock`——我们自己的测试设施;
//   - `anselm`——我们自己的受管网关。
//
// 其余一律来自目录。**这张表不得为 models.dev 已经描述的家新增一行**——那正是 H12-c 拆掉的手工表。
var localProviders = map[string]ProviderMeta{
	"anselm": {Name: "anselm", DisplayName: "Anselm Free", DefaultBaseURL: "https://api.anselm.website/v1", TestMethod: TestMethodGetModels, Category: CategoryLLM, Managed: true, Curated: true, Dialect: string(llminfra.DialectOpenAICompat), Credential: CredentialAPIKey},
	// Ollama's port is not a per-user fact — `http://localhost:11434/v1` is what its own docs print in
	// every example (docs/api/openai-compatibility.mdx). Asking every user to type the standard port of
	// a daemon they just installed is asking them to know a constant we already know.
	// Ollama 的端口**不是逐用户的事实**——`http://localhost:11434/v1` 是它自己文档里每个例子都印着的
	// (docs/api/openai-compatibility.mdx)。让每个用户去手打一个刚装好的 daemon 的**标准端口**,
	// 等于要求他知道一个我们已经知道的常量。
	"ollama": {Name: "ollama", DisplayName: "Ollama (local)", DefaultBaseURL: "http://localhost:11434/v1", TestMethod: TestMethodOllamaTags, Category: CategoryLLM, Curated: true, Dialect: string(llminfra.DialectOpenAICompat), Credential: CredentialAPIKey},
	"custom": {Name: "custom", DisplayName: "Custom (OpenAI/Anthropic compatible)", BaseURLRequired: true, TestMethod: TestMethodCustom, Category: CategoryLLM, Curated: true, Dialect: string(llminfra.DialectOpenAICompat), Credential: CredentialAPIKey},
	"mock":   {Name: "mock", DisplayName: "Mock (dev)", TestMethod: TestMethodAlwaysOK, Category: CategoryLLM, Curated: true, Dialect: string(llminfra.DialectOpenAICompat), Credential: CredentialAPIKey},

	"brave":  {Name: "brave", DisplayName: "Brave Search", DefaultBaseURL: "https://api.search.brave.com/res/v1", TestMethod: TestMethodSearchPing, Category: CategorySearch, Curated: true, Credential: CredentialAPIKey},
	"serper": {Name: "serper", DisplayName: "Serper.dev (Google search)", DefaultBaseURL: "https://google.serper.dev", TestMethod: TestMethodSearchPing, Category: CategorySearch, Curated: true, Credential: CredentialAPIKey},
	"tavily": {Name: "tavily", DisplayName: "Tavily (AI-tuned search)", DefaultBaseURL: "https://api.tavily.com", TestMethod: TestMethodSearchPing, Category: CategorySearch, Curated: true, Credential: CredentialAPIKey},
	"bocha":  {Name: "bocha", DisplayName: "博查 Bocha (CN search)", DefaultBaseURL: "https://api.bochaai.com/v1", TestMethod: TestMethodSearchPing, Category: CategorySearch, Curated: true, Credential: CredentialAPIKey},
}

// knownBaseURLs is the FALLBACK prefill for providers models.dev names but gives no `api` for — and
// that is 24 of the 173, including openai, anthropic, google, azure, bedrock, cohere, xai and groq,
// because their SDK hard-codes the URL instead of publishing it.
//
// **This is not the table H12-c deleted.** That one decided which providers existed; this one only
// answers「what do we prefill when the catalog says nothing」, and every value here is still just a
// prefill the user can overwrite. A provider absent from both the catalog's `api` and this map
// simply requires the user to supply one — and the auth-failure message points at that field
// (WRK-085 §7), because nobody can maintain a list of「哪几家要自己填」.
//
// knownBaseURLs 是「models.dev 收录了、却不给 `api`」那些家的**兜底**预填——而那是 173 家里的 24 家,
// 含 openai/anthropic/google/azure/bedrock/cohere/xai/groq,因为它们的 SDK 把 URL 写死在自己里面、
// 不对外公布。
//
// **它不是 H12-c 删掉的那张表。** 那张表决定**哪些 provider 存在**;这张只回答「目录什么都没说时预填
// 什么」,而这里每一个值仍然只是一个**用户可以覆盖**的预填。目录 `api` 与本表都没有的家,就要求用户
// 自己填——而鉴权失败的消息会**指向那一栏**(WRK-085 §7),因为没有人维护得了一张「哪几家要自己填」的名单。
var knownBaseURLs = map[string]string{
	"openai":    "https://api.openai.com/v1",
	"anthropic": "https://api.anthropic.com",
	"google":    "https://generativelanguage.googleapis.com/v1beta",
	// Cohere's OpenAI-compatible endpoint is a SEPARATE base from its native API — the native one is
	// `/v2/chat` with its own body, and pointing an OpenAI-compatible client at it fails. models.dev
	// names `@ai-sdk/cohere` (the native SDK) and gives no `api`, so without this row a Cohere key
	// would have nowhere correct to point.
	// 来源:https://docs.cohere.com/docs/compatibility-api(Bearer、支持流式与 tool call)。
	// Cohere 的 OpenAI 兼容端点与它的原生 API **不是同一个 base**——原生是 `/v2/chat` + 自己的 body,
	// 把 OpenAI 兼容客户端指过去会失败。models.dev 给的是 `@ai-sdk/cohere`(原生 SDK)且没有 `api`,
	// 故没有这一行,一把 Cohere key 就没有正确的地方可指。
	"cohere": "https://api.cohere.ai/compatibility/v1",
	// 来源:https://docs.venice.ai/api-reference/api-spec —— "implements the OpenAI API specification"。
	"venice": "https://api.venice.ai/api/v1",

	// —— H12-f:以下每一行都是**从已发布的 SDK 包源码里读出来的**默认 baseURL,不是凭记忆写的。
	// 取法:`curl https://cdn.jsdelivr.net/npm/<pkg>/dist/index.mjs`,再找
	// `baseURL = withoutTrailingSlash(options.baseURL) ?? "…"` 那一句。凭记忆写下的 URL 会以
	// 「你的 key 无效」的形态失败,而那句话是**假的**——用户会去重抄一把没错的 key。
	//
	// Each row below was READ OUT OF the published SDK bundle, not written from memory. A remembered
	// URL fails as「your key is invalid」, and that sentence is a LIE — it sends the user to re-copy
	// a key that was right all along.
	"groq":          "https://api.groq.com/openai/v1",          // @ai-sdk/groq
	"xai":           "https://api.x.ai/v1",                     // @ai-sdk/xai
	"mistral":       "https://api.mistral.ai/v1",               // @ai-sdk/mistral
	"cerebras":      "https://api.cerebras.ai/v1",              // @ai-sdk/cerebras
	"togetherai":    "https://api.together.xyz/v1",             // @ai-sdk/togetherai(源码带尾斜杠,此处去掉)
	"v0":            "https://api.v0.dev/v1",                   // @ai-sdk/vercel
	"vercel":        "https://ai-gateway.vercel.sh/v3/ai",      // @ai-sdk/gateway
	"merge-gateway": "https://api-gateway.merge.dev/v1/ai-sdk", // merge-gateway-ai-sdk-provider
	"aihubmix":      "https://aihubmix.com/v1",                 // @aihubmix/ai-sdk-provider(DEFAULT_BASE_URL + `/v1${path}`)

	// Perplexity has NO `/v1`: the bundle builds `${baseURL}/chat/completions` off a bare host.
	// Perplexity **没有 `/v1`**:包里是拿裸主机名直接拼 `${baseURL}/chat/completions`。
	"perplexity": "https://api.perplexity.ai",

	// DeepInfra's OpenAI-compatible surface is a SUBPATH of its own API — the bundle literally does
	// `baseUrl.replace("/inference", "/openai")` and `${baseURL}/openai${path}`. The `/v1` alone is
	// DeepInfra's native inference API and speaks a different body.
	// DeepInfra 的 OpenAI 兼容面是它自己 API 的**子路径**——包里就是
	// `baseUrl.replace("/inference", "/openai")` 与 `${baseURL}/openai${path}`。光一个 `/v1` 是
	// DeepInfra 的原生 inference API、讲的是另一种 body。
	"deepinfra": "https://api.deepinfra.com/v1/openai",
}

// knownBaseURLHints are the providers whose address genuinely CANNOT be prefilled — the URL contains
// something only this user knows. They get the SHAPE and are still required to type a real value.
//
// The distinction matters because「必填」alone is not actionable: a user staring at an empty Azure
// base-URL field does not know that what goes there is their own resource name. The template says it.
//
// knownBaseURLHints 是**地址真的没法预填**的那些家——URL 里有一样只有这个用户知道的东西。它们拿到
// **形状**、并且仍然必须填一个真值。
//
// 这个区分是要紧的,因为光一句「必填」**没法照着做**:一个盯着空的 Azure base URL 栏的用户,不知道
// 该填的是**他自己的 resource 名**。模板把这件事说出来。
var knownBaseURLHints = map[string]string{
	// @ai-sdk/azure builds from AZURE_RESOURCE_NAME; we take the whole URL instead (azure.go).
	"azure":                    "https://{resource}.openai.azure.com",
	"azure-cognitive-services": "https://{resource}.openai.azure.com",
	// @ai-sdk/amazon-bedrock: `https://bedrock-runtime.${region}.amazonaws.com`; the OpenAI-compatible
	// surface hangs off `/openai/v1`(H12-d).
	"amazon-bedrock": "https://bedrock-runtime.{region}.amazonaws.com/openai/v1",
	// ai-gateway-provider: `https://gateway.ai.cloudflare.com/v1/${accountId}/${gateway}` — the gateway
	// is a thing the user CREATED, so no默认 exists at all.
	"cloudflare-ai-gateway": "https://gateway.ai.cloudflare.com/v1/{accountId}/{gateway}",
	// @ai-sdk/google-vertex derives the host from the region: `${region}-aiplatform.googleapis.com`,
	// with `aiplatform.googleapis.com` for global and `aiplatform.{eu|us}.rep.googleapis.com` for the
	// two data-residency endpoints. vertex.go reads the region back OFF this host (vertexLocationFromBase).
	"google-vertex":           "https://{region}-aiplatform.googleapis.com",
	"google-vertex-anthropic": "https://{region}-aiplatform.googleapis.com",
}

// testMethodFor picks how to knock on a provider's door from its dialect — the same fact that
// decides how we talk to it decides how we probe it.
//
// testMethodFor 按方言决定怎么敲这家的门——决定我们**怎么跟它说话**的那个事实,同时决定**怎么探测**它。
func testMethodFor(d llminfra.Dialect) TestMethod {
	switch d {
	case llminfra.DialectAnthropic:
		return TestMethodAnthropicModels
	case llminfra.DialectGoogle:
		return TestMethodGoogleListModels
	case llminfra.DialectVertex:
		return TestMethodVertexToken
	default:
		return TestMethodGetModels
	}
}

// credentialFor: Vertex is the only dialect whose credential is a file.
// credentialFor:Vertex 是唯一凭证是**文件**的方言。
func credentialFor(d llminfra.Dialect) CredentialKind {
	if d == llminfra.DialectVertex {
		return CredentialServiceAccountJSON
	}
	return CredentialAPIKey
}

// catalogMeta projects one catalog provider into the metadata apikey needs.
//
// catalogMeta 把一家目录 provider 投影成 apikey 需要的元数据。
func catalogMeta(p llminfra.ProviderInfo) ProviderMeta {
	base, hint := p.BaseURL, ""
	// A `${…}` in the catalog's api is a template, not an address. Demote it to a hint so the form
	// shows the shape and still demands a real value.
	// 目录 api 里的 `${…}` 是模板、不是地址。降级成提示:表单**展示形状**、同时仍然要一个真值。
	if strings.Contains(base, "${") {
		base, hint = "", p.BaseURL
	}
	if base == "" && hint == "" {
		base = knownBaseURLs[p.ID]
		if base == "" {
			hint = knownBaseURLHints[p.ID]
		}
	}
	return ProviderMeta{
		Name:            p.ID,
		DisplayName:     p.Name,
		DefaultBaseURL:  base,
		BaseURLRequired: base == "",
		BaseURLHint:     hint,
		TestMethod:      testMethodFor(p.Dialect),
		Category:        CategoryLLM,
		Curated:         p.Curated,
		Dialect:         string(p.Dialect),
		Credential:      credentialFor(p.Dialect),
	}
}

// GetProviderMeta returns provider metadata; ok=false if not whitelisted.
//
// GetProviderMeta 返回 provider 元数据；不在白名单时 ok=false。
func GetProviderMeta(name string) (ProviderMeta, bool) {
	if m, ok := localProviders[name]; ok {
		return m, true
	}
	if p, ok := llminfra.CatalogProvider(name); ok {
		return catalogMeta(p), true
	}
	return ProviderMeta{}, false
}

// isValidProvider accepts a provider we can actually REACH. A catalog provider on a dialect this
// build does not speak is refused HERE, at key creation, with its own reason — the honest-absence
// law applied to providers: 功能诚实地不出现,而非调用后失败.
//
// isValidProvider 只接受我们**真的够得着**的 provider。落在本构建说不了的方言上的目录 provider 在
// **这里**、在建 key 时被拒并说明理由——诚实缺席律用在 provider 上:绝不「先收下、调了才失败」。
func isValidProvider(name string) bool {
	if _, ok := localProviders[name]; ok {
		return true
	}
	p, ok := llminfra.CatalogProvider(name)
	return ok && p.Dialect.Speakable()
}

// ListProviders returns the supported providers, sorted by name for a stable response (the
// GET /providers config endpoint). `mock` is a T6 test fixture, NOT a product provider — it is
// filtered from the CATALOG outside dev (WRK-062 S-5) while staying valid for key CREATION
// (testend provisions mock keys without ANSELM_DEV; only the user-facing dropdown must not show it).
//
// ListProviders 返回支持的 provider,按 name 排序保证响应稳定(GET /providers 配置端点)。mock 是 T6
// 测试设施、非产品 provider——非 dev 从**目录**滤除(S-5),但仍可用于建 key(testend 不带 ANSELM_DEV
// 也要 POST mock key;只是用户可见的下拉不得出现它)。
func ListProviders(dev bool) []ProviderMeta {
	cat := llminfra.CatalogProviders()
	out := make([]ProviderMeta, 0, len(localProviders)+len(cat))
	for _, m := range localProviders {
		if m.Name == "mock" && !dev {
			continue
		}
		out = append(out, m)
	}
	for _, p := range cat {
		// A dialect we cannot speak is not offered. Listing it would be an invitation to a failure
		// we already know about. 说不了的方言不摆出来——摆出来等于邀请一次我们**早就知道**的失败。
		if !p.Dialect.Speakable() {
			continue
		}
		if _, local := localProviders[p.ID]; local {
			continue
		}
		out = append(out, catalogMeta(p))
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out
}
