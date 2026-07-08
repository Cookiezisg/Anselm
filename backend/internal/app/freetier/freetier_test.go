package freetier

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"testing"

	"go.uber.org/zap"

	apikeyapp "github.com/sunweilin/anselm/backend/internal/app/apikey"
	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

type fakeKeys struct {
	rows      []*apikeydomain.APIKey
	created   []apikeyapp.ManagedCreateInput
	createErr error
}

func (f *fakeKeys) List(_ context.Context, filter apikeydomain.ListFilter) ([]*apikeydomain.APIKey, string, error) {
	var out []*apikeydomain.APIKey
	for _, r := range f.rows {
		if filter.Provider == "" || r.Provider == filter.Provider {
			out = append(out, r)
		}
	}
	return out, "", nil
}

func (f *fakeKeys) CreateManaged(_ context.Context, in apikeyapp.ManagedCreateInput) (*apikeydomain.APIKey, error) {
	f.created = append(f.created, in)
	if f.createErr != nil {
		return nil, f.createErr
	}
	row := &apikeydomain.APIKey{ID: "aki_x", Provider: in.Provider, DisplayName: in.DisplayName}
	f.rows = append(f.rows, row)
	return row, nil
}

type fakeInstaller struct {
	gotHash string
	gotBase string
	token   string
	err     error
}

func (f *fakeInstaller) Install(_ context.Context, baseURL, fingerprintHash, _ string) (llminfra.InstallResult, error) {
	f.gotHash, f.gotBase = fingerprintHash, baseURL
	if f.err != nil {
		return llminfra.InstallResult{}, f.err
	}
	return llminfra.InstallResult{Token: f.token, MonthlyQuota: 5000}, nil
}

func okFP() (string, error)  { return "machine-serial-123", nil }
func errFP() (string, error) { return "", errors.New("no fingerprint") }

// fakeDefaults records each seed call so a test can assert the ref (managed key id + model) the
// provisioner would write as the workspace scenario defaults.
type fakeDefaults struct {
	seeded []modeldomain.ModelRef
	err    error
}

func (f *fakeDefaults) SeedDefaultsIfUnset(_ context.Context, ref modeldomain.ModelRef) error {
	f.seeded = append(f.seeded, ref)
	return f.err
}

func newProv(keys Keys, inst Installer, fp Fingerprint) *Provisioner {
	return NewProvisioner(keys, nil, inst, fp, zap.NewNop()) // nil defaults → seeding skipped
}

// ProvisionNow (S-7): reports true when a managed row exists afterwards (created or pre-existing),
// false when provisioning degraded — the states, not faults, discipline.
// ProvisionNow(S-7):事后有受管行返 true(新建或原有),开通降级返 false——状态非错误。
func TestProvisionNow_ReportsHonestly(t *testing.T) {
	// Fresh install path → row lands → true. 新装→落行→true。
	keys := &fakeKeys{}
	ok, err := newProv(keys, &fakeInstaller{token: "gwk_minted"}, okFP).ProvisionNow(context.Background())
	if err != nil || !ok {
		t.Fatalf("fresh provision → (%v,%v), want (true,nil)", ok, err)
	}
	// Idempotent short-circuit → still true, no second install. 幂等短路→仍 true。
	inst2 := &fakeInstaller{token: "gwk_other"}
	ok, err = newProv(keys, inst2, okFP).ProvisionNow(context.Background())
	if err != nil || !ok {
		t.Fatalf("idempotent provision → (%v,%v), want (true,nil)", ok, err)
	}
	if inst2.gotHash != "" {
		t.Error("existing row must short-circuit BEFORE the installer is called")
	}
	// Degraded path (gateway down) → false, nil. 降级(网关挂)→(false,nil)。
	ok, err = newProv(&fakeKeys{}, &fakeInstaller{err: errors.New("gateway down")}, okFP).ProvisionNow(context.Background())
	if err != nil || ok {
		t.Fatalf("degraded provision → (%v,%v), want (false,nil)", ok, err)
	}
}

