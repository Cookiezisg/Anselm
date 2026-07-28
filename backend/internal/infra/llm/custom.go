package llm

// newCustomProvider is the escape hatch: any OpenAI-compatible endpoint the user points us at, with
// NO knobs and NO catalog. It sends the floor of the dialect and nothing else, because for an
// endpoint we have never seen, every extra field is a guess that can only cost a 400.
//
// newCustomProvider 是逃生口:用户指给我们的**任意** OpenAI 兼容端点,**没有旋钮、没有目录**。它只发
// 本方言的地板、别的什么都不发——因为对一个我们从没见过的端点,每一个多余字段都是一次只会换来 400 的猜测。
func newCustomProvider() *compatProvider {
	return &compatProvider{spec: compatSpec{
		name: "custom",
		// Empty: the caller must supply base_url. 为空:caller 必须自带 base_url。
		baseURL:  func() string { return "" },
		wire:     customWire,
		describe: describeCustom,
	}}
}

// customWire: text + image_url — the floor. 地板:文本 + 图。
var customWire = partMask{image: true}

// describeCustom best-effort parses an OpenAI-compat /models id list from a custom endpoint. A
// generic endpoint has no static catalog, so models carry no knobs or window specs — the user can
// still target a model id directly.
//
// describeCustom 尽力解析自定义端点的 OpenAI-compat /models id 列表。通用端点无静态目录,故模型不带
// 旋钮或窗口规格——用户仍可直接用某 model id。
func describeCustom(raw string) ([]ModelInfo, error) {
	ids := decodeOpenAICompatModelIDs(raw)
	out := make([]ModelInfo, 0, len(ids))
	for _, id := range ids {
		out = append(out, ModelInfo{ID: id, DisplayName: id})
	}
	return out, nil
}
