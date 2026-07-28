package llm

import "testing"

// The knob surface is now「目录说有什么控件 × 方言说它叫什么」(H12-c). These assert both halves and,
// just as importantly, the silence in between: a control the catalog declares but the dialect has no
// word for must not be rendered, because a parameter name we invented buys a 400 that reads as
// 「这个模型坏了」.
//
// 旋钮面现在是「目录说有什么控件 × 方言说它叫什么」(H12-c)。这里断言两半,以及同样要紧的**中间那段
// 沉默**:目录声明了、而方言没有词去说的控件**不得渲染**——一个我们发明的参数名换来的是一个读起来
// 像「这个模型坏了」的 400。
func knobKeys(t *testing.T, provider, id string) map[string]Knob {
	t.Helper()
	ms, err := DescribeModels(provider, `{"data":[{"id":"`+id+`"}]}`)
	if err != nil {
		t.Fatalf("%s/%s: %v", provider, id, err)
	}
	if len(ms) == 0 {
		t.Fatalf("%s/%s: not in the catalog", provider, id)
	}
	out := map[string]Knob{}
	for _, k := range ms[0].Knobs {
		out[k.Key] = k
	}
	return out
}

// TestKnobs_PerModelNotPerPrefix is the defect the hand-written tables carried: they matched by
// model-id PREFIX, so `{"deepseek", …}` handed `thinking` + `reasoning_effort` to EVERY deepseek id
// — including `deepseek-chat`, which the catalog says is not a reasoning model at all. A dead
// control in the picker is a promise the model cannot keep.
//
// TestKnobs_PerModelNotPerPrefix 钉住手写表带着的那个缺陷:它们按 model-id **前缀**匹配,故
// `{"deepseek", …}` 把 `thinking` + `reasoning_effort` 发给**每一个** deepseek id——包括
// `deepseek-chat`,而目录说它**根本不是**推理模型。选择器里一个死掉的控件,是模型兑现不了的承诺。
func TestKnobs_PerModelNotPerPrefix(t *testing.T) {
	if got := knobKeys(t, "deepseek", "deepseek-chat"); len(got) != 0 {
		t.Errorf("deepseek-chat is not a reasoning model; want no knobs, got %v", got)
	}
	got := knobKeys(t, "deepseek", "deepseek-v4-flash")
	if k, ok := got["thinking"]; !ok || k.Type != "enum" || k.Default != "enabled" {
		t.Errorf("deepseek-v4-flash thinking = %+v, want the family's enabled/disabled enum", k)
	}
	if k, ok := got["reasoning_effort"]; !ok || len(k.Values) != 2 || k.Values[0] != "high" {
		t.Errorf("deepseek-v4-flash effort = %+v, want the catalog's own [high max]", k)
	}
}

// TestKnobs_SpellingIsPerDialect: the same catalog control renders under a different wire key per
// family, which is the half no catalog states and the only half we still maintain.
//
// TestKnobs_SpellingIsPerDialect:同一个目录控件在每一家渲成**不同的**线缆 key——那是任何目录都不
// 声明的那一半,也是我们唯一还维护的那一半。
func TestKnobs_SpellingIsPerDialect(t *testing.T) {
	if k, ok := knobKeys(t, "qwen", "qwen3.7-plus")["enable_thinking"]; !ok || k.Type != "bool" {
		t.Errorf("qwen spells its toggle `enable_thinking` as a real bool, got %+v", k)
	}
	if _, ok := knobKeys(t, "qwen", "qwen3.7-plus")["thinking_budget"]; !ok {
		t.Error("qwen declares a budget_tokens control in the catalog and spells it thinking_budget")
	}
	if k, ok := knobKeys(t, "zhipu", "glm-4.6")["thinking"]; !ok || k.Type != "enum" {
		t.Errorf("zhipu spells the same control `thinking` as an enum, got %+v", k)
	}
}

// TestKnobs_LongTailGetsTheProtocolsOwnName is what H12-c bought: a provider nobody hand-wrote a
// table for still gets its reasoning control, because `reasoning_effort` is the parameter name in
// the OpenAI-compatible protocol these providers declare they speak — not a guess about any one
// vendor. The toggle and the budget have no standard name there, so they stay unspelled.
//
// TestKnobs_LongTailGetsTheProtocolsOwnName 是 H12-c 换来的东西:一家没人为它手写过表的 provider
// 照样拿到它的推理控件,因为 `reasoning_effort` 是这些 provider **自己声明会讲**的那个 OpenAI 兼容
// **协议本身**的参数名——不是对某一家的猜测。开关与预算在那里没有标准名,故留空不拼。
func TestKnobs_LongTailGetsTheProtocolsOwnName(t *testing.T) {
	got := knobKeys(t, "groq", "openai/gpt-oss-120b")
	k, ok := got["reasoning_effort"]
	if !ok || k.Type != "enum" || len(k.Values) == 0 {
		t.Fatalf("a long-tail provider must still get the protocol's own effort knob, got %v", got)
	}
	if len(got) != 1 {
		t.Errorf("nothing beyond the protocol's own name may be invented for it, got %v", got)
	}
}

// TestKnobs_UnspelledControlStaysSilent: qwen has no `effort` spelling, so a catalog-declared effort
// control on one of its models renders NOTHING rather than a made-up key.
//
// TestKnobs_UnspelledControlStaysSilent:qwen 没有 `effort` 拼法,故它某个模型上目录声明的 effort
// 控件**什么都不渲**、而不是渲一个编出来的 key。
func TestKnobs_UnspelledControlStaysSilent(t *testing.T) {
	spelled := qwenKnobs.knobsFor("m", []CatalogReasoning{{Type: "effort", Values: []string{"low", "high"}}})
	if len(spelled) != 0 {
		t.Errorf("qwen has no word for an effort control; want silence, got %+v", spelled)
	}
}
