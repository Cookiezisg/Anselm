package llm

import (
	_ "embed"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"sync/atomic"
)

// The direct-connection capability catalog follows models.dev verbatim (WRK-082 P1): numbers and
// modality arrays for our six lean-/models providers (openai / anthropic / deepseek / qwen /
// moonshot / zhipu) come from the community-maintained https://models.dev/api.json, not from
// hand-written tables. The vendored snapshot below is the offline floor; a background refresh
// (StartCatalogRefresh) swaps in a newer trim at runtime. Knobs stay hand-written per provider
// (P4) — models.dev's reasoning metadata is too weak to drive native knob wire vocabularies.
//
// 直连能力目录逐字 follow models.dev(WRK-082 P1):六个贫 /models 家(openai/anthropic/deepseek/
// qwen/moonshot/zhipu)的数字与模态数组来自社区维护的 api.json,不再手写。下方 vendored 快照是
// 离线保底;后台刷新(StartCatalogRefresh)在运行时换入新裁剪。旋钮仍按家手写(P4)。

//go:embed modelcatalog.json
var vendoredCatalogJSON []byte

// CatalogModel is one model's followed capability facts: input/output modality vocabularies
// (text / image / audio / video / pdf) plus the context/output token limits.
//
// CatalogModel 是一个模型被 follow 的能力事实:输入/输出模态词表(text/image/audio/video/pdf)
// + 上下文/输出 token 上限。
type CatalogModel struct {
	In     []string `json:"in"`
	Out    []string `json:"out"`
	Ctx    int      `json:"ctx"`
	MaxOut int      `json:"maxOut"`
	// Tools reports whether the model can call tools — i.e. whether it can drive the agent runtime
	// at all. A model without it is a perfectly good CHAT model and a useless AGENT, and those are
	// two different facts about the same row; see the trim predicate for why it is carried rather
	// than used as a filter.
	// Tools 报告模型会不会调工具——也就是它到底能不能驱动 agent 运行时。没有它的模型是一个**完全
	// 合格的聊天模型**、一个**没用的 agent**,而那是同一行上的**两个不同事实**;为什么把它**带出来**
	// 而不是拿它当过滤器,见裁剪谓词。
	Tools bool `json:"tools"`
}

// CatalogProvider is one upstream provider as models.dev describes it. The three provider-level
// fields are exactly the three things we stopped hand-maintaining (H12-c):
//
//   - Name — what to call it in the picker.
//   - NPM — the SDK package, which is our DIALECT HINT and **not** a wire protocol. 137 of the 173
//     ship `@ai-sdk/openai-compatible`; the rest publish their own package while still speaking the
//     same wire. Reading it as a protocol name would invent 22 dialects that do not exist.
//   - API — the base URL, and it is EMPTY for most first-party providers (openai, anthropic, google,
//     azure, bedrock, cohere, xai, groq…) because their SDK hard-codes it. That absence is the whole
//     reason a prefill can never be「just read the catalog」: 149 of 173 declare one, and the 24 that
//     do not are the ones most people start with.
//
// CatalogProvider 是 models.dev 描述的一家上游。三个 provider 级字段恰是我们停止手工维护的三样(H12-c):
//
//   - Name——选择器里叫它什么。
//   - NPM——SDK **包名**,它是我们的**方言线索**、**不是**线缆协议。173 家里 137 家发
//     `@ai-sdk/openai-compatible`;其余各自发了个包,说的还是同一条线缆。把它当协议名读,会凭空
//     发明 22 条**并不存在**的方言。
//   - API——base URL,而它对多数一方供应商(openai/anthropic/google/azure/bedrock/cohere/xai/groq…)
//     **是空的**,因为那些 SDK 把它写死在自己里面。这个缺席正是「预填不可能只是读目录」的全部理由:
//     173 家里 149 家声明了它,而**没声明的那 24 家恰恰是大多数人一上来就用的**。
type CatalogProvider struct {
	Name   string                  `json:"name"`
	NPM    string                  `json:"npm"`
	API    string                  `json:"api"`
	Models map[string]CatalogModel `json:"models"`
}

