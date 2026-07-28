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
			return describeFromSpecs(openaiCatalogSpecs(), raw, openaiWire), nil
		},
	}}
}

// openaiParts renders text / image_url / input_audio / file. The `file` part is the one thing this family adds to
// the floor, and it is why an unknown part type is an ERROR here rather than a skip: OpenAI is the
// family whose part vocabulary we actually know completely, so a part we cannot name is a bug in
// the caller, not a degradation we should paper over.
//
// openaiParts 渲 text / image_url / input_audio / file。`file` 是本家在地板之上多出的那一样,也正是这里对未知 part
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
		case PartInputAudio:
			if format := openAICompatibleAudioFormat(part.MediaType); format != "" && part.Data != "" {
				parts = append(parts, compatContentPart{Type: PartInputAudio, InputAudio: &compatInputAudio{
					Data: part.Data, Format: format,
				}})
			}
		default:
			return compatMessage{}, fmt.Errorf("llm.openai: unknown part type %q: %w", part.Type, ErrBadRequest)
		}
	}
	return compatPartsMessage(parts)
}

// ── model catalog (static; OpenAI /v1/models returns ids only) ──────────────────

// openaiWire: the OpenAI dialect renders text / image_url / input_audio / file parts (see buildParts cases).
//
// openaiWire:OpenAI 方言渲 text / image_url / input_audio / file 四种 part(见 buildParts 的 case)。
var openaiWire = partMask{image: true, audio: true, file: true}

// openaiAudioFallback is the provider-owned bridge for a live OpenAI model family that is
// temporarily absent from models.dev. The official OpenAI contract gives this family its own
// stable 128K/16K envelope, text+audio input/output and function calling; keeping that fact here
// prevents a catalog lag from making a real, supported account look as though it cannot send
// input_audio. The fallback is appended only while the exact family is absent, so a later catalog
// refresh remains authoritative and naturally retires this bridge.
//
// openaiAudioFallback 是 models.dev 暂时缺席的一整个 OpenAI live model family 的 provider-owned
// 桥。OpenAI 官方契约给它稳定的 128K/16K 信封、text+audio 输入/输出与 function calling；把这条事实
// 留在这里，避免目录滞后把一个真实、受支持的账号伪装成不能发 input_audio。只有目录完全缺席该家族
// 时才追加；目录补齐后自然优先、桥自动退役。
var openaiAudioFallback = modelSpec{
	prefix: "gpt-audio", ctx: 128_000, out: 16_384,
	in: []string{"text", "audio"}, outMod: []string{"text", "audio"}, tools: true,
}

func openaiCatalogSpecs() []modelSpec {
	specs := catalogSpecs("openai", openaiKnobs)
	if _, ok := catalogModel("openai", "gpt-audio"); !ok {
		specs = append(specs, openaiAudioFallback)
	}
	return specs
}

// DescribeModels parses OpenAI's id-only /v1/models body against the followed catalog; ids absent
// from the catalog are skipped.
//
// DescribeModels 解析 OpenAI 仅含 id 的 /v1/models 返回,查 follow 目录;目录外 id 跳过。

// describeOpenai parses OpenAI's id-only /v1/models body against the followed catalog; ids absent
// from the catalog are skipped.
//
// describeOpenai 解析 OpenAI 仅含 id 的 /v1/models 返回,查 follow 目录;目录外 id 跳过。
func describeOpenai(raw string) ([]ModelInfo, error) {
	return describeFromSpecs(openaiCatalogSpecs(), raw, openaiWire), nil
}
