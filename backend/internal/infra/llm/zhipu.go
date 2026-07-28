package llm

// newZhipuProvider is the Zhipu (BigModel) family's [compatSpec]. Its own: `tool_choice:"auto"`
// alongside a tools array — without it this family will not call a tool at all, which reads in
// production as「the model ignored my tools」rather than as a missing request field.
//
// newZhipuProvider 是智谱(BigModel)家的 [compatSpec]。它自己的东西:tools 数组旁边的
// `tool_choice:"auto"`——不给它,这一家**根本不调工具**,而那在生产上读起来像「模型无视了我的工具」、
// 不像一个缺失的请求字段。
func newZhipuProvider() *compatProvider {
	return &compatProvider{spec: compatSpec{
		name:       "zhipu",
		baseURL:    func() string { return "https://open.bigmodel.cn/api/paas/v4" },
		wire:       zhipuWire,
		toolChoice: "auto",
		encode: func(req Request, body *compatRequest) {
			if req.MaxTokens > 0 {
				body.MaxTokens = req.MaxTokens
			}
			if v := req.Options["thinking"]; v != "" {
				body.Thinking = &compatThinking{Type: v}
			}
		},
		describe: describeZhipu,
	}}
}

// ── model catalog (static; Zhipu /models returns ids only) ──────────────────────

func zhipuThinkingKnobs() []Knob {
	return []Knob{enumKnob("thinking", "Thinking", []string{"enabled", "disabled"}, "enabled")}
}

// zhipuWire: the Zhipu dialect renders text / image_url parts only.
//
// zhipuWire:智谱方言只渲 text / image_url。
var zhipuWire = partMask{image: true}

// zhipuKnobRules: GLM-4.5+ lines expose the thinking knob (P4); the same prefixes cover the
// air/flash/v variants the catalog carries.
//
// zhipuKnobRules:GLM-4.5+ 线有 thinking 旋钮(P4);同前缀覆盖目录里的 air/flash/v 变体。
var zhipuKnobRules = []knobRule{
	{"glm-5", zhipuThinkingKnobs()},
	{"glm-4.7", zhipuThinkingKnobs()},
	{"glm-4.6", zhipuThinkingKnobs()},
	{"glm-4.5", zhipuThinkingKnobs()},
}

// DescribeModels parses Zhipu's id-only /models body against the followed catalog.
//
// DescribeModels 解析智谱仅含 id 的 /models 返回,查 follow 目录。
func describeZhipu(raw string) ([]ModelInfo, error) {
	return describeFromSpecs(catalogSpecs("zhipu", knobsByPrefix(zhipuKnobRules)), raw, zhipuWire), nil
}
