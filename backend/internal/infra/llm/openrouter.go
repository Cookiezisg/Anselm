package llm

import (
	"encoding/json"
	"slices"
)

// newOpenRouterProvider is the OpenRouter family's [compatSpec]. Its own: reasoning is a nested
// `reasoning:{effort}` object rather than a flat field, and its stream spells the thinking field
// `reasoning` while the CN-family models it proxies spell it `reasoning_content` — the shared delta
// reads both, so an aggregator that passes an upstream's spelling through cannot lose the trace.
//
// newOpenRouterProvider 是 OpenRouter 家的 [compatSpec]。它自己的东西:推理是一个**嵌套**的
// `reasoning:{effort}` 对象而非平字段;而它的流把思考字段拼成 `reasoning`、它代理的 CN 家族模型却拼成
// `reasoning_content`——共享的 delta **两个都读**,故一个把上游拼法直通出来的聚合器丢不掉那条思维链。
func newOpenRouterProvider() *compatProvider {
	return &compatProvider{spec: compatSpec{
		name:    "openrouter",
		baseURL: func() string { return "https://openrouter.ai/api/v1" },
		wire:    openrouterWire,
		encode: func(req Request, body *compatRequest) {
			if req.MaxTokens > 0 {
				body.MaxTokens = req.MaxTokens
			}
			if v := req.Options["reasoning_effort"]; v != "" {
				body.Reasoning = &compatReasoning{Effort: v}
			}
		},
		describe: describeOpenrouter,
	}}
}

// openrouterWire: text + image_url. 文本 + 图。
var openrouterWire = partMask{image: true}

// ── model catalog (dynamic; OpenRouter /models is the richest in the industry) ──

// DescribeModels parses OpenRouter's GET /api/v1/models body. As an aggregator of hundreds of
// upstream models it cannot use a static catalog: each entry carries its own context_length,
// top_provider.max_completion_tokens, and supported_parameters, so the whole catalog is derived
// from the live payload rather than a hand-maintained spec table.
//
// DescribeModels 解析 OpenRouter 的 GET /api/v1/models。它聚合上百上游模型，无法用静态目录：
// 每条自带 context_length、top_provider.max_completion_tokens、supported_parameters，故整份目录
// 由实时载荷推导，而非手维护的 spec 表。
func describeOpenrouter(raw string) ([]ModelInfo, error) {
	var resp struct {
		Data []struct {
			ID            string `json:"id"`
			Name          string `json:"name"`
			ContextLength int    `json:"context_length"`
			TopProvider   struct {
				MaxCompletionTokens int `json:"max_completion_tokens"`
			} `json:"top_provider"`
			SupportedParameters []string `json:"supported_parameters"`
		} `json:"data"`
	}
	if err := json.Unmarshal([]byte(raw), &resp); err != nil {
		return nil, nil
	}
	out := make([]ModelInfo, 0, len(resp.Data))
	for _, m := range resp.Data {
		if m.ID == "" {
			continue
		}
		mi := ModelInfo{
			ID:            m.ID,
			DisplayName:   m.Name,
			ContextWindow: m.ContextLength,
			MaxOutput:     m.TopProvider.MaxCompletionTokens,
		}
		// OpenRouter publishes per-model knob support; surface reasoning effort when offered.
		// OpenRouter 公布每模型旋钮支持；该模型支持时暴露 reasoning effort 旋钮。
		if slices.Contains(m.SupportedParameters, "reasoning") {
			mi.Knobs = []Knob{enumKnob("reasoning_effort", "Reasoning effort",
				[]string{"minimal", "low", "medium", "high", "xhigh"}, "medium")}
		}
		out = append(out, mi)
	}
	return out, nil
}
