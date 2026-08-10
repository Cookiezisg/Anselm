package sandbox

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
)

// TestDestroy_RejectsRunningEnv keeps a resident process and its manifest intact.
// 删除仍有常驻进程的 env 必须保留进程/目录/manifest，不能静默杀进程或删目录。
func TestDestroy_RejectsRunningEnv(t *testing.T) {
	svc, owner := newServiceWithEnv(t, "fake-py")
	ctx := context.Background()
	if err := svc.repo.SetEnvRunningPID(ctx, "se_test", 4242); err != nil {
		t.Fatalf("set running pid: %v", err)
	}

	err := svc.Destroy(ctx, owner)
	if !errors.Is(err, sandboxdomain.ErrEnvInUse) {
		t.Fatalf("Destroy running env: %v, want ErrEnvInUse", err)
	}
	env, err := svc.repo.GetEnv(ctx, "se_test")
	if err != nil {
		t.Fatalf("running env disappeared after rejected Destroy: %v", err)
	}
	if env.RunningPID != 4242 {
		t.Fatalf("running pid changed after rejected Destroy: %d", env.RunningPID)
	}
	if !svc.HasOwnerLockForTest(owner) {
		t.Fatal("owner lock must remain while the env is still resident")
	}

	if err := svc.repo.ClearEnvRunningPID(ctx, "se_test"); err != nil {
		t.Fatalf("clear running pid: %v", err)
	}
	if err := svc.Destroy(ctx, owner); err != nil {
		t.Fatalf("Destroy after process stopped: %v", err)
	}
}

// TestDestroyOwners_PreflightsRunningEnvBeforeDeletingSibling keeps a batch atomic with
// respect to the explicit resident-process guard: a running sibling must reject reset-all
// before an idle sibling is removed.
//
// 批量 reset-all 若遇到常驻 sibling，必须在删除任何空闲 sibling 前拒绝，不能留下半成功状态。
func TestDestroyOwners_PreflightsRunningEnvBeforeDeletingSibling(t *testing.T) {
	svc, first := newServiceWithEnv(t, "fake-py")
	second := sandboxdomain.Owner{Kind: sandboxdomain.OwnerKindFunction, ID: "fn_second"}
	secondPath := filepath.Join("envs", second.Kind, second.ID)
	if err := svc.repo.CreateEnv(context.Background(), &sandboxdomain.Env{
		ID: "se_second", OwnerKind: second.Kind, OwnerID: second.ID, RuntimeID: "sr_test",
		Path: secondPath, Status: sandboxdomain.EnvStatusReady, LastUsedAt: time.Now(),
	}); err != nil {
		t.Fatalf("seed sibling env: %v", err)
	}
	if err := os.MkdirAll(filepath.Join(svc.SandboxRoot(), secondPath), 0o755); err != nil {
		t.Fatalf("mkdir sibling env path: %v", err)
	}
	if err := svc.repo.SetEnvRunningPID(context.Background(), "se_second", 4242); err != nil {
		t.Fatalf("set sibling running pid: %v", err)
	}

	removed, err := svc.DestroyOwners(context.Background(), []sandboxdomain.Owner{first, second})
	if !errors.Is(err, sandboxdomain.ErrEnvInUse) {
		t.Fatalf("DestroyOwners running sibling: %v, want ErrEnvInUse", err)
	}
	if removed != 0 {
		t.Fatalf("DestroyOwners removed %d before rejecting running sibling, want 0", removed)
	}
	for _, id := range []string{"se_test", "se_second"} {
		if _, getErr := svc.repo.GetEnv(context.Background(), id); getErr != nil {
			t.Fatalf("env %s disappeared after rejected batch: %v", id, getErr)
		}
	}

	if err := svc.repo.ClearEnvRunningPID(context.Background(), "se_second"); err != nil {
		t.Fatalf("clear sibling running pid: %v", err)
	}
	removed, err = svc.DestroyOwners(context.Background(), []sandboxdomain.Owner{first, second})
	if err != nil || removed != 2 {
		t.Fatalf("DestroyOwners after stop = removed %d, err %v; want 2,nil", removed, err)
	}
}

// TestDestroy_EvictsOwnerLock — R7: the per-owner keyed mutex in envLocks must be
// deleted when the env is destroyed, else the map grows one *sync.Mutex per distinct
// entity for the whole process lifetime (owner IDs never recur). Destroying an env
// (and destroying a never-existed owner) must both leave envLocks empty for that key.
func TestDestroy_EvictsOwnerLock(t *testing.T) {
	svc, owner := newServiceWithEnv(t, "fake-py")
	ctx := context.Background()

	// Take the lock once via the public path so the entry exists, then destroy.
	// 经公开路径取一次锁使条目存在，再 Destroy。
	svc.ownerLock(owner)
	if !svc.HasOwnerLockForTest(owner) {
		t.Fatalf("baseline: owner lock missing before Destroy")
	}

	if err := svc.Destroy(ctx, owner); err != nil {
		t.Fatalf("Destroy: %v", err)
	}
	if svc.HasOwnerLockForTest(owner) {
		t.Errorf("owner lock still in envLocks after Destroy — R7 leak not fixed")
	}

	// Destroying an owner with no env (ErrEnvNotFound path) must also evict the lock the
	// lookup minted, so a probe-then-destroy of a never-materialized owner doesn't leak.
	// 删除无 env 的 owner（ErrEnvNotFound 分支）也须逐出 lookup 铸出的锁。
	ghost := sandboxdomain.Owner{Kind: sandboxdomain.OwnerKindMCP, ID: "mcp_ghost"}
	svc.ownerLock(ghost)
	if err := svc.Destroy(ctx, ghost); err != nil {
		t.Fatalf("Destroy ghost: %v", err)
	}
	if svc.HasOwnerLockForTest(ghost) {
		t.Errorf("ghost owner lock still in envLocks after Destroy — R7 leak not fixed")
	}
}
