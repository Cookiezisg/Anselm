package apikey

import (
	"context"
	"fmt"
	"time"

	modeldomain "github.com/sunweilin/forgify/backend/internal/domain/model"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	modelcapspkg "github.com/sunweilin/forgify/backend/internal/pkg/modelcaps"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// CapabilityService resolves merged model capabilities (static catalog ⊕ user override).
// Wire via NewCapabilityService; injected into callers that need ResolveCapabilities.
//
// CapabilityService 解析合并后的模型能力（静态目录 ⊕ 用户覆盖）。
type CapabilityService struct {
	capOverrides modeldomain.CapOverrideRepository
}

// NewCapabilityService constructs a CapabilityService with the given override repo.
//
// NewCapabilityService 基于给定覆盖 repo 构造 CapabilityService。
func NewCapabilityService(repo modeldomain.CapOverrideRepository) *CapabilityService {
	return &CapabilityService{capOverrides: repo}
}

// ResolveCapabilities merges the static catalog with the user's stored override.
// Priority: user override > (live provider API — P4 seam) > static catalog.
//
// ResolveCapabilities 合并静态目录与用户存储的覆盖。优先级：用户覆盖 > (P4 live) > 静态目录。
func (s *CapabilityService) ResolveCapabilities(ctx context.Context, provider, modelID string) modelcapspkg.Cap {
	base := modelcapspkg.Lookup(provider, modelID)

	// P4 seam: live provider-API overlay (Anthropic /v1/models, Gemini, OpenRouter, Ollama) goes here.
	// When implemented, fetch live cap and merge it over base before the user-override step.

	uid, _ := reqctxpkg.GetUserID(ctx)
	if uid == "" {
		return base
	}
	ovr, err := s.capOverrides.Get(ctx, uid, provider, modelID)
	if err != nil || ovr == nil {
		return base
	}
	return modelcapspkg.Apply(base, toCapOverride(ovr))
}

// SetOverride stores (or replaces) a user's capability override for (provider, modelID).
// The ID is generated if o.ID is empty.
//
// SetOverride 存储（或替换）用户对 (provider, modelID) 的能力覆盖；o.ID 空时自动生成。
func (s *CapabilityService) SetOverride(ctx context.Context, provider, modelID string, o *modeldomain.ModelCapOverride) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return fmt.Errorf("apikey.CapabilityService.SetOverride: %w", err)
	}
	if o.ID == "" {
		o.ID = idgenpkg.New("mco")
	}
	o.UserID = uid
	o.Provider = provider
	o.ModelID = modelID
	o.UpdatedAt = time.Now().UTC()
	if o.CreatedAt.IsZero() {
		o.CreatedAt = o.UpdatedAt
	}
	if err := s.capOverrides.Upsert(ctx, o); err != nil {
		return fmt.Errorf("apikey.CapabilityService.SetOverride: %w", err)
	}
	return nil
}

// ClearOverride removes the user's override for (provider, modelID) if one exists.
//
// ClearOverride 删除用户对 (provider, modelID) 的覆盖（若存在）。
func (s *CapabilityService) ClearOverride(ctx context.Context, provider, modelID string) error {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return fmt.Errorf("apikey.CapabilityService.ClearOverride: %w", err)
	}
	if err := s.capOverrides.Delete(ctx, uid, provider, modelID); err != nil {
		return fmt.Errorf("apikey.CapabilityService.ClearOverride: %w", err)
	}
	return nil
}

// ListOverrides returns all active capability overrides for the current user.
//
// ListOverrides 返回当前用户所有活跃的能力覆盖。
func (s *CapabilityService) ListOverrides(ctx context.Context) ([]*modeldomain.ModelCapOverride, error) {
	uid, err := reqctxpkg.RequireUserID(ctx)
	if err != nil {
		return nil, fmt.Errorf("apikey.CapabilityService.ListOverrides: %w", err)
	}
	rows, err := s.capOverrides.List(ctx, uid)
	if err != nil {
		return nil, fmt.Errorf("apikey.CapabilityService.ListOverrides: %w", err)
	}
	return rows, nil
}

// toCapOverride maps a stored ModelCapOverride to the modelcaps.CapOverride overlay.
// ThinkingShape string ("none"|"effort"|"budget"|"toggle") → modelcaps.ThinkingShape enum.
//
// toCapOverride 把 ModelCapOverride 映射到 modelcaps.CapOverride；字符串 thinking shape → 枚举。
func toCapOverride(o *modeldomain.ModelCapOverride) *modelcapspkg.CapOverride {
	if o == nil {
		return nil
	}
	result := &modelcapspkg.CapOverride{
		ContextWindow: o.ContextWindow,
		MaxOutput:     o.MaxOutput,
	}
	if o.ThinkingShape != nil {
		s := thinkingShapeFromString(*o.ThinkingShape)
		result.Thinking = &s
	}
	return result
}

func thinkingShapeFromString(s string) modelcapspkg.ThinkingShape {
	switch s {
	case "effort":
		return modelcapspkg.ShapeEffort
	case "budget":
		return modelcapspkg.ShapeBudget
	case "toggle":
		return modelcapspkg.ShapeToggle
	default:
		return modelcapspkg.ShapeNone
	}
}
