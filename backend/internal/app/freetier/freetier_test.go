package freetier

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"testing"
	"time"

	"go.uber.org/zap"

	apikeyapp "github.com/sunweilin/anselm/backend/internal/app/apikey"
	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

type rotation struct {
	id, newKey, testResponse string
}

type fakeKeys struct {
	rows       []*apikeydomain.APIKey
	created    []apikeyapp.ManagedCreateInput
	createErr  error
	tested     []string
	testErr    error
	testResult *apikeyapp.TestResult // scripted probe verdict; nil → zero-value result 脚本化探测结论
	rotated    []rotation
	rotateErr  error
	onTest     func()
}

// Test records the live-capability refresh the provisioner performs after minting the managed key,
// and doubles as the heal path's probe — [testResult] scripts the verdict.
// Test 记录 provisioner 铸 key 后的 live 能力刷新,同时兼任自愈路径的探针——testResult 脚本化结论。
func (f *fakeKeys) Test(_ context.Context, id string) (*apikeyapp.TestResult, error) {
	f.tested = append(f.tested, id)
	if f.onTest != nil {
		f.onTest()
	}
	if f.testErr != nil {
		return nil, f.testErr
	}
	if f.testResult != nil {
		return f.testResult, nil
	}
	return &apikeyapp.TestResult{}, nil
}

func (f *fakeKeys) RotateManagedCredential(_ context.Context, id, newKey, testResponse string) error {
	if f.rotateErr != nil {
		return f.rotateErr
	}
	f.rotated = append(f.rotated, rotation{id: id, newKey: newKey, testResponse: testResponse})
	return nil
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
	gotHash   string
	gotBase   string
	installID string
	err       error
	started   chan struct{}
	release   <-chan struct{}
	calls     int
}

func (f *fakeInstaller) Install(ctx context.Context, baseURL, fingerprintHash, _ string) (llminfra.InstallResult, error) {
	f.calls++
	f.gotHash, f.gotBase = fingerprintHash, baseURL
	if f.started != nil {
		close(f.started)
		f.started = nil
	}
	if f.release != nil {
		select {
		case <-f.release:
		case <-ctx.Done():
			return llminfra.InstallResult{}, ctx.Err()
		}
	}
	if f.err != nil {
		return llminfra.InstallResult{}, f.err
	}
	return llminfra.InstallResult{InstallID: f.installID, MonthlyQuota: 5000}, nil
}

func okFP() (string, error)  { return "machine-serial-123", nil }
func errFP() (string, error) { return "", errors.New("no fingerprint") }

// fakeDefaults records each seed call so a test can assert the ref (managed key id + model) the
// provisioner would write as the workspace scenario defaults.
type fakeDefaults struct {
	seeded []modeldomain.ModelRef
	err    error
	onSeed func()
}

