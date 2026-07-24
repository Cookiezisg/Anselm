// Package media owns media-ingestion identity. It is intentionally processor-agnostic in its
// first increment: callers can claim deduplicated work now, while image/video/audio processors
// and their workers attach later without changing cache semantics.
package media

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"go.uber.org/zap"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	mediadomain "github.com/sunweilin/anselm/backend/internal/domain/media"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
)

// AttachmentSource is deliberately the small read seam this service needs. It prevents a media
// worker from reaching around application boundaries into an attachment repository.
type AttachmentSource interface {
	Get(ctx context.Context, id string) (*attachmentdomain.Attachment, error)
}

type Service struct {
	attachments AttachmentSource
	repo        mediadomain.Repository
	log         *zap.Logger
}

func NewService(attachments AttachmentSource, repo mediadomain.Repository, log *zap.Logger) *Service {
	if attachments == nil || repo == nil || log == nil {
		panic("mediaapp.NewService: attachments, repo, and logger are required")
	}
	return &Service{attachments: attachments, repo: repo, log: log}
}

// ClaimDerivative returns the one record for this exact original and canonical transform request.
// Encoding JSON through encoding/json gives deterministic map-key order; callers should pass a
// typed parameter struct whenever the request format is externally versioned.
func (s *Service) ClaimDerivative(ctx context.Context, attachmentID, kind string, params any) (*mediadomain.Derivative, bool, error) {
	if strings.TrimSpace(attachmentID) == "" || strings.TrimSpace(kind) == "" {
		return nil, false, mediadomain.ErrInvalidRequest
	}
	encoded, err := json.Marshal(params)
	if err != nil {
		return nil, false, fmt.Errorf("mediaapp.ClaimDerivative: params: %w", err)
	}
	a, err := s.attachments.Get(ctx, attachmentID)
	if err != nil {
		return nil, false, err
	}
	return s.repo.ClaimDerivative(ctx, &mediadomain.Derivative{
		ID: idgenpkg.New("mdr"), AttachmentID: a.ID, Kind: strings.TrimSpace(kind),
		SourceSHA256: a.SHA256, ParamsHash: mediadomain.Hash(encoded), Status: mediadomain.StatusPending,
	})
}

// ClaimPerception applies the same exact-source discipline to task-conditioned evidence. It stores
// only an opaque task digest; the later processor may store its bounded evidence capsule, never the
// original prompt or upstream raw response.
func (s *Service) ClaimPerception(ctx context.Context, attachmentID, kind, provider, model, task string, params any) (*mediadomain.Perception, bool, error) {
	if strings.TrimSpace(attachmentID) == "" || strings.TrimSpace(kind) == "" ||
		strings.TrimSpace(provider) == "" || strings.TrimSpace(model) == "" || strings.TrimSpace(task) == "" {
		return nil, false, mediadomain.ErrInvalidRequest
	}
	encoded, err := json.Marshal(params)
	if err != nil {
		return nil, false, fmt.Errorf("mediaapp.ClaimPerception: params: %w", err)
	}
	a, err := s.attachments.Get(ctx, attachmentID)
	if err != nil {
		return nil, false, err
	}
	return s.repo.ClaimPerception(ctx, &mediadomain.Perception{
		ID: idgenpkg.New("mpr"), AttachmentID: a.ID, Kind: strings.TrimSpace(kind), SourceSHA256: a.SHA256,
		TaskHash: mediadomain.Hash([]byte(task)), Provider: strings.TrimSpace(provider), Model: strings.TrimSpace(model),
		ParamsHash: mediadomain.Hash(encoded), Status: mediadomain.StatusPending,
	})
}
