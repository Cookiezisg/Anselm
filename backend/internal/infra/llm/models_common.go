package llm

import (
	"encoding/json"
	"strings"
)

// modelSpec is one provider's knowledge of a model family: capability numbers, modality
// vocabularies and the native configurable knobs, keyed by modelID prefix (list order decides
// precedence — most specific prefix first). For the six followed providers the specs are built
// from the models.dev catalog (catalogSpecs); anselm keeps a hand-rolled entry (gateway-owned
// numbers, P5).
//
// modelSpec 是某家对一个模型族的知识:能力数字、模态词表与原生可调旋钮,按 modelID 前缀匹配
// (列表顺序定优先——最具体前缀在前)。六个被 follow 家的 specs 由 models.dev 目录构建
// (catalogSpecs);anselm 保留手写条目(数字网关自权威,P5)。
type modelSpec struct {
	prefix string
	ctx    int
	out    int
	knobs  []Knob
	in     []string // input modalities the MODEL accepts (text/image/audio/video/pdf), per catalog
	outMod []string // output modalities the model produces, per catalog (批B consumes this)
	tools  bool     // model can call tools — i.e. can drive the agent runtime (H12-b)
	// reasoning is the model's own declaration of its thinking controls (H12-c). The KNOB rendered
	// from it is `spelling × this`: the catalog says a control exists and what its values are, the
	// dialect says what it is called on the wire.
	// reasoning 是模型自己声明的思考控件(H12-c)。据它渲出的 **Knob = 拼法 × 它**:目录说「有这么一个
	// 控件、取值是这些」,方言说「它在线缆上叫什么」。
	reasoning []CatalogReasoning
}

// knobSpelling is how ONE dialect writes the thinking controls the catalog describes. It is the
// smallest possible remnant of the hand-written knob tables: four wire strings and a default,
// instead of a per-model-prefix list that had to be revised every time a vendor shipped a model.
//
// **A missing spelling means silence, not a guess.** A family with no `toggle` key simply renders
// no toggle even when the catalog says the model has one — because emitting a parameter name we
// invented is how you get a 400 that reads as「这个模型坏了」.
//
// knobSpelling 是**一条方言**怎么书写目录所描述的那些思考控件。它是手写旋钮表能剩下的最小残余:
// 四个线缆字符串加一个默认值,取代一张「厂商每发一个模型就要改一次」的逐前缀表。
//
// **拼法缺席即沉默、绝不猜。** 一个没有 `toggle` key 的家,即使目录说这个模型有开关也**不渲**它
// ——发出一个我们自己发明的参数名,正是「拿到一个读起来像『这个模型坏了』的 400」的方式。
type knobSpelling struct {
	effort     string // wire key for an effort enum
	effortDef  string
	toggle     string   // wire key for an on/off control
	toggleVals []string // the two native values, e.g. ["enabled","disabled"]; empty = a real bool
	toggleDef  string
	budget     string // wire key for a token budget
	// withEffort rides along ONLY on models that declare an effort control. OpenAI's `verbosity` is
	// the one case: it is not a reasoning control, but it shipped with the GPT-5 reasoning family and
	// older models reject it — so「有 effort 的那些模型」is the honest condition, and it comes from
	// the catalog rather than from a prefix we would have to revise.
	//
	// An unconditional extra would put `verbosity` on gpt-4o, which is how a picker grows a control
	// the model will refuse (caught by the capability test, not by me).
	//
	// withEffort **只**随「声明了 effort 控件的模型」出现。OpenAI 的 `verbosity` 是唯一这种情况:
	// 它不是推理控件,但它与 GPT-5 推理家族一同发布、更老的模型会拒绝它——故「有 effort 的那些模型」
	// 是诚实的条件,而这个条件来自**目录**、不是来自一个我们还得不断修订的前缀。
	//
	// 无条件的 extra 会把 `verbosity` 挂到 gpt-4o 上,而那正是「选择器长出一个模型会拒绝的控件」的
	// 方式(是能力测试逮到的,不是我)。
	withEffort []Knob
	// byPrefix is the escape hatch for a family whose controls the catalog does NOT fully declare,
	// and there is exactly one: Anthropic's `thinking` enum takes different value sets per model
	// (`adaptive/disabled` on the flagships, `adaptive/enabled/disabled` on 4.6, `enabled/disabled`
	// elsewhere) and models.dev states none of them — it declares only the effort levels. Keeping a
	// hand table for the half the catalog is silent about is the same rule as everywhere else, not
	// an exception to it: we maintain what the catalog does not say, and nothing more.
	// byPrefix 是「目录并未完整声明其控件」的家的逃生口,而这样的家**恰好只有一个**:Anthropic 的
	// `thinking` 枚举**逐模型**取不同的值集(旗舰 `adaptive/disabled`、4.6 `adaptive/enabled/disabled`、
	// 其余 `enabled/disabled`),而 models.dev 一个都没说——它只声明了 effort 档位。为目录**沉默的**那
	// 一半留一张手表,与别处是**同一条规则**、不是它的例外:我们维护目录没说的东西,仅此而已。
	byPrefix func(id string) []Knob
}

