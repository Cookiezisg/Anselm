package modelprofile

import (
	"context"
	"errors"
	"testing"
	"time"

	profiledomain "github.com/sunweilin/anselm/backend/internal/domain/modelprofile"
	"go.uber.org/zap"
)

type fakeRepo struct {
	profiles map[string]*profiledomain.Profile
	err      error
}

func (r *fakeRepo) Find(_ context.Context, key string) (*profiledomain.Profile, bool, error) {
	if r.err != nil {
		return nil, false, r.err
	}
	p, ok := r.profiles[key]
	return p, ok, nil
}

func (r *fakeRepo) Save(_ context.Context, p *profiledomain.Profile) error {
	if r.err != nil {
		return r.err
	}
	r.profiles[p.IdentityKey] = p
	return nil
}

func testIdentity() profiledomain.Identity {
	return profiledomain.Identity{
		Provider: "custom", APIKeyID: "aki_1", EndpointFingerprint: "endpoint-sha256",
		CredentialFingerprint: "credential-sha256", ModelID: "model-x",
		RequestClass: profiledomain.RequestClassText, ConfigFingerprint: "config-sha256",
	}
}

func testObservation(kind string, predicted int, recovery bool, at time.Time) profiledomain.Observation {
	return profiledomain.Observation{
		Identity: testIdentity(), Kind: kind, PredictedInputTokens: predicted,
		ActualInputTokens: predicted + 11, RequestBytes: predicted * 3, Recovery: recovery, At: at,
	}
}

func TestBudgetRequiresRecoveredOverflowAndKeepsGuardBand(t *testing.T) {
	now := time.Date(2026, 7, 24, 12, 0, 0, 0, time.UTC)
	repo := &fakeRepo{profiles: map[string]*profiledomain.Profile{}}
	svc := NewService(repo, zap.NewNop())
	svc.now = func() time.Time { return now }

	// Ordinary successes never cause a guessed budget.
	if err := svc.Observe(context.Background(), testObservation(profiledomain.ObservationSuccess, 900_000, false, now)); err != nil {
		t.Fatal(err)
	}
	if budget, ok, err := svc.Budget(context.Background(), testIdentity()); err != nil || ok || budget != 0 {
		t.Fatalf("success-only budget = %d, %v, %v", budget, ok, err)
	}

	// An overflow alone is not enough: retry must prove the recovery path worked.
	if err := svc.Observe(context.Background(), testObservation(profiledomain.ObservationContextOverflow, 1_000_000, false, now)); err != nil {
		t.Fatal(err)
	}
	if _, ok, _ := svc.Budget(context.Background(), testIdentity()); ok {
		t.Fatal("unrecovered overflow must not become an active budget")
	}
	if err := svc.Observe(context.Background(), testObservation(profiledomain.ObservationSuccess, 450_000, true, now.Add(time.Second))); err != nil {
		t.Fatal(err)
	}
	if budget, ok, err := svc.Budget(context.Background(), testIdentity()); err != nil || !ok || budget != 700_000 {
		t.Fatalf("budget = %d, %v, %v; want 700000, true, nil", budget, ok, err)
	}

	// A later lower wall tightens the learned upper bound; we never increase it
	// merely because a later provider response happens to accept more.
	if err := svc.Observe(context.Background(), testObservation(profiledomain.ObservationContextOverflow, 800_000, false, now.Add(2*time.Second))); err != nil {
		t.Fatal(err)
	}
	if budget, ok, _ := svc.Budget(context.Background(), testIdentity()); !ok || budget != 560_000 {
		t.Fatalf("tightened budget = %d, %v; want 560000, true", budget, ok)
	}
}

func TestBudgetExpiresAndIdentityChangeDoesNotBleed(t *testing.T) {
	now := time.Date(2026, 7, 24, 12, 0, 0, 0, time.UTC)
	repo := &fakeRepo{profiles: map[string]*profiledomain.Profile{}}
	svc := NewService(repo, zap.NewNop())
	svc.now = func() time.Time { return now }
	for _, o := range []profiledomain.Observation{
		testObservation(profiledomain.ObservationContextOverflow, 900_000, false, now),
		testObservation(profiledomain.ObservationSuccess, 400_000, true, now.Add(time.Second)),
	} {
		if err := svc.Observe(context.Background(), o); err != nil {
			t.Fatal(err)
		}
	}
	if _, ok, _ := svc.Budget(context.Background(), testIdentity()); !ok {
		t.Fatal("expected learned budget")
	}
	changed := testIdentity()
	changed.CredentialFingerprint = "rotated-credential-sha256"
	if _, ok, _ := svc.Budget(context.Background(), changed); ok {
		t.Fatal("rotated credential must start a fresh profile")
	}
	svc.now = func() time.Time { return now.Add(profileTTL + time.Second) }
	if _, ok, _ := svc.Budget(context.Background(), testIdentity()); ok {
		t.Fatal("expired profile must not govern a request")
	}
}

func TestObserveInvalidEvidenceIsIgnored(t *testing.T) {
	repo := &fakeRepo{profiles: map[string]*profiledomain.Profile{}}
	svc := NewService(repo, zap.NewNop())
	bad := testObservation(profiledomain.ObservationSuccess, 1, false, time.Now())
	bad.Identity.ConfigFingerprint = ""
	if err := svc.Observe(context.Background(), bad); err != nil {
		t.Fatal(err)
	}
	if len(repo.profiles) != 0 {
		t.Fatalf("invalid evidence persisted: %#v", repo.profiles)
	}
	repo.err = errors.New("disk down")
	if err := svc.Observe(context.Background(), testObservation(profiledomain.ObservationSuccess, 1, false, time.Now())); !errors.Is(err, repo.err) {
		t.Fatalf("store error = %v", err)
	}
}
