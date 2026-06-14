// Package router assembles the HTTP mux + middleware chain. Recorder wraps *http.ServeMux
// to record (method, path) registrations so a dev endpoint can list real routes without a
// hand-maintained manifest. (Full route assembly — registering every business handler —
// lives in bootstrap wiring, since it depends on the whole app.)
//
// Package router 装配 HTTP mux + 中间件链。Recorder 包装 *http.ServeMux 记录 (method, path)
// 注册，让 dev 端点无需手维护清单即可列出真实路由。（完整路由装配——注册所有业务 handler——
// 在 bootstrap 装配，因它依赖整个 app。）
package router

import (
	"net/http"
	"strings"
	"sync"
)

// Route is one recorded registration.
//
// Route 是一次注册记录。
type Route struct {
	Method string
	Path   string
}

// Recorder wraps a mux and intercepts HandleFunc/Handle to record entries. It satisfies the
// shape every handler's Register(mux) expects (HandleFunc + Handle), so handlers register
// against it without router importing the handlers package (which would cycle).
//
// Recorder 包装 mux，截获 HandleFunc/Handle 记录条目。它满足每个 handler 的 Register(mux) 所需
// 形状（HandleFunc + Handle），故 handler 对它注册而无需 router import handlers 包（会成环）。
type Recorder struct {
	mux    *http.ServeMux
	mu     sync.RWMutex
	routes []Route
}

// NewRecorder wraps mux so registrations are recorded in addition to forwarded.
//
// NewRecorder 包装 mux，注册时同时写入记录。
func NewRecorder(mux *http.ServeMux) *Recorder {
	return &Recorder{mux: mux, routes: make([]Route, 0, 64)}
}

// HandleFunc records (method, path) then forwards to the underlying mux. Go 1.22+ ServeMux
// syntax: "GET /path" or pure "/path" (any method).
//
// HandleFunc 记录 (method, path) 后转发底层 mux。
func (r *Recorder) HandleFunc(pattern string, h func(http.ResponseWriter, *http.Request)) {
	method, path := parsePattern(pattern)
	r.mu.Lock()
	r.routes = append(r.routes, Route{Method: method, Path: path})
	r.mu.Unlock()
	r.mux.HandleFunc(pattern, h)
}

// Handle is HandleFunc for an http.Handler.
//
// Handle 是接 http.Handler 的 HandleFunc。
func (r *Recorder) Handle(pattern string, h http.Handler) {
	method, path := parsePattern(pattern)
	r.mu.Lock()
	r.routes = append(r.routes, Route{Method: method, Path: path})
	r.mu.Unlock()
	r.mux.Handle(pattern, h)
}

// List returns a snapshot of recorded routes.
//
// List 返回记录的路由快照。
func (r *Recorder) List() []Route {
	r.mu.RLock()
	defer r.mu.RUnlock()
	out := make([]Route, len(r.routes))
	copy(out, r.routes)
	return out
}

func parsePattern(p string) (method, path string) {
	p = strings.TrimSpace(p)
	if i := strings.IndexByte(p, ' '); i > 0 {
		return p[:i], strings.TrimSpace(p[i+1:])
	}
	return "ANY", p
}

// Compile-time guard: *Recorder satisfies the registrar shape handlers register against,
// without importing the handlers package.
//
// 编译期校验：*Recorder 满足 handler 注册所需形状，且不 import handlers 包。
var _ interface {
	HandleFunc(string, func(http.ResponseWriter, *http.Request))
	Handle(string, http.Handler)
} = (*Recorder)(nil)
