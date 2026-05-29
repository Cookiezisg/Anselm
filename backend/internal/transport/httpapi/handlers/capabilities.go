package handlers

import (
	"net/http"

	"go.uber.org/zap"

	apikeyapp "github.com/sunweilin/forgify/backend/internal/app/apikey"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	modelcapspkg "github.com/sunweilin/forgify/backend/internal/pkg/modelcaps"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// CapabilitiesHandler serves GET/PUT/DELETE /api/v1/model-capabilities, merging
// the static catalog with per-user overrides via CapabilityService.
//
// CapabilitiesHandler 提供 /api/v1/model-capabilities 的三个端点，通过
// CapabilityService 合并静态目录与用户覆盖。
type CapabilitiesHandler struct {
	capSvc    *apikeyapp.CapabilityService
	apikeySvc *apikeyapp.Service
	log       *zap.Logger
}

// NewCapabilitiesHandler constructs the handler.
//
// NewCapabilitiesHandler 构造 handler。
func NewCapabilitiesHandler(capSvc *apikeyapp.CapabilityService, apikeySvc *apikeyapp.Service, log *zap.Logger) *CapabilitiesHandler {
	return &CapabilitiesHandler{capSvc: capSvc, apikeySvc: apikeySvc, log: log}
}

func (h *CapabilitiesHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/model-capabilities", h.List)
	mux.HandleFunc("PUT /api/v1/model-capabilities/{provider}/{modelId}", h.SetOverride)
	mux.HandleFunc("DELETE /api/v1/model-capabilities/{provider}/{modelId}", h.ClearOverride)
}

// capabilityItem is the JSON shape for one resolved model capability.
//
// capabilityItem 是单个模型解析能力的 JSON 结构。
type capabilityItem struct {
	Provider      string   `json:"provider"`
	ModelID       string   `json:"modelId"`
	ThinkingShape string   `json:"thinkingShape"`
	EffortValues  []string `json:"effortValues"`
	BudgetMin     int      `json:"budgetMin"`
	BudgetMax     int      `json:"budgetMax"`
	ContextWindow int      `json:"contextWindow"`
	MaxOutput     int      `json:"maxOutput"`
	ContextMode   string   `json:"contextMode"`
}

// List resolves capabilities for every modelId across all of the user's verified LLM keys.
//
// List 遍历用户所有已验证 LLM key 的 modelsFound，解析并返回各模型能力。
func (h *CapabilitiesHandler) List(w http.ResponseWriter, r *http.Request) {
	keys, _, err := h.apikeySvc.List(r.Context(), apikeydomain.ListFilter{Limit: 200})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	out := make([]capabilityItem, 0)
	for _, k := range keys {
		if k.TestStatus != apikeydomain.TestStatusOK {
			continue
		}
		for _, modelID := range k.ModelsFound {
			cap := h.capSvc.ResolveCapabilities(r.Context(), k.Provider, modelID)
			effortValues := cap.EffortValues
			if effortValues == nil {
				effortValues = []string{}
			}
			out = append(out, capabilityItem{
				Provider:      k.Provider,
				ModelID:       modelID,
				ThinkingShape: thinkingShapeToString(cap.Thinking),
				EffortValues:  effortValues,
				BudgetMin:     cap.BudgetMin,
				BudgetMax:     cap.BudgetMax,
				ContextWindow: cap.ContextWindow,
				MaxOutput:     cap.MaxOutput,
				ContextMode:   cap.ContextMode,
			})
		}
	}
	responsehttpapi.Success(w, http.StatusOK, out)
}

type setOverrideRequest struct {
	ThinkingShape *string `json:"thinkingShape"`
	ContextWindow *int    `json:"contextWindow"`
	MaxOutput     *int    `json:"maxOutput"`
}

// SetOverride stores (or replaces) a user capability override; returns 200 with the stored override.
//
// SetOverride 存储（或替换）用户覆盖；按 §N6 upsert 统一返 200。
func (h *CapabilitiesHandler) SetOverride(w http.ResponseWriter, r *http.Request) {
	provider := r.PathValue("provider")
	modelID := r.PathValue("modelId")
	var req setOverrideRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	// Validate thinkingShape if provided.
	if req.ThinkingShape != nil {
		if !isValidThinkingShape(*req.ThinkingShape) {
			responsehttpapi.Error(w, http.StatusBadRequest, "INVALID_THINKING_SHAPE",
				"thinkingShape must be one of: none, effort, budget, toggle", nil)
			return
		}
	}
	o := &modeldomain.ModelCapOverride{
		ThinkingShape: req.ThinkingShape,
		ContextWindow: req.ContextWindow,
		MaxOutput:     req.MaxOutput,
	}
	if err := h.capSvc.SetOverride(r.Context(), provider, modelID, o); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, o)
}

// ClearOverride removes a user capability override.
//
// ClearOverride 删除用户覆盖，不存在时静默成功。
func (h *CapabilitiesHandler) ClearOverride(w http.ResponseWriter, r *http.Request) {
	provider := r.PathValue("provider")
	modelID := r.PathValue("modelId")
	if err := h.capSvc.ClearOverride(r.Context(), provider, modelID); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}

// thinkingShapeToString maps the ThinkingShape enum to its wire string.
//
// thinkingShapeToString 把 ThinkingShape 枚举映射到字符串。
func thinkingShapeToString(s modelcapspkg.ThinkingShape) string {
	switch s {
	case modelcapspkg.ShapeEffort:
		return "effort"
	case modelcapspkg.ShapeBudget:
		return "budget"
	case modelcapspkg.ShapeToggle:
		return "toggle"
	default:
		return "none"
	}
}

func isValidThinkingShape(s string) bool {
	switch s {
	case "none", "effort", "budget", "toggle":
		return true
	}
	return false
}

