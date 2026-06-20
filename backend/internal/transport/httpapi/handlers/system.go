package handlers

import (
	"net/http"

	"go.uber.org/zap"

	settingsapp "github.com/sunweilin/anselm/backend/internal/app/settings"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// SystemHandler serves read-only machine/runtime info the settings UI needs. Today: the
// resolved data directory (where this local-first app persists everything) so the desktop
// can show "your data lives here" and offer an open-in-file-manager affordance. Guarded
// like /limits (same settings Service, machine-level but accessed with a workspace selected).
//
// SystemHandler 提供设置页要的只读机器/运行时信息。目前:解析后的数据目录(本地优先 app 一切落盘处),
// 供桌面端显示「你的数据在此」并提供在文件管理器打开。与 /limits 同走 guarded(同 settings Service、
// machine 级但访问时已选 workspace)。
type SystemHandler struct {
	svc *settingsapp.Service
	log *zap.Logger
}

func NewSystemHandler(svc *settingsapp.Service, log *zap.Logger) *SystemHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &SystemHandler{svc: svc, log: log.Named("handlers.system")}
}

func (h *SystemHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/system/data-dir", h.DataDir)
}

type dataDirResponse struct {
	DataDir string `json:"dataDir"`
}

func (h *SystemHandler) DataDir(w http.ResponseWriter, r *http.Request) {
	responsehttpapi.Success(w, http.StatusOK, dataDirResponse{DataDir: h.svc.DataDir()})
}
