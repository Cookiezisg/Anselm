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
		})
	}
	return out
}