// knobsFromCatalog renders one model's declared controls through a dialect's spelling.
//
// knobsFromCatalog 把一个模型声明的控件,按某条方言的拼法渲出来。
func (k knobSpelling) knobsFor(id string, rs []CatalogReasoning) []Knob {
	if k.byPrefix != nil {
		return k.byPrefix(id)
	}
	var out []Knob
	for _, r := range rs {
		switch r.Type {
		case "effort":
			if k.effort == "" || len(r.Values) == 0 {
				continue
			}
			out = append(out, enumKnob(k.effort, "Reasoning effort", r.Values, k.effortDef))
			out = append(out, k.withEffort...)
		case "toggle":
			if k.toggle == "" {
				continue
			}
			if len(k.toggleVals) == 2 {
				out = append(out, enumKnob(k.toggle, "Thinking", k.toggleVals, k.toggleDef))
			} else {
				out = append(out, boolKnob(k.toggle, "Thinking", k.toggleDef))
			}
		case "budget_tokens":
			if k.budget == "" {
				continue
			}
			out = append(out, intKnob(k.budget, "Thinking budget", ""))
		}
	}
	return out
}

// partMask declares which ContentPart kinds a provider's BuildRequest can actually render on its
// wire. The projected ModelInfo booleans are catalog-modality ∧ mask: a model the catalog says
// reads PDF must still not advertise NativeDocs on a dialect that cannot carry a file part —
// capability advertising must describe the whole path (the gateway's "double-half" rule applied
// to dialects).
//
// partMask 声明某家 BuildRequest 真能上线缆的 ContentPart 种类。投影出的 ModelInfo 布尔
// = 目录模态 ∧ 掩码:目录说会读 PDF 的模型,在渲不了 file part 的方言上仍不得宣称 NativeDocs——
// 能力宣称必须描述整条路(网关「双半才真」用在方言上)。
type partMask struct {
	image, video, audio, file bool
}

// knobRule binds one hand-written native knob surface to a model-id prefix. Rules are checked in
// listed order (most specific prefix first, same convention as the old static tables); catalog
// models matching no rule get no knobs — conservative, the model still works (P4: knobs are kept
// hand-written and are deliberately NOT extended to families we have not verified).
//
// knobRule 把一份手写原生旋钮面绑到 model-id 前缀。按列表顺序匹配(最具体前缀在前,同旧静态表
// 惯例);目录里没规则命中的模型无旋钮——保守,模型照用(P4:旋钮保持手写,不主动扩到未核实的族)。
type knobRule struct {
	prefix string
	knobs  []Knob
}

// knobsByPrefix adapts an ordered rule list into catalogSpecs' knobsFor callback.
//
// knobsByPrefix 把有序规则表适配成 catalogSpecs 的 knobsFor 回调。
func knobsByPrefix(rules []knobRule) func(string) []Knob {
	return func(id string) []Knob {
		lid := strings.ToLower(strings.TrimSpace(id))
		for _, r := range rules {
			if strings.HasPrefix(lid, r.prefix) {
				return r.knobs
			}
		}
		return nil
	}
}

// matchSpec returns the first spec whose prefix matches modelID (case-insensitive).
//
// matchSpec 返回首个 prefix 命中 modelID 的 spec（大小写不敏感）。
func matchSpec(specs []modelSpec, modelID string) (modelSpec, bool) {
	id := strings.ToLower(strings.TrimSpace(modelID))
	for _, s := range specs {
		if strings.HasPrefix(id, s.prefix) {
			return s, true
		}
	}
	return modelSpec{}, false
}

// enumKnob builds an enum-type Knob descriptor with native key/values/default kept verbatim.
//
// enumKnob 构造 enum 型 Knob 描述符，key/取值/默认全原生原样。
func enumKnob(key, label string, values []string, def string) Knob {
	return Knob{Key: key, Label: label, Type: "enum", Values: values, Default: def}
}