// ModelCatalog is the trimmed models.dev projection, keyed by models.dev's OWN provider ids. Our
// own provider names (qwen / zhipu / moonshot) reach it through [catalogProviderMap]; the other
// ~167 are addressed by their upstream id because we have no name of our own for them.
//
// ModelCatalog 是裁剪后的 models.dev 投影,键为 **models.dev 自己的** provider id。我们自己的名字
// (qwen / zhipu / moonshot)经 [catalogProviderMap] 抵达它;其余约 167 家按上游 id 寻址——因为我们
// **没有**自己的名字给它们。
type ModelCatalog struct {
	Source    string                     `json:"source"`
	Providers map[string]CatalogProvider `json:"providers"`
}

// catalogProviderMap renames the handful of providers this app knew before it followed the whole
// catalog — our vocabulary on the left of the arrow, models.dev's on the right. It is an ALIAS
// table, not a filter: every other provider is addressed by its upstream id, and nothing is
// discarded for being absent from this map (H12-c; before that, this map WAS the filter and the
// catalog held six providers).
//
// catalogProviderMap 给「本 app 在 follow 整个目录之前就认识的那几家」改名——箭头左边是我们的词表、
// 右边是 models.dev 的。它是**别名**表、不是过滤器:其余每一家按上游 id 寻址,而**不在这张表里**
// 不再意味着被丢弃(H12-c;在那之前,这张表**就是**过滤器,目录里只有六家)。
var catalogProviderMap = map[string]string{
	"qwen":     "alibaba",
	"moonshot": "moonshotai",
	"zhipu":    "zhipuai",
}

// catalogRequired are the providers whose absence means the refresh is BROKEN rather than merely
// thinner: they are the ones the app ships knobs and defaults for, so a catalog without them would
// blank out the picker for an existing user. Everything else may come and go upstream.
//
// catalogRequired 是「缺席即刷新**坏了**、而不只是变薄」的那几家:它们是本 app 自带旋钮与默认值的
// 那些,故一份没有它们的目录会把现有用户的选择器清空。其余各家在上游来去自由。
var catalogRequired = []string{"openai", "anthropic", "deepseek", "alibaba", "moonshotai", "zhipuai"}

// catalogKey resolves OUR provider name to the models.dev id it lives under.
//
// catalogKey 把**我们的** provider 名解析成它在 models.dev 里的 id。
func catalogKey(ours string) string {
	if theirs, ok := catalogProviderMap[ours]; ok {
		return theirs
	}
	return ours
}

// currentCatalog holds the active catalog: the vendored snapshot at init, possibly replaced by a
// fresher cached/downloaded trim (load priority: runtime cache > vendored — see catalogrefresh.go).
var currentCatalog atomic.Pointer[ModelCatalog]

func init() {
	cat, err := ParseCatalog(vendoredCatalogJSON)
	if err != nil {
		// The vendored snapshot ships inside the binary and is guarded by tests; failing loudly at
		// init beats serving an empty capability catalog that silently hides every direct model.
		// vendored 快照随二进制内嵌且有测试守卫;init 大声失败胜过静默端出空目录、藏掉全部直连模型。
		panic(fmt.Sprintf("llm: vendored model catalog invalid: %v", err))
	}
	currentCatalog.Store(cat)
}

// ParseCatalog decodes and validates a trimmed catalog document.
//
// ParseCatalog 解码并校验一份裁剪目录。
func ParseCatalog(data []byte) (*ModelCatalog, error) {
	var cat ModelCatalog
	if err := json.Unmarshal(data, &cat); err != nil {
		return nil, fmt.Errorf("model catalog: %w", err)
	}
	if err := cat.validate(); err != nil {
		return nil, err
	}
	return &cat, nil
}

