package llm

import "testing"

// These tests exist because a green suite and a green real-money acceptance BOTH passed while this
// was broken. Every fixture in the repo streams true increments, because that is what the endpoint
// we happened to be pointed at streams. The bug appears only when you follow the vendor's own
// migration notice — and then it is total, not partial.
//
// 这些测试存在,是因为门禁全绿**和**真钱验收全绿的时候,这里是坏的。仓库里每一份 fixture 都发真增量,
// 因为我们碰巧指着的那个端点就发真增量。这个 bug **只在你听从供应商自己的迁移公告时**才出现——而那时
// 它是全量的、不是局部的。

// TestToolArgs_IncrementalWireIsPassedThrough: the shape every existing fixture uses. Each chunk is
// new text and must reach the caller unchanged.
//
// TestToolArgs_IncrementalWireIsPassedThrough:仓库里每一份 fixture 用的那个形状。每一片都是新文本,
// 必须原样抵达调用方。
func TestToolArgs_IncrementalWireIsPassedThrough(t *testing.T) {
	a := newToolArgs()
	var got string
	for _, chunk := range []string{`{"aspect": "`, `square`, `"`, `, "prompt": "塔"}`} {
		got += a.delta(0, chunk)
	}
	if want := `{"aspect": "square", "prompt": "塔"}`; got != want {
		t.Fatalf("got %q, want %q", got, want)
	}
}

// TestToolArgs_CumulativeWireIsDeduplicated: the shape DashScope's workspace-specific host streams.
// Concatenating these verbatim yields `{"aspect": "{"aspect": "square…`, which fails JSON parsing on
// every single tool call.
//
// TestToolArgs_CumulativeWireIsDeduplicated:DashScope 工作区专属域名发的那个形状。原样拼接会得到
// `{"aspect": "{"aspect": "square…`,于是**每一次**工具调用都 JSON 解析失败。
func TestToolArgs_CumulativeWireIsDeduplicated(t *testing.T) {
	a := newToolArgs()
	var got string
	for _, chunk := range []string{
		`{"aspect": "`,
		`{"aspect": "square`,
		`{"aspect": "square`, // a repeat contributes nothing / 重复片贡献为空
		`{"aspect": "square"`,
		`{"aspect": "square", "prompt": "塔"}`,
	} {
		got += a.delta(0, chunk)
	}
	if want := `{"aspect": "square", "prompt": "塔"}`; got != want {
		t.Fatalf("got %q, want %q", got, want)
	}
}

// TestToolArgs_ParallelCallsDoNotBleed: two tool calls stream interleaved under different indices,
// and one's accumulated prefix must never be subtracted from the other's chunk.
//
// TestToolArgs_ParallelCallsDoNotBleed:两次工具调用在不同下标上交错流出,一方累积的前缀绝不能被从
// 另一方的分片里减掉。
func TestToolArgs_ParallelCallsDoNotBleed(t *testing.T) {
	a := newToolArgs()
	var zero, one string
	zero += a.delta(0, `{"a": `)
	one += a.delta(1, `{"a": `)
	zero += a.delta(0, `{"a": 1}`)
	one += a.delta(1, `2}`)
	if zero != `{"a": 1}` {
		t.Fatalf("index 0 = %q", zero)
	}
	if one != `{"a": 2}` {
		t.Fatalf("index 1 = %q", one)
	}
}

// TestToolArgs_EmptyChunksContributeNothing: both wires emit empty argument chunks alongside the
// tool id/name frames; they must not be forwarded as deltas.
//
// TestToolArgs_EmptyChunksContributeNothing:两种线缆都会在 id/name 帧旁边发空的参数片;它们绝不该
// 作为 delta 被转发。
func TestToolArgs_EmptyChunksContributeNothing(t *testing.T) {
	a := newToolArgs()
	if d := a.delta(0, ""); d != "" {
		t.Fatalf("empty chunk produced %q", d)
	}
	if d := a.delta(0, `{"a":1}`); d != `{"a":1}` {
		t.Fatalf("first real chunk = %q", d)
	}
	if d := a.delta(0, ""); d != "" {
		t.Fatalf("trailing empty chunk produced %q", d)
	}
}

// TestToolArgs_NilIsInert: a state built before this field existed must not panic — the seven
// dialects construct their state in seven places.
//
// TestToolArgs_NilIsInert:在这个字段存在之前构造的 state 不得 panic——七个方言在七处各自构造。
func TestToolArgs_NilIsInert(t *testing.T) {
	var a *toolArgs
	if d := a.delta(0, `{"a":1}`); d != "" {
		t.Fatalf("nil accumulator returned %q", d)
	}
}
