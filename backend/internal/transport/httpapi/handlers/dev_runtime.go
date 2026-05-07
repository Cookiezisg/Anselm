// dev_runtime.go — GET /dev/runtime endpoint (TE-21). Reports the Go
// runtime's view of the server: goroutine count, mem/heap/stack stats,
// GC numbers, SQLite connection pool, uptime. The Metrics tab in testend
// polls this every few seconds so testers can spot leaks (rising goroutine
// count, heap that never shrinks, GC pauses spiking) without attaching
// pprof or restarting with extra flags.
//
// dev_runtime.go ——/dev/runtime（TE-21）。报告 Go runtime 视角的服务器状态：
// goroutine 数、mem/heap/stack、GC、SQLite 连接池、uptime。testend Metrics
// tab 几秒轮询，让测试者无需 pprof 或重启就能发现泄漏（goroutine 涨、heap
// 不释放、GC 暂停飙升）。
package handlers

import (
	"net/http"
	"runtime"
	"time"

	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// Runtime serves GET /dev/runtime — single-shot snapshot of the server's
// runtime state. The response shape mirrors what the Metrics tab card
// layout expects: runtime / mem / gc / db sections.
//
// Runtime 单次快照，shape 对应 Metrics tab 的卡片布局。
func (h *DevHandler) Runtime(w http.ResponseWriter, r *http.Request) {
	var ms runtime.MemStats
	runtime.ReadMemStats(&ms)

	uptimeSeconds := int64(0)
	if h.startedAt != (time.Time{}) {
		uptimeSeconds = int64(time.Since(h.startedAt).Seconds())
	}

	out := map[string]any{
		"goVersion":      runtime.Version(),
		"goroutines":     runtime.NumGoroutine(),
		"cgoCalls":       runtime.NumCgoCall(),
		"numCPU":         runtime.NumCPU(),
		"maxProcs":       runtime.GOMAXPROCS(0),
		"uptimeSeconds":  uptimeSeconds,
		"mem": map[string]any{
			"heapAlloc":  ms.HeapAlloc,
			"heapSys":    ms.HeapSys,
			"heapInuse":  ms.HeapInuse,
			"heapIdle":   ms.HeapIdle,
			"stackInuse": ms.StackInuse,
			"sys":        ms.Sys,
		},
		"gc": map[string]any{
			"numGC":       ms.NumGC,
			"numForcedGC": ms.NumForcedGC,
			"lastPauseNs": ms.PauseNs[(ms.NumGC+255)%256],
			"totalPauseNs": ms.PauseTotalNs,
			"cpuFraction":  ms.GCCPUFraction,
		},
	}

	// SQLite pool stats (best-effort — db.DB() can fail in pathological
	// configs; ignore and leave the section out rather than 500ing).
	// SQLite 连接池统计（best-effort，db.DB() 异常时省略本段不 500）。
	if sqlDB, err := h.db.DB(); err == nil {
		s := sqlDB.Stats()
		out["db"] = map[string]any{
			"openConnections":    s.OpenConnections,
			"inUse":              s.InUse,
			"idle":               s.Idle,
			"waitCount":          s.WaitCount,
			"waitDurationNs":     s.WaitDuration.Nanoseconds(),
			"maxOpenConnections": s.MaxOpenConnections,
		}
	}

	responsehttpapi.Success(w, http.StatusOK, out)
}
