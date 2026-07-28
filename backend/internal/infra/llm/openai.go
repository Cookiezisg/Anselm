package llm

import "fmt"

// openaiProvider is the OpenAI family's [compatSpec] over the shared [compatProvider]. What is
// OpenAI-specific and nothing else: `max_completion_tokens` (not `max_tokens`), the
// reasoning_effort + verbosity pair, and `file` content parts (inline PDF).
//
// openaiProvider 是 OpenAI 家在共享 [compatProvider] 上的 [compatSpec]。**只属于 OpenAI** 的东西:
// `max_completion_tokens`(不是 `max_tokens`)、reasoning_effort + verbosity 这一对、以及 `file`
// content part(内联 PDF)。
func newOpenAIProvider() *compatProvider {
	return &compatProvider{spec: compatSpec{
		name:    "openai",
		baseURL: func() string { return "https://api.openai.com/v1" },
		wire:    openaiWire,
		parts:   openaiParts,
		encode: func(req Request, body *compatRequest) {
			if req.MaxTokens > 0 {
				body.MaxCompletionTokens = req.MaxTokens
			}
			// Native knobs straight from Options — no neutral abstraction, no clamping. The UI only
			// offers values from Knobs(modelID); a non-reasoning model simply carries none of these.
			// 原生旋钮直接取自 Options——无中立抽象、不 clamp。UI 只给 Knobs(modelID) 声明的值。
			if v := req.Options["reasoning_effort"]; v != "" {
				body.ReasoningEffort = v
			}
			if v := req.Options["verbosity"]; v != "" {
				body.Verbosity = v
			}
		},
		describe: func(raw string) ([]ModelInfo, error) {
			return describeFromSpecs(catalogSpecs("openai", knobsByPrefix(openaiKnobRules)), raw, openaiWire), nil
		},
	}}
}

// openaiParts renders text / image_url / file. The `file` part is the one thing this family adds to
// the floor, and it is why an unknown part type is an ERROR here rather than a skip: OpenAI is the
// family whose part vocabulary we actually know completely, so a part we cannot name is a bug in
// the caller, not a degradation we should paper over.
//
// openaiParts 渲 text / image_url / file。`file` 是本家在地板之上多出的那一样,也正是这里对未知 part
// **报错**而非跳过的理由:OpenAI 是我们**真正完整知道**其 part 词汇表的那一家,故一个叫不出名字的
// part 是调用方的 bug、不是我们该糊过去的降级。
func openaiParts(m LLMMessage) (compatMessage, error) {
	parts := make([]compatContentPart, 0, len(m.Parts))
	for _, part := range m.Parts {
		switch part.Type {
		case "text":
			parts = append(parts, compatContentPart{Type: "text", Text: part.Text})
		case "image_url":
			parts = append(parts, compatContentPart{Type: "image_url", ImageURL: &compatImageURL{URL: part.ImageURL}})
		case "file":
			parts = append(parts, compatContentPart{Type: "file", File: &compatFile{
				Filename: part.Filename,
				FileData: "data:" + part.MediaType + ";base64," + part.Data,
			}})
		default:
			return compatMessage{}, fmt.Errorf("llm.openai: unknown part type %q: %w", part.Type, ErrBadRequest)
		}
	}
	return compatPartsMessage(parts)
}

// ── model catalog (static; OpenAI /v1/models returns ids only) ──────────────────

// oaiKnobs builds the reasoning_effort + verbosity descriptors for a GPT-5-era model with the
// given native effort set and default. o-series models get effort only (see openaiSpecs).
//
// oaiKnobs 为 GPT-5 代模型构造 reasoning_effort + verbosity 描述符（给定原生 effort 集与默认）。
// o 系列只有 effort（见 openaiSpecs）。
func oaiKnobs(effortDefault string, efforts ...string) []Knob {
	return []Knob{
		enumKnob("reasoning_effort", "Reasoning effort", efforts, effortDefault),
		enumKnob("verbosity", "Verbosity", []string{"low", "medium", "high"}, "medium"),
	}
}

// openaiWire: the OpenAI dialect renders text / image_url / file parts (see buildParts cases).
//
// openaiWire:OpenAI 方言渲 text / image_url / file 三种 part(见 buildParts 的 case)。
var openaiWire = partMask{image: true, file: true}

// openaiKnobRules keeps OpenAI's hand-written native knob surfaces (P4), most-specific prefix
// first; capability numbers and modalities come from the models.dev catalog.
//
// openaiKnobRules 保留 OpenAI 手写原生旋钮面(P4),最具体前缀在前;能力数字与模态出自
// models.dev 目录。
var openaiKnobRules = []knobRule{
	{"gpt-5.5", oaiKnobs("medium", "none", "low", "medium", "high", "xhigh")},
	{"gpt-5.4-mini", oaiKnobs("none", "none", "low", "medium", "high", "xhigh")},
	{"gpt-5.4", oaiKnobs("none", "none", "low", "medium", "high", "xhigh")},
	{"gpt-5.1", oaiKnobs("none", "none", "low", "medium", "high")},
	{"gpt-5", oaiKnobs("medium", "minimal", "low", "medium", "high")},
	{"o3", []Knob{enumKnob("reasoning_effort", "Reasoning effort", []string{"low", "medium", "high"}, "medium")}},
	{"o4", []Knob{enumKnob("reasoning_effort", "Reasoning effort", []string{"low", "medium", "high"}, "medium")}},
}

// DescribeModels parses OpenAI's id-only /v1/models body against the followed catalog; ids absent
// from the catalog are skipped.
//
// DescribeModels 解析 OpenAI 仅含 id 的 /v1/models 返回,查 follow 目录;目录外 id 跳过。
