package llm

import "strings"

// toolArgs normalizes the two shapes an OpenAI-compatible stream serves tool-call arguments in.
//
// **Both shapes are real, and one vendor serves both.** DashScope's legacy shared Singapore host
// (`dashscope-intl.aliyuncs.com`) streams true increments — `{"aspect": "`, then `square`, then
// `"`. Its workspace-specific host (`<ws>.ap-southeast-1.maas.aliyuncs.com` — the one the vendor's
// own migration notice tells you to move to) streams the CUMULATIVE value in every chunk —
// `{"aspect": "`, then `{"aspect": "square`, then `{"aspect": "square"`. Same model, same request,
// same API shape, one wire convention apart (真线缆抓取实证 2026-07-28).
//
// Concatenating a cumulative stream produces `{"aspect": "{"aspect": "square…`, which fails JSON
// parsing on EVERY tool call. The damage is total rather than partial: the agent loop sees every
// call fail, three turns in a row, and aborts with a tool-error storm. A capability does not
// degrade here — it dies, and it dies the moment someone follows the vendor's migration advice.
//
// This lives in one place because all seven OpenAI-compatible dialects had copied the same
// `ArgsDelta: tc.Function.Arguments` line. Fixing the one dialect with a reproduction would have
// left six loaded guns, each pointed at whichever vendor changes convention next.
//
// toolArgs 把 OpenAI 兼容流式里工具调用参数的两种形状归一。
//
// **两种形状都是真的,而且同一家供应商两种都发。** DashScope 的旧共用新加坡域名发**真增量**——
// `{"aspect": "`、`square`、`"`;它的**工作区专属**域名(厂商自己的迁移公告让你搬过去的那个)每一片
// 都发**完整累积值**——`{"aspect": "`、`{"aspect": "square`、`{"aspect": "square"`。同一个模型、同一个
// 请求、同一套 API 形状,只差一个线缆约定(真线缆抓取实证 2026-07-28)。
//
// 把累积流拼起来会得到 `{"aspect": "{"aspect": "square…`,于是**每一次**工具调用都 JSON 解析失败。
// 损害是**全量**而非局部:agent 循环看到每一次调用都失败、连续三轮,以 tool-error storm 中止。能力在
// 这里不是降级——是**死掉**,而且是在有人听从供应商迁移建议的那一刻死掉。
//
// 它住在一个地方,因为七个 OpenAI 兼容方言各抄了同一行 `ArgsDelta: tc.Function.Arguments`。只修那个
// 有复现的方言,等于留下六把上了膛的枪,每一把都对着下一个改约定的供应商。
// deltaAccumulator is the shared prefix-extension normalizer used by tool arguments and the small
// set of providers/models that stream text cumulatively.
// deltaAccumulator 是工具参数与少数以累计方式发文本的 provider/model 共用的前缀延伸归一器。
type deltaAccumulator struct {
	seen map[int]string
}

type toolArgs = deltaAccumulator

func newDeltaAccumulator() *deltaAccumulator { return &deltaAccumulator{seen: map[int]string{}} }
func newToolArgs() *toolArgs                 { return newDeltaAccumulator() }

// delta returns the NEW suffix one wire chunk contributes, or "" when it contributes nothing.
//
// The prefix test is the discriminator, and it is safe in both directions: for well-formed JSON a
// genuine increment can never re-state everything already accumulated — that would build
// `{"a{"a…`, which no parser accepts — so reading a prefix-extending chunk as cumulative cannot
// corrupt a true increment stream.
//
// delta 返回一个线缆分片贡献的**新增后缀**,没有贡献时返回 ""。
//
// 前缀判别就是那个分辨器,且两个方向都安全:对合法 JSON 而言,一个真增量**不可能**把已累积的一切重述
// 一遍——那会拼出 `{"a{"a…`,没有任何解析器收——故把「延长前缀」的分片读作累积,不会破坏一条真增量流。
func (t *deltaAccumulator) delta(idx int, chunk string) string {
	if t == nil || chunk == "" {
		return ""
	}
	prev := t.seen[idx]
	if prev != "" && strings.HasPrefix(chunk, prev) {
		t.seen[idx] = chunk
		return chunk[len(prev):]
	}
	t.seen[idx] = prev + chunk
	return chunk
}
