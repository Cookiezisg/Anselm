package llm

import (
	"encoding/json"
	"fmt"
	"strings"
)

// newDeepSeekProvider is the DeepSeek family's [compatSpec]. Two things are DeepSeek's alone: the
// reasoning_content round-trip rule (below) and the thinking + reasoning_effort pair.
//
// newDeepSeekProvider 是 DeepSeek 家的 [compatSpec]。**只属于 DeepSeek** 的有两样:下面那条
// reasoning_content round-trip 规则,以及 thinking + reasoning_effort 这一对。
func newDeepSeekProvider() *compatProvider {
	return &compatProvider{spec: compatSpec{
		name:    "deepseek",
		baseURL: func() string { return "https://api.deepseek.com" },
		wire:    deepseekWire,
		prepare: stripPlainTurnReasoning,
		parts:   deepseekParts,
		encode: func(req Request, body *compatRequest) {
			if req.MaxTokens > 0 {
				body.MaxTokens = req.MaxTokens
			}
			if v := req.Options["thinking"]; v != "" {
				body.Thinking = &compatThinking{Type: v}
			}
			if v := req.Options["reasoning_effort"]; v != "" {
				body.ReasoningEffort = v
			}
		},
		describe: describeDeepseek,
	}}
}

// stripPlainTurnReasoning drops reasoning_content from assistant turns that carry no tool_calls.
//
// **It is an upstream rule, not a preference.** DeepSeek rejects a continuation whose assistant
// turn carries reasoning_content without a tool response; tool-call turns must KEEP it, because the
// chain of thought is reconstructed from it. Getting this backwards fails only on the second turn
// of a conversation, which is exactly the kind of bug a single-turn test never sees.
//
// stripPlainTurnReasoning 从**不带 tool_calls** 的 assistant 回合上剥掉 reasoning_content。
//
// **这是上游的规则、不是偏好。** DeepSeek 拒绝「assistant 回合带 reasoning_content 却没有工具响应」
// 的续写;而带 tool_calls 的回合必须**保留**它,因为思维链要据此重建。搞反了只在对话的**第二个**回合
// 才失败——正是单回合测试永远看不见的那种 bug。
func stripPlainTurnReasoning(msgs []LLMMessage) []LLMMessage {
	for i := range msgs {
		m := &msgs[i]
		if m.Role == RoleAssistant && len(m.ToolCalls) == 0 {
			m.ReasoningContent = ""
		}
	}
	return msgs
}

// deepseekParts renders text / image_url / video_url / input_audio, and collapses back to a plain
// string when NO media survived: a parts array holding only text is legal but wasteful, and some
// deployments of this wire treat a media-less array more strictly than a plain string.
//
// deepseekParts 渲 text / image_url / video_url / input_audio,并在**没有媒体幸存**时塌回一个普通
// 字符串:只装文本的 parts 数组合法但浪费,而这条线缆的某些部署对**无媒体的数组**比对普通字符串更严格。
func deepseekParts(m LLMMessage) (compatMessage, error) {
	parts := make([]compatContentPart, 0, len(m.Parts))
	hasMedia := false
	for _, part := range m.Parts {
		switch part.Type {
		case PartText:
			parts = append(parts, compatContentPart{Type: PartText, Text: part.Text})
		case PartImageURL:
			hasMedia = true
			parts = append(parts, compatContentPart{Type: PartImageURL, ImageURL: &compatImageURL{URL: part.ImageURL}})
		case PartVideoURL:
			hasMedia = true
			parts = append(parts, compatContentPart{Type: PartVideoURL, VideoURL: &compatVideoURL{URL: part.VideoURL}})
		case PartInputAudio:
			if format := openAICompatibleAudioFormat(part.MediaType); format != "" && part.Data != "" {
				hasMedia = true
				parts = append(parts, compatContentPart{Type: PartInputAudio, InputAudio: &compatInputAudio{Data: part.Data, Format: format}})
			}
		}
	}
	if !hasMedia {
		texts := make([]string, len(parts))
		for i, p := range parts {
			texts[i] = p.Text
		}
		return compatMessage{Role: "user", Content: jsonString(strings.Join(texts, "\n\n"))}, nil
	}
	raw, err := json.Marshal(parts)
	if err != nil {
		return compatMessage{}, fmt.Errorf("llm.deepseek: marshal parts: %w", err)
	}
	return compatMessage{Role: "user", Content: raw}, nil
}

func openAICompatibleAudioFormat(mediaType string) string {
	mediaType = strings.ToLower(strings.TrimSpace(strings.Split(mediaType, ";")[0]))
	switch mediaType {
	case "audio/wav", "audio/x-wav", "audio/wave":
		return "wav"
	case "audio/mpeg", "audio/mp3":
		return "mp3"
	default:
		return ""
	}
}

// ── model catalog (static; DeepSeek /models returns ids only) ───────────────────

func dsKnobs() []Knob {
	return []Knob{
		enumKnob("thinking", "Thinking", []string{"enabled", "disabled"}, "enabled"),
		enumKnob("reasoning_effort", "Reasoning effort", []string{"high", "max"}, "high"),
	}
}

// deepseekWire: the DeepSeek dialect renders text / image_url / video_url / input_audio parts
// (dsContentPart fields). Whether a given model reads them comes from the catalog modalities.
//
// deepseekWire:DeepSeek 方言渲 text / image_url / video_url / input_audio(dsContentPart 字段);
// 某个模型读不读它们由目录模态决定。
var deepseekWire = partMask{image: true, video: true, audio: true}

// deepseekKnobRules: the whole DeepSeek line controls thinking by request params (P4).
//
// deepseekKnobRules:DeepSeek 全线靠请求参数控思考(P4)。
var deepseekKnobRules = []knobRule{{"deepseek", dsKnobs()}}

// DescribeModels parses DeepSeek's id-only /models body against the followed catalog.
//
// DescribeModels 解析 DeepSeek 仅含 id 的 /models 返回,查 follow 目录。
func describeDeepseek(raw string) ([]ModelInfo, error) {
	return describeFromSpecs(catalogSpecs("deepseek", knobsByPrefix(deepseekKnobRules)), raw, deepseekWire), nil
}
