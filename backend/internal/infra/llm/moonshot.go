package llm

// newMoonshotProvider is the Moonshot (Kimi) family's [compatSpec]. Its own: `max_completion_tokens`
// (the legacy max_tokens is deprecated there) and a thinking:{type} toggle.
//
// newMoonshotProvider 是 Moonshot(Kimi)家的 [compatSpec]。它自己的东西:`max_completion_tokens`
// (那边旧的 max_tokens 已弃用)与 thinking:{type} 开关。
func newMoonshotProvider() *compatProvider {
	return &compatProvider{spec: compatSpec{
		name:    "moonshot",
		baseURL: func() string { return "https://api.moonshot.cn/v1" },
		wire:    moonshotWire,
		encode: func(req Request, body *compatRequest) {
			if req.MaxTokens > 0 {
				body.MaxCompletionTokens = req.MaxTokens
			}
			if v := req.Options["thinking"]; v != "" {
				body.Thinking = &compatThinking{Type: v}
			}
		},
		describe: describeMoonshot,
	}}
}

// ── model catalog (static; Moonshot /models is richer but a static catalog suffices here) ──

func moonshotThinkingKnobs() []Knob {
	return []Knob{enumKnob("thinking", "Thinking", []string{"enabled", "disabled"}, "enabled")}
}

// moonshotWire: the Moonshot dialect renders text / image_url parts only — a catalog model
// listing video input (kimi-k2.6) still projects Video=false until the dialect carries it.
//
// moonshotWire:Moonshot 方言只渲 text / image_url——目录里列 video 输入的模型(kimi-k2.6)
// 在方言能承载之前仍投影 Video=false。
var moonshotWire = partMask{image: true}

// moonshotKnobRules: only kimi-k2.6/k2.5 expose the thinking toggle (P4).
//
// moonshotKnobRules:仅 kimi-k2.6/k2.5 有 thinking 开关(P4)。
var moonshotKnobRules = []knobRule{
	{"kimi-k2.6", moonshotThinkingKnobs()},
	{"kimi-k2.5", moonshotThinkingKnobs()},
}

// DescribeModels parses Moonshot's /models body against the followed catalog.
//
// DescribeModels 解析 Moonshot /models 返回,查 follow 目录。
func describeMoonshot(raw string) ([]ModelInfo, error) {
	return describeFromSpecs(catalogSpecs("moonshot", knobsByPrefix(moonshotKnobRules)), raw, moonshotWire), nil
}