// validate enforces the shape the rest of the package relies on: all six providers present, every
// model with a text-bearing modality pair and a positive context window. A refresh that fails this
// is discarded (the previous catalog stays active) — a half-empty upstream must never blank out
// the picker.
//
// validate 强制本包依赖的形状:六家齐、每模型带含 text 的模态对 + 正上下文窗。刷新不过此关即弃
// (旧目录继续生效)——上游半残绝不能清空选择器。
func (c *ModelCatalog) validate() error {
	if c == nil || len(c.Providers) == 0 {
		return fmt.Errorf("model catalog: empty document")
	}
	for _, theirs := range catalogRequired {
		p, ok := c.Providers[theirs]
		if !ok || len(p.Models) == 0 {
			return fmt.Errorf("model catalog: provider %q missing or empty", theirs)
		}
	}
	for theirs, p := range c.Providers {
		for id, m := range p.Models {
			if id == "" || m.Ctx <= 0 || len(m.In) == 0 || len(m.Out) == 0 {
				return fmt.Errorf("model catalog: provider %q model %q malformed (ctx=%d in=%d out=%d)", theirs, id, m.Ctx, len(m.In), len(m.Out))
			}
		}
	}
	return nil
}

// TrimUpstreamCatalog projects a raw models.dev api.json onto our catalog. What is kept is
// everything that can actually hold a chat completion, and the predicate is deliberately narrower
// than it used to be (H12-b):
//
//   - "text" ∈ modalities.output — a chat completion must be able to answer in text. A model that
//     only emits images or audio is not a chat model at all; the generation TOOLS reach those, and
//     putting them in the chat picker would offer a conversation that cannot happen.
//   - id does not contain "realtime" — realtime models do not speak /chat/completions; listing them
//     would violate "功能诚实地不出现,而非调用后失败" (WRK-082 §0).
//   - limit.context > 0 — with no declared window there is no envelope to size, so compaction and
//     the attachment budget would both be computing against zero. This one surfaced the moment the
//     predicate widened: `gpt-image-1.5` declares text output and NO context, and it is the reason
//     this clause is written down rather than assumed.
//
// **`tool_call` is no longer a filter — it is a FACT we carry** (H12-b, 用户 2026-07-28 拍板).
// Dropping a model for lacking tools threw away a whole class of perfectly usable chat models on
// behalf of a user who never asked; and it did so INVISIBLY, so the model simply "was not there"
// with no way to learn why. Now the row survives carrying `tools:false`, and the picker says what
// it is: 能聊天、不能当 agent.
//
// TrimUpstreamCatalog 把原始 api.json 投影成我们的目录。留下的是**真正能装下一次 chat completion**
// 的一切,而这个谓词比从前**刻意更窄**(H12-b):
//
//   - 输出含 "text"——一次 chat completion 必须能用文本作答。只出图或只出音频的模型**根本不是**
//     聊天模型;生成**工具**够得到它们,把它们放进聊天选择器等于提供一场不可能发生的对话。
//   - id 不含 "realtime"——realtime 不讲 /chat/completions,列出即违背「绝无调了才失败」。
//   - limit.context > 0——没有声明窗口就没有信封可量,压缩与附件预算都会对着 0 计算。这一条是谓词
//     放宽的**当场**冒出来的:`gpt-image-1.5` 声明输出含文本、却**没有** context,它正是这一条被
//     写下来、而不是被默认的理由。
//
// **`tool_call` 不再是过滤器、而是我们带出来的一个事实**(H12-b,用户 2026-07-28 拍板)。因为没有工具
// 就丢掉一个模型,是**替一个从没这么要求过的用户**扔掉一整类完全可用的聊天模型;而且扔得**看不见**
// ——那个模型就是「不在那儿」,没有任何途径知道为什么。现在这一行带着 `tools:false` 活下来,选择器
// 直说它是什么:**能聊天、不能当 agent**。
func TrimUpstreamCatalog(raw []byte) (*ModelCatalog, error) {
	var upstream map[string]struct {
		Name   string `json:"name"`
		NPM    string `json:"npm"`
		API    string `json:"api"`
		Models map[string]struct {
			ToolCall   bool `json:"tool_call"`
			Modalities struct {
				Input  []string `json:"input"`
				Output []string `json:"output"`
			} `json:"modalities"`
			Limit struct {
				Context int `json:"context"`
				Output  int `json:"output"`
			} `json:"limit"`
		} `json:"models"`
	}
	if err := json.Unmarshal(raw, &upstream); err != nil {
		return nil, fmt.Errorf("models.dev api.json: %w", err)
	}
	out := &ModelCatalog{
		Source:    "https://models.dev/api.json",
		Providers: make(map[string]CatalogProvider, len(upstream)),
	}
	for theirs, prov := range upstream {
		models := make(map[string]CatalogModel, len(prov.Models))
		for id, m := range prov.Models {
			if !hasModality(m.Modalities.Output, "text") || strings.Contains(id, "realtime") || m.Limit.Context <= 0 {
				continue
			}
			models[id] = CatalogModel{
				In:     append([]string(nil), m.Modalities.Input...),
				Out:    append([]string(nil), m.Modalities.Output...),
				Ctx:    m.Limit.Context,
				MaxOut: m.Limit.Output,
				Tools:  m.ToolCall,
			}
		}
		// A provider whose every model failed the predicate is not carried: an entry with no usable
		// model is a name in a picker that leads nowhere.
		// 所有模型都没过谓词的家不收:一个没有可用模型的条目,是选择器里一个**通向虚无**的名字。
		if len(models) == 0 {
			continue
		}
		name := prov.Name
		if name == "" {
			name = theirs
		}
		out.Providers[theirs] = CatalogProvider{Name: name, NPM: prov.NPM, API: prov.API, Models: models}
	}
	for _, theirs := range catalogRequired {
		if _, ok := out.Providers[theirs]; !ok {
			return nil, fmt.Errorf("models.dev api.json: provider %q absent upstream", theirs)
		}
	}
	if err := out.validate(); err != nil {
		return nil, err
	}
	return out, nil
}