// boolKnob builds a boolean Knob (frontend renders a toggle); def is "true"/"false".
//
// boolKnob 构造布尔 Knob（前端渲染开关）；def 为 "true"/"false"。
func boolKnob(key, label, def string) Knob {
	return Knob{Key: key, Label: label, Type: "bool", Default: def}
}

// intKnob builds an integer Knob (frontend renders a number input); def is the default as a
// string ("" = provider/model default).
//
// intKnob 构造整数 Knob（前端渲染数字输入）；def 为默认值字符串（"" = provider/模型默认）。
func intKnob(key, label, def string) Knob {
	return Knob{Key: key, Label: label, Type: "int", Default: def}
}

// decodeOpenAICompatModelIDs parses an OpenAI-style GET /models body ({"data":[{"id":...}]}) into
// its id list. Shared by every OpenAI-compat provider — this is list plumbing, not wire dialect
// (each provider still owns its own BuildRequest).
//
// decodeOpenAICompatModelIDs 解析 OpenAI 式 GET /models 返回（{"data":[{"id":...}]}）的 id 列表。
// 所有 OpenAI-compat 家共享——这是列表管道、非 wire 方言（各家仍自持 BuildRequest）。
func decodeOpenAICompatModelIDs(raw string) []string {
	var resp struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if json.Unmarshal([]byte(raw), &resp) != nil {
		return nil
	}
	out := make([]string, 0, len(resp.Data))
	for _, m := range resp.Data {
		if m.ID != "" {
			out = append(out, m.ID)
		}
	}
	return out
}

// describeFromSpecs assembles ModelInfo for each id in an OpenAI-compat /models body by looking it
// up in specs; ids with no matching spec are skipped (unknown to the catalog — the user may still
// target such a model id directly, it just carries no knobs/specs here). Modality booleans are
// projected as catalog-modality ∧ dialect mask (see partMask).
//
// describeFromSpecs 对 OpenAI-compat /models 返回里每个 id 查 specs 装配 ModelInfo;无匹配 spec 的
// id 跳过(目录未知——用户仍可直接用该 id,只是这里没有旋钮/规格)。模态布尔投影 = 目录模态 ∧
// 方言掩码(见 partMask)。
// describeAllFromCatalog answers with EVERY model the catalog attributes to a provider, for the one
// case where there is no /models list to intersect with: Vertex addresses models through publisher
// paths and has no OpenAI-shaped listing, so the catalog is the only inventory that exists.
//
// The ordinary [describeFromSpecs] intersects the provider's own list with the catalog, which is
// strictly better when the list exists — it stops us offering a model this particular account
// cannot reach. Reaching for this function where a listing exists would trade that for nothing.
//
// describeAllFromCatalog 交回目录归给某家的**每一个**模型,只为那唯一一种情况:**没有 /models 列表**
// 可以求交——Vertex 按 publisher 路径寻址模型、没有 OpenAI 形的列举,故目录是**存在的唯一**清单。
//
// 普通的 [describeFromSpecs] 把该家自己的列表与目录求交,而在列表存在时那严格更好——它避免我们提供
// 一个**这个账号够不着**的模型。在有列举的地方改用本函数,是拿那个好处换了个零。
func describeAllFromCatalog(specs []modelSpec, mask partMask) []ModelInfo {
	out := make([]ModelInfo, 0, len(specs))
	for _, s := range specs {
		out = append(out, ModelInfo{
			ID:            s.prefix,
			DisplayName:   s.prefix,
			ContextWindow: s.ctx,
			MaxOutput:     s.out,
			Knobs:         s.knobs,
			Vision:        mask.image && hasModality(s.in, "image"),
			Video:         mask.video && hasModality(s.in, "video"),
			Audio:         mask.audio && hasModality(s.in, "audio"),
			NativeDocs:    mask.file && hasModality(s.in, "pdf"),
			Tools:         s.tools,
		})
	}
	return out
}

func describeFromSpecs(specs []modelSpec, raw string, mask partMask) []ModelInfo {
	ids := decodeOpenAICompatModelIDs(raw)
	out := make([]ModelInfo, 0, len(ids))
	for _, id := range ids {
		s, ok := matchSpec(specs, id)
		if !ok {
			continue
		}
		out = append(out, ModelInfo{
			ID:            id,
			DisplayName:   id,
			ContextWindow: s.ctx,
			MaxOutput:     s.out,
			Knobs:         s.knobs,
			Vision:        mask.image && hasModality(s.in, "image"),
			Video:         mask.video && hasModality(s.in, "video"),
			Audio:         mask.audio && hasModality(s.in, "audio"),
			NativeDocs:    mask.file && hasModality(s.in, "pdf"),
			Tools:         s.tools,
		})
	}
	return out
}
