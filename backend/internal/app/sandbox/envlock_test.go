package sandbox

import (
	"context"
	"testing"

	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
)

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
