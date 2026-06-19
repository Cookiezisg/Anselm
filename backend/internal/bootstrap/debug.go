package bootstrap

import (
	"encoding/json"
	"net/http"
	"net/http/pprof"
	"runtime"

	"go.uber.org/zap"
)

// registerDebug mounts dev-only observability endpoints on the shared mux: Go's pprof profiles at
// /debug/pprof (goroutine / heap / allocs / cpu / trace …) and a /debug/stats JSON snapshot. These
// are the first-line tools for the systems-level defects this backend is prone to — a goroutine leak
// shows as an ever-rising goroutine count (and `goroutine?debug=2` names the stuck stacks), a memory
// leak as an ever-rising heap, runaway CPU in the cpu profile. Gated on dev: pprof is an info-leak /
// DoS surface a shipped desktop sidecar must not expose. Debug paths are non-/api/v1 so they bypass
// the workspace-require middleware automatically (router.Chain exempts them).
//
// registerDebug 仅 dev 挂可观测性端点：Go pprof（goroutine/heap/allocs/cpu/trace…）+ /debug/stats JSON
// 快照。抓本后端易犯系统级缺陷的第一手工具——goroutine 泄漏=数只涨（`goroutine?debug=2` 列卡住的栈）、内存
// 泄漏=堆只涨、CPU 失控看 cpu profile。dev 门控：pprof 是信息泄露/DoS 面，出货 sidecar 不该暴露。
func registerDebug(mux *http.ServeMux, dev bool, log *zap.Logger) {
	if !dev {
		return
	}
	// Specific pprof endpoints win over the /debug/pprof/ subtree (ServeMux longest-pattern wins);
	// the subtree's pprof.Index serves the named runtime profiles (goroutine/heap/allocs/block/…).
	mux.HandleFunc("GET /debug/pprof/cmdline", pprof.Cmdline)
	mux.HandleFunc("GET /debug/pprof/profile", pprof.Profile)
	mux.HandleFunc("GET /debug/pprof/symbol", pprof.Symbol)
	mux.HandleFunc("GET /debug/pprof/trace", pprof.Trace)
	mux.HandleFunc("GET /debug/pprof/", pprof.Index)
	mux.HandleFunc("GET /debug/stats", handleDebugStats)
	log.Info("dev observability mounted: /debug/pprof + /debug/stats")
}

// handleDebugStats returns an at-a-glance runtime snapshot — the cheap numbers to watch over a long
// session: a climbing goroutine count or heap is a leak; pprof gives the detail.
//
// handleDebugStats 返回运行时快照——长跑要盯的几个数：goroutine/堆只涨即泄漏；细节看 pprof。
func handleDebugStats(w http.ResponseWriter, _ *http.Request) {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	lastPause := uint64(0)
	if m.NumGC > 0 {
		lastPause = m.PauseNs[(m.NumGC+255)%256]
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"goroutines":    runtime.NumGoroutine(),
		"gomaxprocs":    runtime.GOMAXPROCS(0),
		"numCPU":        runtime.NumCPU(),
		"cgoCalls":      runtime.NumCgoCall(), // pure-Go sqlite → expect ~0
		"heapAllocMB":   m.HeapAlloc / (1 << 20),
		"heapSysMB":     m.HeapSys / (1 << 20),
		"heapObjects":   m.HeapObjects,
		"stackInuseMB":  m.StackInuse / (1 << 20),
		"numGC":         m.NumGC,
		"lastGCPauseNs": lastPause,
	})
}
