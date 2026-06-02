package handlers

import (
	"net/http"

	"go.uber.org/zap"

	apikeyapp "github.com/sunweilin/forgify/backend/internal/app/apikey"
	apikeydomain "github.com/sunweilin/forgify/backend/internal/domain/apikey"
	modelcatalogpkg "github.com/sunweilin/forgify/backend/internal/pkg/modelcatalog"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// CapabilitiesHandler serves read-only model capabilities and provider-native
// option descriptors.
type CapabilitiesHandler struct {
	capSvc    *apikeyapp.CapabilityService
	apikeySvc *apikeyapp.Service
	log       *zap.Logger
}

func NewCapabilitiesHandler(capSvc *apikeyapp.CapabilityService, apikeySvc *apikeyapp.Service, log *zap.Logger) *CapabilitiesHandler {
	return &CapabilitiesHandler{capSvc: capSvc, apikeySvc: apikeySvc, log: log}
}

func (h *CapabilitiesHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/model-capabilities", h.ListCapabilities)
}

type capabilityItem struct {
	Provider      string                             `json:"provider"`
	ModelID       string                             `json:"modelId"`
	DisplayName   string                             `json:"displayName"`
	ContextWindow int                                `json:"contextWindow"`
	MaxOutput     int                                `json:"maxOutput"`
	Options       []modelcatalogpkg.OptionDescriptor `json:"options"`
}

func (h *CapabilitiesHandler) ListCapabilities(w http.ResponseWriter, r *http.Request) {
	keys, _, err := h.apikeySvc.List(r.Context(), apikeydomain.ListFilter{Limit: 200})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	out := make([]capabilityItem, 0)
	seen := map[string]bool{}
	for _, k := range keys {
		if k.TestStatus != apikeydomain.TestStatusOK {
			continue
		}
		for _, desc := range modelcatalogpkg.DescribeModels(k.Provider, k.ModelsFound) {
			key := k.Provider + "\x00" + desc.ModelID
			if seen[key] {
				continue
			}
			seen[key] = true
			out = append(out, capabilityItem{
				Provider:      k.Provider,
				ModelID:       desc.ModelID,
				DisplayName:   desc.DisplayName,
				ContextWindow: desc.ContextWindow,
				MaxOutput:     desc.MaxOutput,
				Options:       desc.Options,
			})
		}
	}
	responsehttpapi.Success(w, http.StatusOK, out)
}
