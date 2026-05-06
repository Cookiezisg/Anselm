// trace.go — TraceRecorder + recording Client wrapper. When enabled
// (via Factory.SetTracer in --dev mode) every Stream call gets
// captured: full Request payload + every StreamEvent emitted +
// final assembled text + elapsed time + final error if any. Stored
// in a per-conversation ring buffer (last N traces) so testend's
// Wire tab can replay 'what did the LLM see and emit on each turn'.
//
// Per-conversation ring rather than one global flat list because
// (a) testers debug one conversation at a time + (b) lets us cap
// memory bounded by N × M conversations rather than N × turns ever.
//
// trace.go ——TraceRecorder + 包 Client 的 wrapper。启用（--dev 时
// Factory.SetTracer）后每次 Stream 调用全捕获：完整 Request 载荷 +
// 发出的每个 StreamEvent + 最终拼装文字 + 耗时 + 最终 error。存到
// per-conversation 环形 buffer（最近 N 个 traces）让 testend Wire
// tab 能 replay "LLM 每个 turn 看到啥发出啥"。
//
// per-conversation ring 而非全局 flat list 因为 (a) 测试一次只 debug
// 一个对话 + (b) 让内存上限按 N × M 对话而非 N × 永不停的 turn 数。
package llm

import (
	"context"
	"iter"
	"strings"
	"sync"
	"time"

	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// defaultMaxTracesPerConv caps how many recent LLM turns we keep
// per conversation. 10 covers the typical "debug recent issue"
// flow without unbounded memory growth across long conversations.
//
// defaultMaxTracesPerConv 限定 per-conversation 保留的最近 LLM turn
// 数。10 覆盖典型 "debug 最近问题" 流，不让长对话无限增长内存。
const defaultMaxTracesPerConv = 10

// Trace is one captured Stream() call: what the chat runner sent +
// what the provider streamed back + post-stream summary.
//
// Trace 是一次捕获的 Stream() 调用：chat runner 发了啥 + provider 流
// 回啥 + stream 后的汇总。
type Trace struct {
	Timestamp      time.Time     `json:"timestamp"`
	ConversationID string        `json:"conversationId,omitempty"`
	Request        Request       `json:"request"`
	Events         []StreamEvent `json:"events"`
	ElapsedMs      int64         `json:"elapsedMs"`

	// FinalText is the concatenation of all EventText deltas — the
	// reader-friendly version of "what the LLM said". EventReasoning
	// + tool calls excluded; full reconstruction comes from Events.
	//
	// FinalText 是所有 EventText delta 的拼接——"LLM 说了啥" 的可读版。
	// EventReasoning + tool call 不含；完整重建走 Events。
	FinalText string `json:"finalText,omitempty"`

	// Error is the last EventError's message, if any.
	//
	// Error 是最后一个 EventError 的消息（如有）。
	Error string `json:"error,omitempty"`
}

// TraceRecorder holds per-conversation trace rings. Concurrency-safe.
//
// TraceRecorder 持 per-conversation trace rings。并发安全。
type TraceRecorder struct {
	mu     sync.Mutex
	traces map[string][]Trace // convID → ring (newest at end)
	maxPer int
}

// NewTraceRecorder returns a recorder with the default cap of 10
// traces per conversation.
//
// NewTraceRecorder 返每对话上限 10 traces 的 recorder。
func NewTraceRecorder() *TraceRecorder {
	return &TraceRecorder{
		traces: map[string][]Trace{},
		maxPer: defaultMaxTracesPerConv,
	}
}

// Record appends a trace to the conversation's ring; oldest is dropped
// when capacity is hit. Empty conversation ID falls into the "no-conv"
// bucket so traces still capture (e.g. autoTitle calls that don't
// thread a conversation ID).
//
// Record 把 trace 加到对话 ring；满 cap 时丢最早。空 conversation ID
// 落入 "no-conv" 桶让 trace 仍捕获（如不带 conv ID 的 autoTitle 调用）。
func (r *TraceRecorder) Record(t Trace) {
	r.mu.Lock()
	defer r.mu.Unlock()
	key := t.ConversationID
	if key == "" {
		key = "(no-conversation)"
	}
	ring := r.traces[key]
	ring = append(ring, t)
	if len(ring) > r.maxPer {
		ring = ring[len(ring)-r.maxPer:]
	}
	r.traces[key] = ring
}

// TracesFor returns a copy of the recorded traces for one conversation,
// oldest-first. Empty slice when nothing recorded yet.
//
// TracesFor 返某对话的 trace 副本，最早在前。无记录时返空 slice。
func (r *TraceRecorder) TracesFor(conversationID string) []Trace {
	r.mu.Lock()
	defer r.mu.Unlock()
	ring := r.traces[conversationID]
	out := make([]Trace, len(ring))
	copy(out, ring)
	return out
}

// Conversations returns all conversation IDs that have at least one
// recorded trace. Used by the Wire tab dropdown when no specific
// conversation is selected — falls back to "show me what conversations
// have traces".
//
// Conversations 返所有至少一条 trace 的 conversation ID。Wire tab
// 在没选具体对话时走 dropdown——回退到"哪些对话有 trace"。
func (r *TraceRecorder) Conversations() []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]string, 0, len(r.traces))
	for k := range r.traces {
		out = append(out, k)
	}
	return out
}

// Clear drops all traces for one conversation. Returns count dropped.
//
// Clear 丢某对话的全部 trace。返丢的数。
func (r *TraceRecorder) Clear(conversationID string) int {
	r.mu.Lock()
	defer r.mu.Unlock()
	n := len(r.traces[conversationID])
	delete(r.traces, conversationID)
	return n
}

// recordingClient wraps an inner Client. Stream extracts conversationID
// from ctx, captures the request snapshot + every event yielded, then
// calls Recorder.Record after the iterator is consumed.
//
// recordingClient 包内部 Client。Stream 从 ctx 提 conversationID,
// 捕获 request 快照 + yield 的每个 event,迭代器消费完调
// Recorder.Record。
type recordingClient struct {
	inner    Client
	recorder *TraceRecorder
}

func (c *recordingClient) Stream(ctx context.Context, req Request) iter.Seq[StreamEvent] {
	convID, _ := reqctxpkg.GetConversationID(ctx)
	start := time.Now()
	innerSeq := c.inner.Stream(ctx, req)

	return func(yield func(StreamEvent) bool) {
		var (
			events    []StreamEvent
			finalText strings.Builder
			finalErr  string
		)
		// Tee the iterator: forward every event upstream, also append
		// to the trace buffer. yield's bool result tells us when the
		// consumer wants to stop early — we mirror that to inner.
		// Tee 迭代器：每个 event 转发上游 + 加 trace buffer。yield 的
		// bool 告诉我们消费方是否提前停——我们镜像到 inner。
		stopped := false
		for ev := range innerSeq {
			events = append(events, ev)
			if ev.Type == EventText {
				finalText.WriteString(ev.Delta)
			}
			if ev.Type == EventError && ev.Err != nil {
				finalErr = ev.Err.Error()
			}
			if !stopped {
				if !yield(ev) {
					stopped = true
				}
			}
		}
		c.recorder.Record(Trace{
			Timestamp:      start,
			ConversationID: convID,
			Request:        req,
			Events:         events,
			ElapsedMs:      time.Since(start).Milliseconds(),
			FinalText:      finalText.String(),
			Error:          finalErr,
		})
	}
}