func TestEnsure_ProvisionsManagedRow(t *testing.T) {
	keys := &fakeKeys{}
	inst := &fakeInstaller{token: "gwk_minted"}
	if err := newProv(keys, inst, okFP).EnsureForWorkspace(context.Background()); err != nil {
		t.Fatal(err)
	}
	if len(keys.created) != 1 {
		t.Fatalf("CreateManaged called %d times, want 1", len(keys.created))
	}
	in := keys.created[0]
	if in.Provider != "anselm" || in.Key != "gwk_minted" || in.BaseURL != llminfra.AnselmBaseURL {
		t.Errorf("managed input = %+v", in)
	}
	if in.TestResponse != llminfra.AnselmProbeBody() {
		t.Errorf("test response = %q, want synthetic /models body", in.TestResponse)
	}
	// Privacy: the installer must receive the HASH of the fingerprint, never the raw serial.
	want := sha256.Sum256([]byte("machine-serial-123"))
	if inst.gotHash != hex.EncodeToString(want[:]) {
		t.Errorf("install fingerprint = %q, want sha256 hex", inst.gotHash)
	}
	if inst.gotHash == "machine-serial-123" {
		t.Fatal("raw fingerprint leaked to installer")
	}
	if inst.gotBase != llminfra.AnselmBaseURL {
		t.Errorf("install base = %q, want gateway base", inst.gotBase)
	}
}

func TestEnsure_IdempotentWhenPresent(t *testing.T) {
	keys := &fakeKeys{rows: []*apikeydomain.APIKey{{ID: "aki_existing", Provider: "anselm"}}}
	inst := &fakeInstaller{token: "gwk_x"}
	if err := newProv(keys, inst, okFP).EnsureForWorkspace(context.Background()); err != nil {
		t.Fatal(err)
	}
	if len(keys.created) != 0 {
		t.Errorf("should not create when a managed row exists; created %d", len(keys.created))
	}
	if inst.gotHash != "" {
		t.Error("should not install when already provisioned")
	}
}

func TestEnsure_DegradesWithoutFingerprint(t *testing.T) {
	keys := &fakeKeys{}
	inst := &fakeInstaller{token: "gwk_x"}
	if err := newProv(keys, inst, errFP).EnsureForWorkspace(context.Background()); err != nil {
		t.Errorf("must degrade to nil, got %v", err)
	}
	if inst.gotHash != "" || len(keys.created) != 0 {
		t.Error("no fingerprint must skip install + create")
	}
}

func TestEnsure_DegradesOnInstallError(t *testing.T) {
	keys := &fakeKeys{}
	inst := &fakeInstaller{err: errors.New("gateway down")}
	if err := newProv(keys, inst, okFP).EnsureForWorkspace(context.Background()); err != nil {
		t.Errorf("must degrade to nil, got %v", err)
	}
	if len(keys.created) != 0 {
		t.Error("install failure must skip create")
	}
}

func TestEnsure_DisplayNameConflictIsIdempotent(t *testing.T) {
	keys := &fakeKeys{createErr: apikeydomain.ErrDisplayNameConflict}
	inst := &fakeInstaller{token: "gwk_x"}
	if err := newProv(keys, inst, okFP).EnsureForWorkspace(context.Background()); err != nil {
		t.Errorf("display-name conflict must be treated as idempotent no-op, got %v", err)
	}
}

// On a fresh provision the just-created managed key becomes the seed for all three scenario defaults.
func TestEnsure_SeedsWorkspaceDefaults(t *testing.T) {
	keys := &fakeKeys{}
	defs := &fakeDefaults{}
	p := NewProvisioner(keys, defs, &fakeInstaller{token: "gwk_minted"}, okFP, zap.NewNop())
	if err := p.EnsureForWorkspace(context.Background()); err != nil {
		t.Fatal(err)
	}
	if len(defs.seeded) != 1 {
		t.Fatalf("SeedDefaultsIfUnset called %d times, want 1", len(defs.seeded))
	}
	if ref := defs.seeded[0]; ref.APIKeyID != "aki_x" || ref.ModelID != llminfra.AnselmModelID {
		t.Errorf("seeded ref = %+v, want {aki_x, %s}", ref, llminfra.AnselmModelID)
	}
}

// The already-provisioned path still seeds — a workspace whose managed key predates the seeding
// self-heals its NULL defaults on the next boot, using the EXISTING key's id (not a fresh install).
func TestEnsure_SeedsDefaultsOnSelfHeal(t *testing.T) {
	keys := &fakeKeys{rows: []*apikeydomain.APIKey{{ID: "aki_existing", Provider: "anselm"}}}
	defs := &fakeDefaults{}
	inst := &fakeInstaller{token: "gwk_x"}
	p := NewProvisioner(keys, defs, inst, okFP, zap.NewNop())
	if err := p.EnsureForWorkspace(context.Background()); err != nil {
		t.Fatal(err)
	}
	if len(keys.created) != 0 || inst.gotHash != "" {
		t.Error("existing key must not re-install / re-create")
	}
	if len(defs.seeded) != 1 || defs.seeded[0].APIKeyID != "aki_existing" {
		t.Fatalf("existing key must still seed defaults with its own id, got %+v", defs.seeded)
	}
}
