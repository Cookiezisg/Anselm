// dev_processes.go — GET /dev/bash-processes (TE-12). Read-only inspection
// of the Bash tool's background-process registry. Lets testend show every
// long-running child the LLM has spawned with run_in_background:true:
// command, status, pid-equivalent (bash_id), exit code, ring-buffer size,
// and an optional non-mutating tail sample.
//
// dev_processes.go ——/dev/bash-processes（TE-12）。Bash 工具后台进程注册
// 表的只读检查。让 testend 看每个 LLM 用 run_in_background:true spawn 的
// 长跑子进程：命令 / 状态 / bash_id / 退出码 / 环形缓冲大小 / 非破坏性尾。
package handlers

import (
	"net/http"
	"strconv"

	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// BashProcesses handles GET /dev/bash-processes?sample=N (default 2048,
// max 16384). Returns every tracked process newest-first. The optional
// `sample` query controls how many bytes of buffer tail to include per
// process — 0 = no sample (just metadata).
//
// BashProcesses 处理 GET /dev/bash-processes?sample=N（默认 2048，最大
// 16384）。返每个追踪的进程，最新优先。sample 控制每进程返多少尾字节，
// 0 = 不返样本（只元数据）。
func (h *DevHandler) BashProcesses(w http.ResponseWriter, r *http.Request) {
	sample := 2048
	if s := r.URL.Query().Get("sample"); s != "" {
		if n, err := strconv.Atoi(s); err == nil && n >= 0 {
			sample = n
		}
	}
	if sample > 16384 {
		sample = 16384
	}
	snaps := h.shellManager.Snapshots(sample)
	responsehttpapi.Success(w, http.StatusOK, map[string]any{
		"count":     len(snaps),
		"sample":    sample,
		"processes": snaps,
	})
}