func (f *fakeDefaults) SeedDefaultsIfUnset(_ context.Context, ref modeldomain.ModelRef) error {
	f.seeded = append(f.seeded, ref)
	if f.onSeed != nil {
		f.onSeed()
	}
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
	ok, err := newProv(keys, &fakeInstaller{installID: "ins_minted"}, okFP).ProvisionNow(context.Background())
	if err != nil || !ok {
		t.Fatalf("fresh provision → (%v,%v), want (true,nil)", ok, err)
	}
	// Idempotent short-circuit → still true, no second install. 幂等短路→仍 true。
	inst2 := &fakeInstaller{installID: "ins_other"}
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

// The dead-install heal (E 真机验收 0725): the gateway database was wiped, the stored install id no
// longer existed, and the workspace was permanently dead — the managed row is user-immutable and
// EnsureForWorkspace no-ops on existing rows. ProvisionNow must repair exactly this state.
// 死 install 自愈:网关库被清、存储的 install id 不复存在,workspace 永久死结(受管行不可变 + ensure 见行
// 空操作)。ProvisionNow 必须修复恰好这一种状态。
func TestProvisionNow_HealsDeadInstall(t *testing.T) {
	keys := &fakeKeys{
		rows: []*apikeydomain.APIKey{{ID: "aki_dead", Provider: "anselm"}},
		testResult: &apikeyapp.TestResult{
			OK:      false,
			Message: `HTTP 401: {"error":{"code":"INVALID_INSTALL","message":"missing or invalid install id"}}`,
		},
	}
	inst := &fakeInstaller{installID: "ins_reborn"}
	ok, err := newProv(keys, inst, okFP).ProvisionNow(context.Background())
	if err != nil || !ok {
		t.Fatalf("heal → (%v,%v), want (true,nil)", ok, err)
	}
	if len(keys.rotated) != 1 {
		t.Fatalf("want exactly one rotation, got %d", len(keys.rotated))
	}
	r := keys.rotated[0]
	if r.id != "aki_dead" || r.newKey != "ins_reborn" {
		t.Errorf("rotation = %+v; want the SAME row id with the fresh install id", r)
	}
	if r.testResponse == "" {
		t.Error("the placeholder capability archive must be reseeded with the rotation")
	}
	if len(keys.created) != 0 {
		t.Error("heal must rotate in place, never mint a second row (defaults reference the id)")
	}
}

// The narrow-trigger law: a probe can fail for a dozen transient reasons (offline, gateway restart,
// rate limit) and rotating on any of them would destroy a WORKING install because the network
// blinked. Only the gateway's structured INVALID_INSTALL verdict may trigger.
// 窄触发律:探测失败有一打瞬时原因,在其中任何一种上轮换=因网络眨眼毁掉好 install。只有网关结构化的
// INVALID_INSTALL 结论可触发。
func TestProvisionNow_TransientFailureNeverRotates(t *testing.T) {
	for _, res := range []*apikeyapp.TestResult{
		{OK: false, Message: "dial tcp 127.0.0.1:443: connect: connection refused"},
		{OK: false, Message: "HTTP 429: rate limited"},
		{OK: true}, // healthy 健康
	} {
		keys := &fakeKeys{rows: []*apikeydomain.APIKey{{ID: "aki_live", Provider: "anselm"}}, testResult: res}
		inst := &fakeInstaller{installID: "ins_should_not_exist"}
		ok, err := newProv(keys, inst, okFP).ProvisionNow(context.Background())
		if err != nil || !ok {
			t.Fatalf("existing row → (%v,%v), want (true,nil)", ok, err)
		}
		if len(keys.rotated) != 0 {
			t.Errorf("probe %q must NOT rotate", res.Message)
		}
		if inst.gotHash != "" {
			t.Errorf("probe %q must NOT re-install", res.Message)
		}
	}
}

// A failed heal leaves the row as it was — best-effort like the rest of the package; the next
// explicit provision retries. 自愈失败保持原行——与全包同为 best-effort,下次显式 provision 再试。
func TestProvisionNow_HealFailureLeavesRowIntact(t *testing.T) {
	keys := &fakeKeys{
		rows:       []*apikeydomain.APIKey{{ID: "aki_dead", Provider: "anselm"}},
		testResult: &apikeyapp.TestResult{OK: false, Message: `HTTP 401: {"error":{"code":"INVALID_INSTALL"}}`},
	}
	ok, err := newProv(keys, &fakeInstaller{err: errors.New("gateway down mid-heal")}, okFP).ProvisionNow(context.Background())
	if err != nil || !ok {
		t.Fatalf("failed heal → (%v,%v), want (true,nil) — the row still exists", ok, err)
	}
	if len(keys.rotated) != 0 {
		t.Error("re-install failed — nothing may have been rotated")
	}
}

func TestEnsure_ProvisionsManagedRow(t *testing.T) {
	keys := &fakeKeys{}
	inst := &fakeInstaller{installID: "ins_minted"}
	if err := newProv(keys, inst, okFP).EnsureForWorkspace(context.Background()); err != nil {
		t.Fatal(err)
	}
	if len(keys.created) != 1 {
		t.Fatalf("CreateManaged called %d times, want 1", len(keys.created))
	}
	in := keys.created[0]
	if in.Provider != "anselm" || in.Key != "ins_minted" || in.BaseURL != llminfra.AnselmBaseURL {
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
	inst := &fakeInstaller{installID: "ins_x"}
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
	inst := &fakeInstaller{installID: "ins_x"}
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
	inst := &fakeInstaller{installID: "ins_x"}
	if err := newProv(keys, inst, okFP).EnsureForWorkspace(context.Background()); err != nil {
		t.Errorf("display-name conflict must be treated as idempotent no-op, got %v", err)
	}
}

// On a fresh provision the just-created managed key becomes the seed for all three scenario defaults.
func TestEnsure_SeedsWorkspaceDefaults(t *testing.T) {
	keys := &fakeKeys{}
	defs := &fakeDefaults{}
	p := NewProvisioner(keys, defs, &fakeInstaller{installID: "ins_minted"}, okFP, zap.NewNop())
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

// A freshly persisted managed key is immediately visible to another request, while a live
// capability probe is network I/O. Therefore defaults must land before that probe: otherwise a
// user who opens a brand-new workspace and sends the first message immediately gets
// LLM_RESOLVE_ERROR even though the managed key already exists.
func TestEnsure_SeedsDefaultsBeforeLiveCapabilityProbe(t *testing.T) {
	seeded := false
	defs := &fakeDefaults{onSeed: func() { seeded = true }}
	keys := &fakeKeys{onTest: func() {
		if !seeded {
			t.Error("live capability probe ran before the managed defaults were seeded")
		}
	}}
	p := NewProvisioner(keys, defs, &fakeInstaller{installID: "ins_minted"}, okFP, zap.NewNop())
	if err := p.EnsureForWorkspace(context.Background()); err != nil {
		t.Fatal(err)
	}
}

// The background on-created hook and the foreground first-run provision request share one flight;
// otherwise both can register a device before either managed row is visible. 后台 hook 与首启前台请求
// 必须共用一个单飞，否则双方都可能在受管行落盘前登记设备。
func TestProvisioner_CoalescesConcurrentWorkspaceProvisioning(t *testing.T) {
	started := make(chan struct{})
	release := make(chan struct{})
	inst := &fakeInstaller{installID: "ins_minted", started: started, release: release}
	keys := &fakeKeys{}
	p := NewProvisioner(keys, nil, inst, okFP, zap.NewNop())
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_same")

	ensureDone := make(chan error, 1)
	go func() { ensureDone <- p.EnsureForWorkspace(ctx) }()
	<-started

	provisionDone := make(chan struct {
		ok  bool
		err error
	}, 1)
	go func() {
		ok, err := p.ProvisionNow(ctx)
		provisionDone <- struct {
			ok  bool
			err error
		}{ok: ok, err: err}
	}()
	close(release)

	if err := <-ensureDone; err != nil {
		t.Fatal(err)
	}
	result := <-provisionDone
	if result.err != nil || !result.ok {
		t.Fatalf("coalesced foreground provision = (%v,%v), want (true,nil)", result.ok, result.err)
	}
	if inst.calls != 1 || len(keys.created) != 1 {
		t.Fatalf("concurrent provisioning installed %d times and created %d rows, want 1/1", inst.calls, len(keys.created))
	}
}

// Deleting a workspace before its async hook gets scheduled must leave a tombstone: the hook may
// wake up later, but it must not register a remote install or create a managed row for a dead root.
// 删除发生在异步 hook 尚未调度前也必须留下 tombstone：hook 即使晚醒，也不能为死 workspace
// 登记远端 install 或创建 managed 行。
func TestStopWorkspace_PreventsLateProvision(t *testing.T) {
	keys := &fakeKeys{}
	inst := &fakeInstaller{installID: "ins_should_not_exist"}
	p := NewProvisioner(keys, nil, inst, okFP, zap.NewNop())
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_deleted")

	p.StopWorkspace("ws_deleted")
	if err := p.EnsureForWorkspace(ctx); err != nil {
		t.Fatal(err)
	}
	if inst.calls != 0 || len(keys.created) != 0 {
		t.Fatalf("late hook provisioned after stop: installs=%d managedRows=%d", inst.calls, len(keys.created))
	}
}

// StopWorkspace cancels an in-flight installer and joins it before the caller can delete the
// workspace row. The cancellation path is lifecycle noise, not a provisioning warning.
// StopWorkspace 取消在途 installer 并在调用者删 workspace 行前收束；取消属于生命周期噪声，不是开通 WARN。
func TestStopWorkspace_CancelsInFlightProvision(t *testing.T) {
	started := make(chan struct{})
	release := make(chan struct{})
	inst := &fakeInstaller{installID: "ins_should_not_persist", started: started, release: release}
	keys := &fakeKeys{}
	p := NewProvisioner(keys, nil, inst, okFP, zap.NewNop())
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_deleting")

	done := make(chan error, 1)
	go func() { done <- p.EnsureForWorkspace(ctx) }()
	<-started

	stopped := make(chan struct{})
	go func() {
		p.StopWorkspace("ws_deleting")
		close(stopped)
	}()
	select {
	case <-stopped:
	case <-time.After(time.Second):
		t.Fatal("StopWorkspace did not join the cancelled provision flight")
	}
	if err := <-done; err != nil {
		t.Fatal(err)
	}
	if len(keys.created) != 0 {
		t.Fatalf("cancelled provision created %d managed rows", len(keys.created))
	}
}

// The already-provisioned path still seeds — a workspace whose managed key predates the seeding
// self-heals its NULL defaults on the next boot, using the EXISTING key's id (not a fresh install).
func TestEnsure_SeedsDefaultsOnSelfHeal(t *testing.T) {
	keys := &fakeKeys{rows: []*apikeydomain.APIKey{{ID: "aki_existing", Provider: "anselm"}}}
	defs := &fakeDefaults{}
	inst := &fakeInstaller{installID: "ins_x"}
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

// The managed key's capability archive is seeded with a hard-coded placeholder so a first boot works
// offline. If provisioning stopped there, that constant would be the ONLY thing the capability
// catalogue ever sees and every real route profile the gateway publishes would be invisible — the
// desktop would quietly govern itself by numbers compiled into its own binary.
//
// A failing probe must NOT fail provisioning (offline first boot must still yield a usable key), but
// it must not be silent either.
//
// 受管 key 的能力档案先播一份硬编码占位,使首启离线也能用。若开通到此为止,那个常量就会是能力目录**唯一**
// 见过的东西,网关真实发布的每一份 route profile 都到不了桌面端——它会悄悄按编进自己二进制的数字自治。
//
// 探针失败**不得**让开通失败(离线首启仍须产出可用的 key),但也不得无声无息。
func TestProvisionRefreshesCapabilitiesFromTheGateway(t *testing.T) {
	keys := &fakeKeys{}
	ok, err := newProv(keys, &fakeInstaller{installID: "ins_1"}, okFP).ProvisionNow(context.Background())
	if err != nil || !ok {
		t.Fatalf("provision → (%v,%v), want (true,nil)", ok, err)
	}
	if len(keys.created) != 1 {
		t.Fatalf("want one managed key, got %d", len(keys.created))
	}
	if len(keys.tested) != 1 || keys.tested[0] == "" {
		t.Fatalf("provisioning must refresh the placeholder archive with a live probe, tested=%v", keys.tested)
	}

	// A probe failure degrades, it does not abort: an offline first boot still yields a usable key.
	// 探针失败只降级、不中止:离线首启仍产出可用的 key。
	keys2 := &fakeKeys{testErr: errors.New("offline")}
	ok2, err2 := newProv(keys2, &fakeInstaller{installID: "ins_2"}, okFP).ProvisionNow(context.Background())
	if err2 != nil || !ok2 {
		t.Fatalf("a failed capability probe must not fail provisioning → (%v,%v)", ok2, err2)
	}
	if len(keys2.created) != 1 {
		t.Fatalf("the managed key must still exist after a failed probe, got %d", len(keys2.created))
	}
}
