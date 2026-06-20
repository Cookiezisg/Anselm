package handlers

import (
	"net/http"

	"go.uber.org/zap"

	freetierapp "github.com/sunweilin/anselm/backend/internal/app/freetier"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// FreetierHandler serves the built-in free-tier surface the settings UI needs. Today: a read-only
// quota proxy (GET /freetier/quota) so the free-tier card can show "X / limit remaining, resets at
// …" — the install token is encrypted at rest in the backend, so the client cannot read the gateway
// directly and the backend proxies a live read. Guarded like /limits (workspace-scoped: the managed
// key is per-workspace).
//
// FreetierHandler 提供设置页要的内置免费档面。目前:只读配额代理(GET /freetier/quota),使免费档卡片能显
// 「剩 X / limit,某时重置」——install token 加密存后端,客户端无法直读网关,后端代理一次 live 读。与
// /limits 同走 guarded(workspace 级:受管 key 按 workspace 隔离)。
type FreetierHandler struct {
	svc *freetierapp.QuotaReader
	log *zap.Logger
}

func NewFreetierHandler(svc *freetierapp.QuotaReader, log *zap.Logger) *FreetierHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &FreetierHandler{svc: svc, log: log.Named("handlers.freetier")}
}

func (h *FreetierHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/freetier/quota", h.Quota)
}

type quotaResponse struct {
	Limit     int64  `json:"limit"`
	Used      int64  `json:"used"`
	Remaining int64  `json:"remaining"`
	ResetAt   string `json:"resetAt"`
	Available bool   `json:"available"`
}

func (h *FreetierHandler) Quota(w http.ResponseWriter, r *http.Request) {
	q, err := h.svc.Read(r.Context())
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, quotaResponse{
		Limit:     q.Limit,
		Used:      q.Used,
		Remaining: q.Remaining,
		ResetAt:   q.ResetAt,
		Available: q.Available,
	})
}
