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

// ModelCatalog is the trimmed models.dev projection keyed by OUR provider names.
//
// ModelCatalog 是裁剪后的 models.dev 投影,键为**我们的** provider 名。
type ModelCatalog struct {
	Source    string                             `json:"source"`
	Providers map[string]map[string]CatalogModel `json:"providers"`
}

// catalogProviderMap maps a models.dev provider key to our provider name — exactly the six
// followed providers; everything else upstream is discarded by the trim.
//
// catalogProviderMap 把 models.dev 的 provider 键映到我们的 provider 名——恰好六家;上游其余
// 一律被裁剪丢弃。
var catalogProviderMap = map[string]string{
	"openai":     "openai",
	"anthropic":  "anthropic",
	"deepseek":   "deepseek",
	"alibaba":    "qwen",
	"moonshotai": "moonshot",
	"zhipuai":    "zhipu",
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
	for _, ours := range catalogProviderMap {
		models, ok := c.Providers[ours]
		if !ok || len(models) == 0 {
			return fmt.Errorf("model catalog: provider %q missing or empty", ours)
		}
		for id, m := range models {
			if id == "" || m.Ctx <= 0 || len(m.In) == 0 || len(m.Out) == 0 {
				return fmt.Errorf("model catalog: provider %q model %q malformed (ctx=%d in=%d out=%d)", ours, id, m.Ctx, len(m.In), len(m.Out))
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
		Providers: make(map[string]map[string]CatalogModel, len(catalogProviderMap)),
	}
	for theirs, ours := range catalogProviderMap {
		prov, ok := upstream[theirs]
		if !ok {
			return nil, fmt.Errorf("models.dev api.json: provider %q absent upstream", theirs)
		}
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
		out.Providers[ours] = models
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
	models := cat.Providers[provider]
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
