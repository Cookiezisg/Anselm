// llmrecord.go — the REAL upstream, with the wire kept. A transparent recording reverse proxy that
// forwards every byte to a real provider (real money, real models, real artifacts) while capturing
// the request bodies on the way through.
//
// **It exists to make one acceptance criterion provable.** WRK-082's終点验收 §0.2 ② says the
// downstream model must REALLY SEE what upstream produced, "不采信模型自述" — do not take the model's
// word for it. Against a fake that is easy: LLMMock keeps every request. Against a real model it was
// impossible, because the only reachable evidence was the model's own reply, and a model that says
// "I see a lighthouse" is exactly what a model hallucinates when it was handed a sentence instead of
// pixels. The proxy resolves that: the money and the model are real, and the wire is still on record.
//
// It also answers the money question no artifact can. "重听走缓存零计费" is invisible in the response
// (both listens return identical bytes); it is only visible as an upstream call that never happened.
// CallsTo counts exactly that.
//
// llmrecord.go —— **真上游,但线缆留底**。一个透明的录制反向代理:每个字节原样转发给真供应商(真钱、
// 真模型、真产物),同时把途经的请求体捕获下来。
//
// **它的存在是为了让一条验收标准变得可证。** 终点验收 §0.2 ② 要求下游模型**真的看见**上游的产出,
// 且**不采信模型自述**。对假件这很容易(LLMMock 留着每个请求);对真模型此前**不可能**——唯一能拿到的
// 证据就是模型自己的回答,而一个说「我看见一座灯塔」的模型,正是**收到一句话而非像素**时会产生的幻觉。
// 代理解决了它:钱和模型都是真的,线缆仍在案。
//
// 它还回答一个产物回答不了的钱的问题。「重听走缓存零计费」在响应里**看不见**(两次重听返回一模一样的
// 字节),它只在**一次没有发生的上游调用**里可见。CallsTo 数的正是那个。
package harness

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"testing"

	"github.com/sunweilin/anselm/testend/harness/proxycore"
)

// Recorder is a recording pass-through to a real provider. Point an api-key's baseUrl at
// URL()+"/compatible-mode/v1" (or whatever prefix that provider serves) and every dialect — chat,
// images, speech, video submit/poll — flows through the same origin and lands in the same log.
//
// Recorder 是通往真供应商的录制式直通。把 api-key 的 baseUrl 指向 URL()+"/compatible-mode/v1"(或该
// 供应商的相应前缀),于是每一种方言——聊天、图、语音、视频提交/轮询——都经同一个 origin、落进同一本账。
type Recorder struct {
	dumpLog // chat requests, in the same shape LLMMock produces. 聊天请求,与 LLMMock 同形。

	srv *httptest.Server

	cmu   sync.Mutex
	calls []RecordedCall
}

// RecordedCall is one request that crossed the proxy — every path, not just chat. The generation
// dialects (images / speech / video) are not chat-shaped, so they have no PromptDump; what matters
// about them is that they HAPPENED, and how many times.
//
// RecordedCall 是一次穿过代理的请求——**所有**路径,不止聊天。生成方言(图/语音/视频)不是聊天形状,
// 故无 PromptDump;关于它们要紧的是**发生过**、以及发生了几次。
type RecordedCall struct {
	Method string
	Path   string
	Body   []byte
}

// NewRecorder starts a proxy in front of upstream (e.g. "https://dashscope-intl.aliyuncs.com").
//
// NewRecorder 在 upstream 前面启动一个代理。
func NewRecorder(t *testing.T, upstream string) *Recorder {
	t.Helper()
	u, err := url.Parse(strings.TrimRight(upstream, "/"))
	if err != nil || u.Host == "" {
		t.Fatalf("harness: bad upstream %q: %v", upstream, err)
	}
	rec := &Recorder{}

	// The transparency invariants (upstream Host rewrite, end-to-end flush forwarding) live in
	// proxycore — one place, shared with the standalone rig tap (cmd/llmtap).
	// 透明性不变量(上游 Host 重写、端到端 flush 转发)住 proxycore——只此一份,与独立台架 tap
	// (cmd/llmtap)共用。
	rec.srv = httptest.NewServer(proxycore.Handler(u, func(r *http.Request, body []byte) {
		rec.note(r.Method, r.URL.Path, body)
	}, nil))
	t.Cleanup(rec.srv.Close)
	return rec
}

func (r *Recorder) note(method, path string, body []byte) {
	r.cmu.Lock()
	r.calls = append(r.calls, RecordedCall{Method: method, Path: path, Body: body})
	r.cmu.Unlock()
	if strings.HasSuffix(path, "/chat/completions") {
		r.add(parsePromptDump(body))
	}
}

// URL is the proxy origin. Compose the provider's own prefix onto it for an api-key baseUrl.
//
// URL 是代理的 origin。给 api-key 的 baseUrl 时,在它后面拼上该供应商自己的前缀。
func (r *Recorder) URL() string { return r.srv.URL }

// Calls returns every request that crossed the proxy, in order.
//
// Calls 按顺序返回穿过代理的每一个请求。
func (r *Recorder) Calls() []RecordedCall {
	r.cmu.Lock()
	defer r.cmu.Unlock()
	out := make([]RecordedCall, len(r.calls))
	copy(out, r.calls)
	return out
}

// CallsTo counts requests whose path contains the fragment — the spend counter. A cache that
// silently pays twice satisfies every assertion about the artifact and fails only this one.
//
// CallsTo 数路径含该片段的请求——**花钱计数器**。一个悄悄付了两次钱的缓存,能满足关于产物的每一条断言,
// 只会在这一条上失败。
func (r *Recorder) CallsTo(fragment string) int {
	n := 0
	for _, c := range r.Calls() {
		if strings.Contains(c.Path, fragment) {
			n++
		}
	}
	return n
}
