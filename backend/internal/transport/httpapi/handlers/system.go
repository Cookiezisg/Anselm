package handlers

import (
	"encoding/json"
	"io"
	"net/http"

	"go.uber.org/zap"

	settingsapp "github.com/sunweilin/anselm/backend/internal/app/settings"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// SystemHandler serves read-only machine/runtime info the settings UI needs: the resolved data
// directory (where this local-first app persists everything, "your data lives here" + open-in-file-
// manager) and the build-stamped app version (the About panel; workspace-exempt like /health so the
// desktop can read it before onboarding — bearer still applies). data-dir stays guarded like /limits.
//
// SystemHandler 提供设置页要的只读机器/运行时信息:解析后的数据目录(本地优先 app 一切落盘处)+ 构建期
// 盖章版本(关于页;与 /health 同豁免 workspace、onboarding 前可读,bearer 照过)。data-dir 照旧 guarded。
type SystemHandler struct {
	svc     *settingsapp.Service
	version string
	log     *zap.Logger
}

func NewSystemHandler(svc *settingsapp.Service, version string, log *zap.Logger) *SystemHandler {
	if log == nil {
		log = zap.NewNop()
	}
	if version == "" {
		version = "dev"
	}
	return &SystemHandler{svc: svc, version: version, log: log.Named("handlers.system")}
}

func (h *SystemHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/system/data-dir", h.DataDir)
	mux.HandleFunc("GET /api/v1/version", h.Version)
	mux.HandleFunc("GET /api/v1/network", h.GetNetwork)
	mux.HandleFunc("PATCH /api/v1/network", h.PatchNetwork)
	mux.HandleFunc("GET /api/v1/retention", h.GetRetention)
	mux.HandleFunc("PATCH /api/v1/retention", h.PatchRetention)
}

type dataDirResponse struct {
	DataDir string `json:"dataDir"`
}

func (h *SystemHandler) DataDir(w http.ResponseWriter, r *http.Request) {
	responsehttpapi.Success(w, http.StatusOK, dataDirResponse{DataDir: h.svc.DataDir()})
}

type versionResponse struct {
	Version string `json:"version"`
}

func (h *SystemHandler) Version(w http.ResponseWriter, r *http.Request) {
	responsehttpapi.Success(w, http.StatusOK, versionResponse{Version: h.version})
}

// GetNetwork returns the outbound-proxy config (WRK-062 工单⑩). GetNetwork 返出站代理配置。
func (h *SystemHandler) GetNetwork(w http.ResponseWriter, r *http.Request) {
	responsehttpapi.Success(w, http.StatusOK, h.svc.Net())
}

// PatchNetwork REPLACES the network config (a full object, not a merge — three optional string
// fields) and applies the proxy env; a sidecar restart fully activates it. PatchNetwork 整体替换。
func (h *SystemHandler) PatchNetwork(w http.ResponseWriter, r *http.Request) {
	var req settingsapp.Network
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	next, err := h.svc.PatchNetwork(req)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, next)
}

// GetRetention returns the run-history retention line (scheduler 工单⑬), always a concrete value —
// a fresh install reads back the server-held default, never null, so the client never hardcodes it.
//
// GetRetention 返 run 历史保留线（scheduler 工单⑬），恒为具体值——全新安装读回服务端自持的默认、绝不
// null，故客户端永不硬编它。
func (h *SystemHandler) GetRetention(w http.ResponseWriter, r *http.Request) {
	responsehttpapi.Success(w, http.StatusOK, h.svc.Retention())
}

// PatchRetention MERGES a partial JSON object over the retention line (absent fields keep their
// value) and kicks a sweep so a tightened line reclaims runs now, not at the next slow tick. Raw
// body rather than decodeJSON bind: the merge base and the strict unknown-field rejection live in
// the app layer, the PatchLimits idiom — and a bind would read {} as an explicit 0 = "forever",
// silently disabling cleanup. Negative days → 400 SETTINGS_RETENTION_INVALID.
//
// PatchRetention **合并**部分 JSON 对象到保留线（缺省字段保持）并踢一脚清理，使收紧的线立刻回收 run、
// 而非等下个慢 tick。用裸 body 而非 decodeJSON 绑定：合并基底与严格未知字段拒绝住在 app 层（PatchLimits
// 惯用形）——且绑定会把 {} 读成显式的 0 = 「永久」、静默关掉清理。负天数 → 400 SETTINGS_RETENTION_INVALID。
func (h *SystemHandler) PatchRetention(w http.ResponseWriter, r *http.Request) {
	raw, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 64<<10))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, settingsapp.ErrRetentionInvalid)
		return
	}
	next, err := h.svc.PatchRetention(json.RawMessage(raw))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, next)
}
