package handlers

import (
	"net/http"

	"go.uber.org/zap"

	freetierapp "github.com/sunweilin/anselm/backend/internal/app/freetier"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// FreetierHandler serves the built-in free-tier surface the settings UI needs. Today: a read-only
// quota proxy (GET /freetier/quota) so the free-tier card can show "X / limit remaining, resets at
// …". The Go sidecar owns the device proof key, so the client cannot call the gateway directly and
// the backend proxies a live read. Guarded like /limits (workspace-scoped: the managed
// key is per-workspace).
//
// FreetierHandler 提供设置页要的内置免费档面。目前:只读配额代理(GET /freetier/quota),使免费档卡片能显
// 「剩 X / limit,某时重置」——Go sidecar 持有设备证明私钥，客户端无法直读网关，由后端代理 live 读。与
// /limits 同走 guarded(workspace 级:受管 key 按 workspace 隔离)。
type FreetierHandler struct {
	svc         *freetierapp.QuotaReader
	provisioner *freetierapp.Provisioner
	log         *zap.Logger
}

func NewFreetierHandler(svc *freetierapp.QuotaReader, provisioner *freetierapp.Provisioner, log *zap.Logger) *FreetierHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &FreetierHandler{svc: svc, provisioner: provisioner, log: log.Named("handlers.freetier")}
}

func (h *FreetierHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/freetier/quota", h.Quota)
	// Manual re-provision (WRK-062 S-7): the boot/OnCreated hooks are best-effort — this is the
	// user-facing retry. Idempotent: an existing managed row short-circuits to provisioned:true.
	// 手动重开通(S-7):boot/OnCreated 钩子 best-effort,这是用户侧重试口;幂等,已有受管行即短路。
	mux.HandleFunc("POST /api/v1/freetier:provision", h.Provision)
}

type provisionResponse struct {
	Provisioned bool `json:"provisioned"`
}

func (h *FreetierHandler) Provision(w http.ResponseWriter, r *http.Request) {
	provisioned, err := h.provisioner.ProvisionNow(r.Context())
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, provisionResponse{Provisioned: provisioned})
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
