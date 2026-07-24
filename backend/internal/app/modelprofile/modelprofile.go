// Package modelprofile turns runtime sampling evidence into a conservative,
// expiring soft context budget for unknown external models. It never rejects a
// request locally: its budget only lets the loop compact earlier; the upstream
// remains the authority and a new overflow re-enters transparent recovery.
//
// Package modelprofile 把运行时采样证据变为保守、会过期的软上下文预算。它绝不本地拒绝请求：
// 预算只让 loop 更早压缩；上游仍是权威，新的 overflow 仍走透明恢复。
package modelprofile

import (
	"context"
	"time"

	"go.uber.org/zap"

	profiledomain "github.com/sunweilin/anselm/backend/internal/domain/modelprofile"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
)

const (
	profileTTL      = 30 * 24 * time.Hour
	safeBudgetRatio = 0.70
)

// Clock makes expiry rules deterministic in tests.
type Clock func() time.Time

// Service owns profile aggregation and budget derivation.
type Service struct {
	repo profiledomain.Repository
	now  Clock
	log  *zap.Logger
}

func NewService(repo profiledomain.Repository, log *zap.Logger) *Service {
	if log == nil {
		log = zap.NewNop()
	}
	return &Service{repo: repo, now: func() time.Time { return time.Now().UTC() }, log: log.Named("modelprofile")}
}

// Observe is best-effort at its callers, but returns errors to make storage
// faults observable in tests and logs. Invalid/incomplete evidence is ignored:
// it must never manufacture a cross-route budget.
func (s *Service) Observe(ctx context.Context, o profiledomain.Observation) error {
	if s == nil || s.repo == nil || !o.Valid() {
		return nil
	}
	if o.At.IsZero() {
		o.At = s.now()
	}
	p, found, err := s.repo.Find(ctx, o.Identity.Key())
	if err != nil {
		return err
	}
	if !found {
		p = profiledomain.NewProfile(idgenpkg.New("mrp"), o.Identity, o.At)
	}
	p.Apply(o, o.At.Add(profileTTL))
	if err := s.repo.Save(ctx, p); err != nil {
		return err
	}
	return nil
}

// Budget returns a learned, soft prompt budget in Anselm's prediction unit.
// One overflow alone is deliberately insufficient: it becomes actionable only
// after the compacted retry succeeds. The 30%% guard band absorbs tokenizer and
// wire-accounting mismatch. Expired or incomplete evidence returns unknown.
func (s *Service) Budget(ctx context.Context, identity profiledomain.Identity) (int, bool, error) {
	if s == nil || s.repo == nil || !identity.Valid() {
		return 0, false, nil
	}
	p, found, err := s.repo.Find(ctx, identity.Key())
	if err != nil || !found || !s.now().Before(p.ExpiresAt) ||
		p.LowestOverflowPredicted <= 0 || p.RecoveredOverflows <= 0 {
		return 0, false, err
	}
	budget := int(float64(p.LowestOverflowPredicted) * safeBudgetRatio)
	if budget <= 0 {
		return 0, false, nil
	}
	return budget, true, nil
}
