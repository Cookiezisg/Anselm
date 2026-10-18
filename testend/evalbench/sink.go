package evalbench

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"time"
)

// SinkCall is one request the workflow sent to the outside world. SinkCall 是 workflow 发往外界的一次请求。
type SinkCall struct {
	Seq    int               `json:"seq"`
	Method string            `json:"method"`
	Path   string            `json:"path"`
	Body   string            `json:"body"`
	Header map[string]string `json:"header,omitempty"`
	At     time.Time         `json:"at"`
	// Faulted marks a request the armed fault answered: it reached the sink but was not delivered,
	// so a retry after it is one delivery, not two. Faulted 标记被故障应答的请求：到达 sink 但未送达，
	// 故其后的重试只算一次送达。
	Faulted bool `json:"faulted,omitempty"`
}

// Sink is the loopback side-effect target. It records every call (the ledger is the verdict) and
// can be armed with one fault that applies to the NEXT matching request only, so "retry" is a
// valid repair and "stop calling" is not. Functions run in the sandbox with direct network, so a
// loopback httptest server is reachable without any proxy configuration.
//
// Sink 是回环副作用目标。它记录每次调用（台账即裁决），并可装载一个只作用于**下一次**匹配请求的故障，
// 使"重试"是合法修复而"不再调用"不是。沙箱里的函数直连网络，回环 httptest server 无需代理即可达。
type Sink struct {
	srv    *httptest.Server
	mu     sync.Mutex
	calls  []SinkCall
	armed  *Fault
	served bool
}

// NewSink starts the sink; Close it with the test. NewSink 启动 sink；随测试 Close。
func NewSink() *Sink {
	s := &Sink{}
	s.srv = httptest.NewServer(http.HandlerFunc(s.handle))
	return s
}

func (s *Sink) URL() string { return s.srv.URL }
func (s *Sink) Close()      { s.srv.Close() }

// Arm installs a sink-kind fault for the next request. Arm 为下一次请求装载 sink 类故障。
func (s *Sink) Arm(f *Fault) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.armed, s.served = f, false
}

// Reset clears the ledger and any armed fault. Reset 清空台账与已装载故障。
func (s *Sink) Reset() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.calls, s.armed, s.served = nil, nil, false
}

// Ledger returns a copy of the calls received so far. Ledger 返回至今收到的调用副本。
func (s *Sink) Ledger() []SinkCall {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]SinkCall, len(s.calls))
	copy(out, s.calls)
	return out
}

func (s *Sink) handle(w http.ResponseWriter, r *http.Request) {
	body, _ := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	hdr := map[string]string{}
	for _, k := range []string{"Authorization", "X-Eb-Schema", "Content-Type"} {
		if v := r.Header.Get(k); v != "" {
			hdr[k] = v
		}
	}
	s.mu.Lock()
	fault := s.armed
	fire := fault != nil && fault.Sink != nil && !s.served
	if fire {
		// A header-gated fault clears as soon as the request carries the required header: that IS
		// the repair the catalog asks for. 带 header 门的故障在请求携带所需 header 时即解除：那正是目录要求的修复。
		if fault.Sink.RequireHeader != "" {
			name, want, _ := strings.Cut(fault.Sink.RequireHeader, ":")
			if strings.TrimSpace(r.Header.Get(strings.TrimSpace(name))) == strings.TrimSpace(want) {
				fire = false
			}
		}
	}
	// Transient faults (502, timeout) fire once so a plain retry repairs them; header-gated faults
	// (401, schema) keep firing until the request adapts, so only a real code change repairs them.
	// 瞬时故障（502、超时）只打一次，纯重试即可修复；header 门故障（401、schema）持续打到请求适配为止，
	// 只有真正改代码才算修复。
	if fire && fault.Sink.RequireHeader == "" {
		s.served = true
	}
	s.calls = append(s.calls, SinkCall{Seq: len(s.calls) + 1, Method: r.Method, Path: r.URL.Path, Body: string(body), Header: hdr, At: time.Now(), Faulted: fire})
	s.mu.Unlock()

	if fire {
		if fault.Sink.StallMS > 0 {
			time.Sleep(time.Duration(fault.Sink.StallMS) * time.Millisecond)
		}
		if fault.Sink.Status != 0 {
			w.WriteHeader(fault.Sink.Status)
		}
		if fault.Sink.Body != "" {
			_, _ = io.WriteString(w, fault.Sink.Body)
		}
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_, _ = io.WriteString(w, `{"ok":true}`)
}