// marshalCatalog renders a catalog in the canonical vendored form: two-space indent, sorted map
// keys (encoding/json sorts), trailing newline — reruns produce byte-stable diffs.
//
// marshalCatalog 以规范 vendored 形渲染目录:两空格缩进、map 键排序(encoding/json 自排)、
// 尾随换行——重跑得到字节稳定 diff。
func marshalCatalog(cat *ModelCatalog) ([]byte, error) {
	data, err := json.MarshalIndent(cat, "", "  ")
	if err != nil {
		return nil, err
	}
	return append(data, '\n'), nil
}

// MarshalCatalog is marshalCatalog for the vendoring command.
//
// MarshalCatalog 供 vendoring 命令使用。
func MarshalCatalog(cat *ModelCatalog) ([]byte, error) { return marshalCatalog(cat) }

func hasModality(list []string, want string) bool {
	for _, s := range list {
		if strings.EqualFold(s, want) {
			return true
		}
	}
	return false
}

// catalogSpecs builds the provider's modelSpec list from the active catalog: one spec per catalog
// model (id doubles as the match prefix — dated variants like claude-opus-4-8-20260115 hit their
// family entry), sorted longest-prefix-first so matchSpec's precedence rule keeps working, knobs
// attached by the provider's hand-written rule (P4).
//
// catalogSpecs 从活动目录构建该家的 modelSpec 列表:每个目录模型一条(id 兼作匹配前缀——带日期
// 变体命中族条目),按前缀长度降序排(保住 matchSpec 的优先规则),旋钮由该家手写规则挂上(P4)。
func catalogSpecs(provider string, knobsFor func(id string) []Knob) []modelSpec {
	cat := currentCatalog.Load()
	models := cat.Providers[catalogKey(provider)].Models
	specs := make([]modelSpec, 0, len(models))
	for id, m := range models {
		var knobs []Knob
		if knobsFor != nil {
			knobs = knobsFor(id)
		}
		specs = append(specs, modelSpec{prefix: id, ctx: m.Ctx, out: m.MaxOut, knobs: knobs, in: m.In, outMod: m.Out, tools: m.Tools})
	}
	sort.Slice(specs, func(i, j int) bool {
		if len(specs[i].prefix) != len(specs[j].prefix) {
			return len(specs[i].prefix) > len(specs[j].prefix)
		}
		return specs[i].prefix < specs[j].prefix
	})
	return specs
}
