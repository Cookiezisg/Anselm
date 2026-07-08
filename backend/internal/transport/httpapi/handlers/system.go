package handlers

import (
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
