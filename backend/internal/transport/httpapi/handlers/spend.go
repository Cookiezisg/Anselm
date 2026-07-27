// Package handlers — spend: the direct-side generation spend ledger's read surface (WRK-082
// H10). One aggregated projection endpoint; rows are written only by the generation Router's
// chokepoints, never via HTTP.
//
// handlers — spend:直连侧生成支出台账的读面(H10)。一个聚合投影端点;行只由生成 Router 的
// 咽喉写,永不经 HTTP 写。
package handlers

import (
	"net/http"
	"strconv"

	"go.uber.org/zap"

	spendapp "github.com/sunweilin/anselm/backend/internal/app/spend"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// errSpendWindowInvalid rejects a days parameter that is not a positive integer. Same law as
// trigger-schedule's window (N4 exemption ③): a real parameter fails LOUD on nonsense and is
// CLAMPED on ambition — an unparseable value is a caller bug, a big one is just a big window.
//
// errSpendWindowInvalid 拒绝非正整数的 days 参数。与 trigger-schedule 的窗口同律(N4 豁免③):
// 真参数对胡话**大声失败**、对野心**钳制**——解析不了是调用方的 bug,太大只是窗口大。
var errSpendWindowInvalid = errorspkg.New(errorspkg.KindInvalid, "SPEND_WINDOW_INVALID",
	"days must be a positive integer")

// spendMaxDays caps the projection window. A year of daily × category × provider × model cells
// is still a small payload; beyond that the panel has no use for the resolution.
//
// spendMaxDays 封投影窗。一年的 日×品类×provider×model 格仍是小载荷;再往外面板用不上这个分辨率。
const (
	spendMaxDays     = 365
	spendDefaultDays = 30
)

// SpendHandler serves the spend projection.
//
// SpendHandler 提供支出投影。
type SpendHandler struct {
	svc *spendapp.Service
	log *zap.Logger
}

// NewSpendHandler constructs the handler.
//
// NewSpendHandler 构造 handler。
func NewSpendHandler(svc *spendapp.Service, log *zap.Logger) *SpendHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &SpendHandler{svc: svc, log: log.Named("handlers.spend")}
}

// Register mounts the route.
//
// Register 挂载路由。
func (h *SpendHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/spend", h.Get)
}

// spendRow is the wire shape of one aggregated cell (camelCase, N3).
//
// spendRow 是一格聚合的线缆形(camelCase,N3)。
type spendRow struct {
	Date     string `json:"date"`
	Category string `json:"category"`
	Provider string `json:"provider"`
	Model    string `json:"model"`
	Units    int64  `json:"units"`
	EstPUSD  int64  `json:"estPUSD"`
}

// Get returns the last-N-days aggregation. `estimated` is stamped on the envelope so no client
// can read the money numbers without also reading that they are estimates — units are counted,
// prices are a hand-written table, and the authority is the provider's own billing console.
//
// Get 返回近 N 天聚合。`estimated` 盖在信封上,使任何客户端都无法只读钱数、不读「这是估算」——
// 用量是数的,价是手写表,权威在供应商自己的账单控制台。
func (h *SpendHandler) Get(w http.ResponseWriter, r *http.Request) {
	days := spendDefaultDays
	if raw := r.URL.Query().Get("days"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || n <= 0 {
			responsehttpapi.FromDomainError(w, h.log, errSpendWindowInvalid)
			return
		}
		days = min(n, spendMaxDays)
	}
	rows, err := h.svc.Daily(r.Context(), days)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	out := make([]spendRow, 0, len(rows))
	for _, x := range rows {
		out = append(out, spendRow{Date: x.Date, Category: x.Category, Provider: x.Provider,
			Model: x.Model, Units: x.Units, EstPUSD: x.EstPUSD})
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]any{
		"days":      days,
		"estimated": true,
		"rows":      out,
	})
}
