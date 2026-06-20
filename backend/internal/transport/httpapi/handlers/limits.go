package handlers

import (
	"encoding/json"
	"io"
	"net/http"

	"go.uber.org/zap"

	settingsapp "github.com/sunweilin/anselm/backend/internal/app/settings"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// LimitsHandler serves the user-tunable operational ceilings (settings.json "limits"
// block): GET returns the live values, PATCH merges a partial update, persists and
// hot-swaps — consumers see new values on their next read, no restart.
//
// LimitsHandler 提供用户可调运行上限（settings.json "limits" 段）：GET 返活动值，PATCH
// 合并部分更新、持久化并热换——消费方下一次读取即见新值，无需重启。
type LimitsHandler struct {
	svc *settingsapp.Service
	log *zap.Logger
}

func NewLimitsHandler(svc *settingsapp.Service, log *zap.Logger) *LimitsHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &LimitsHandler{svc: svc, log: log.Named("handlers.limits")}
}

func (h *LimitsHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/limits", h.Get)
	mux.HandleFunc("GET /api/v1/limits/schema", h.Schema)
	mux.HandleFunc("PATCH /api/v1/limits", h.Patch)
	mux.HandleFunc("POST /api/v1/limits:reset", h.Reset)
}

// Schema returns each tunable limit's metadata (default/min/max/unit/desc) so the UI renders
// ranges from the backend instead of hardcoding the Go constants. Static — no body, no state.
//
// Schema 返回每个可调上限的元数据（default/min/max/unit/desc）,使 UI 从后端渲染范围、免硬编 Go 常量。
// 静态——无 body、无状态。
func (h *LimitsHandler) Schema(w http.ResponseWriter, r *http.Request) {
	responsehttpapi.Success(w, http.StatusOK, h.svc.LimitsSchema())
}

func (h *LimitsHandler) Get(w http.ResponseWriter, r *http.Request) {
	responsehttpapi.Success(w, http.StatusOK, h.svc.Limits())
}

func (h *LimitsHandler) Patch(w http.ResponseWriter, r *http.Request) {
	raw, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 64<<10))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, settingsapp.ErrLimitsInvalid)
		return
	}
	cur, err := h.svc.PatchLimits(json.RawMessage(raw))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, cur)
}

// Reset restores the canonical default limits (no body) — the server owns the defaults so
// the client never hardcodes them. Returns the (now-default) live values, like Patch.
//
// Reset 恢复规范默认 limits（无 body）——默认由服务端持有,客户端绝不硬编。返回（现为默认的）
// 活动值,与 Patch 同形。
func (h *LimitsHandler) Reset(w http.ResponseWriter, r *http.Request) {
	cur, err := h.svc.ResetLimits()
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, cur)
}
