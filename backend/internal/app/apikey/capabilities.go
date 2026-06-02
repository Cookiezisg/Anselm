package apikey

import (
	"context"

	modelcatalogpkg "github.com/sunweilin/forgify/backend/internal/pkg/modelcatalog"
)

// CapabilityService resolves static model capabilities plus provider-native options.
type CapabilityService struct{}

func NewCapabilityService() *CapabilityService {
	return &CapabilityService{}
}

// ResolveCapabilities returns the default capability for a raw provider model ID.
func (s *CapabilityService) ResolveCapabilities(_ context.Context, provider, modelID string) modelcatalogpkg.Capability {
	return modelcatalogpkg.Compile(provider, modelID, nil).Capability
}
