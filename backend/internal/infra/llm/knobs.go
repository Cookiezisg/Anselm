package llm

// The knob spellings: for each dialect, what the thinking controls the CATALOG describes are called
// on that dialect's wire. This file is what is left of five hand-written per-model-prefix tables
// (H12-c) — the tables listed WHICH models had knobs and had to be revised whenever a vendor
// shipped one; these say only how a control is spelled, which changes when a vendor changes its
// API, not when it changes its lineup.
//
// 旋钮拼法:对每条方言,**目录所描述的**那些思考控件在这条线缆上叫什么。本文件是五张手写「逐模型前缀」
// 表剩下的东西(H12-c)——那些表列的是**哪些模型有旋钮**、厂商每发一个模型就要改一次;这里只说一个控件
// **怎么拼**,而它变化的时机是厂商改 API、不是厂商改产品线。

// compatKnobs is the floor of the OpenAI-compatible dialect, used by every catalog provider this
// build has no hand-written spec for (~160 of them).
//
// `reasoning_effort` is not a guess about any particular vendor — it is the parameter name in the
// OpenAI-compatible protocol itself, which is what those providers declare they speak. The toggle
// and the budget have NO standard name in that protocol, so they are left unspelled and simply do
// not render: a model may well have them, and we would be inventing the word for it.
//
// compatKnobs 是 OpenAI 兼容方言的地板,供本构建没有手写 spec 的每一家目录 provider 使用(约 160 家)。
//
// `reasoning_effort` 不是对**某一家**的猜测——它是 OpenAI 兼容**协议本身**的参数名,而那正是这些
// provider 声明自己讲的东西。开关与预算在那个协议里**没有**标准名字,故留空、不渲染:模型很可能确实
// 有它们,而我们只是**不知道该用哪个词**去说。
var compatKnobs = knobSpelling{effort: "reasoning_effort"}

// openaiKnobs: effort comes from the catalog; `verbosity` is not a thinking control, so it rides
// along only where an effort control exists — see knobSpelling.withEffort for why that condition is
// the honest one.
// openaiKnobs:effort 来自目录;`verbosity` 不是思考控件,故它只在**有 effort 控件的地方**随行
// ——为什么这个条件是诚实的那一个,见 knobSpelling.withEffort。
var openaiKnobs = knobSpelling{
	effort:     "reasoning_effort",
	withEffort: []Knob{enumKnob("verbosity", "Verbosity", []string{"low", "medium", "high"}, "medium")},
}

// deepseekKnobs: an enum-valued toggle (`enabled`/`disabled`), plus effort.
// deepseekKnobs:枚举值的开关(`enabled`/`disabled`)加 effort。
var deepseekKnobs = knobSpelling{
	effort:     "reasoning_effort",
	toggle:     "thinking",
	toggleVals: []string{"enabled", "disabled"},
	toggleDef:  "enabled",
}

// qwenKnobs: a real boolean toggle and a token budget — the one family with all three shapes.
// qwenKnobs:真布尔开关 + token 预算——三种形状齐全的那一家。
var qwenKnobs = knobSpelling{
	toggle:    "enable_thinking",
	toggleDef: "false",
	budget:    "thinking_budget",
}

var zhipuKnobs = knobSpelling{
	toggle:     "thinking",
	toggleVals: []string{"enabled", "disabled"},
	toggleDef:  "enabled",
}

var moonshotKnobs = knobSpelling{
	toggle:     "thinking",
	toggleVals: []string{"enabled", "disabled"},
	toggleDef:  "enabled",
}
