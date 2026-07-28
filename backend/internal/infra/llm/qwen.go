package llm

import (
	"strconv"
	"strings"
)

// newQwenProvider is the Qwen (DashScope) family's [compatSpec]. Its own: the enable_thinking bool
// + thinking_budget int pair (top-level body fields, NOT extra_body), and the widest part
// vocabulary in this dialect — image, video and audio all inline.
//
// newQwenProvider 是 Qwen(DashScope)家的 [compatSpec]。它自己的东西:enable_thinking(bool)与
// thinking_budget(int)这一对(**顶层** body 字段、不是 extra_body),以及本方言里最宽的 part 词汇表
// ——图、视频、音频全部内联。
func newQwenProvider() *compatProvider {
	return &compatProvider{spec: compatSpec{
		name:    "qwen",
		baseURL: func() string { return "https://dashscope.aliyuncs.com/compatible-mode/v1" },
		wire:    qwenWire,
		parts:   qwenParts,
		encode: func(req Request, body *compatRequest) {
			if req.MaxTokens > 0 {
				body.MaxTokens = req.MaxTokens
			}
			if v := req.Options["enable_thinking"]; v != "" {
				b := v == "true"
				body.EnableThinking = &b
			}
			if v := req.Options["thinking_budget"]; v != "" {
				if n, err := strconv.Atoi(v); err == nil {
					body.ThinkingBudget = n
				}
			}
		},
		cumulativeText: func(modelID string) bool {
			// DashScope's Qwen-MT translation models return the full translated prefix in each SSE
			// content delta (observed on qwen-mt-plus). Other Qwen families retain normal increments.
			// DashScope 的 Qwen-MT 翻译模型在每个 SSE content delta 重发完整译文前缀（qwen-mt-plus 真线缆实证）；
			// 其余 Qwen 家族仍是普通增量。
			return strings.HasPrefix(modelID, "qwen-mt-")
		},
		prepareSystemForModel: func(modelID, system string, msgs []LLMMessage) (string, []LLMMessage) {
			if !strings.HasPrefix(modelID, "qwen-mt-") || strings.TrimSpace(system) == "" {
				return system, msgs
			}
			prefix := "System instructions:\n" + system + "\n\n"
			for i := range msgs {
				if msgs[i].Role != RoleUser {
					continue
				}
				if len(msgs[i].Parts) == 0 {
					msgs[i].Content = prefix + msgs[i].Content
					return "", msgs
				}
				// A multimodal first user message cannot safely absorb text into its parts here. Put a
				// text-only user message immediately before it; the provider still sees no system role.
				out := make([]LLMMessage, 0, len(msgs)+1)
				out = append(out, LLMMessage{Role: RoleUser, Content: prefix})
				out = append(out, msgs[:i]...)
				out = append(out, msgs[i:]...)
				return "", out
			}
			return "", append([]LLMMessage{{Role: RoleUser, Content: prefix}}, msgs...)
		},
		describe: describeQwen,
	}}
}

// qwenParts renders text / image_url / video_url / input_audio. Unknown parts are skipped, not
// refused — see [compatTextImageParts] for why.
//
// qwenParts 渲 text / image_url / video_url / input_audio。未知 part 跳过而非拒绝,理由见
// [compatTextImageParts]。
func qwenParts(m LLMMessage) (compatMessage, error) {
	parts := make([]compatContentPart, 0, len(m.Parts))
	for _, part := range m.Parts {
		switch part.Type {
		case "text":
			parts = append(parts, compatContentPart{Type: "text", Text: part.Text})
		case "image_url":
			parts = append(parts, compatContentPart{Type: "image_url", ImageURL: &compatImageURL{URL: part.ImageURL}})
		case PartVideoURL:
			parts = append(parts, compatContentPart{Type: "video_url", VideoURL: &compatVideoURL{URL: part.VideoURL}})
		case PartInputAudio:
			mediaType := strings.TrimSpace(part.MediaType)
			if mediaType == "" {
				// Attachment rendering always supplies a MIME type. Keep direct callers safe too: a
				// valid WAV data URL beats emitting an invalid empty media type.
				// 附件渲染总会给出 MIME。直接调用方也要安全:一个有效的 WAV data URL 好过发一个
				// 无效的空媒体类型。
				mediaType = "audio/wav"
			}
			parts = append(parts, compatContentPart{Type: "input_audio", InputAudio: &compatInputAudio{
				Data: "data:" + mediaType + ";base64," + part.Data, Format: qwenAudioFormat(mediaType),
			}})
		}
	}
	return compatPartsMessage(parts)
}

// qwenAudioFormat maps a MIME type to the `format` string Qwen's input_audio part wants, falling
// back to the subtype (and finally "wav") rather than refusing: a format we do not recognise is
// still worth trying, and the upstream will say so if it disagrees.
//
// qwenAudioFormat 把 MIME 映射成 Qwen input_audio 的 `format`,不认识就退回子类型(最后退 "wav")
// 而非拒绝:一个我们不认得的格式仍然值得一试,上游若不同意会自己说。
func qwenAudioFormat(mediaType string) string {
	switch strings.ToLower(strings.TrimSpace(mediaType)) {
	case "audio/mpeg", "audio/mp3":
		return "mp3"
	case "audio/wav", "audio/x-wav", "audio/wave":
		return "wav"
	default:
		if format := strings.TrimPrefix(strings.ToLower(strings.TrimSpace(mediaType)), "audio/"); format != "" {
			return format
		}
		return "wav"
	}
}

// ── model catalog (static; Qwen /models returns ids only) ───────────────────────

// qwenWire: the Qwen compatible-mode dialect renders text / image_url / video_url / input_audio
// parts. Which models actually read video/audio comes from the catalog modalities — this replaces
// the old qwenNativeInputCaps patch function.
//
// qwenWire:Qwen 兼容模式方言渲 text / image_url / video_url / input_audio;哪些模型真读
// video/audio 由目录模态决定——取代旧 qwenNativeInputCaps 补丁函数。
var qwenWire = partMask{image: true, video: true, audio: true}

// DescribeModels parses Qwen's id-only /models body against the followed catalog.
//
// DescribeModels 解析 Qwen 仅含 id 的 /models 返回,查 follow 目录。
func describeQwen(raw string) ([]ModelInfo, error) {
	return describeFromSpecs(catalogSpecs("qwen", qwenKnobs), raw, qwenWire), nil
}
