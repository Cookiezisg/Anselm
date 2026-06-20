package handler

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	sandboxapp "github.com/sunweilin/anselm/backend/internal/app/sandbox"
	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
)

// SandboxAdapter satisfies SandboxRunner by writing each version's code files and
// delegating the long-lived spawn + cleanup to sandboxapp.Service. Env materialization
// is NOT here — that goes through envfix.Provisioner.
//
// SandboxAdapter 写每个版本的代码文件、把长跑 spawn + 清理委托 sandboxapp.Service，满足
// SandboxRunner。env 物化不在此——走 envfix.Provisioner。
type SandboxAdapter struct {
	svc     *sandboxapp.Service
	dataDir string
}

// NewSandboxAdapter binds the adapter to a sandbox service + the handler data root.
func NewSandboxAdapter(svc *sandboxapp.Service, dataDir string) *SandboxAdapter {
	return &SandboxAdapter{svc: svc, dataDir: dataDir}
}

var _ SandboxRunner = (*SandboxAdapter)(nil)

func (a *SandboxAdapter) Ready() bool { return a.svc.IsReady() }

// Spawn writes user_handler.py (classCode) + driver.py, then starts the long-lived
// `python driver.py` in owner's venv. driver.py imports user_handler from the same dir
// (Python puts the script's dir on sys.path[0]).
//
// Spawn 写 user_handler.py（classCode）+ driver.py，再在 owner 的 venv 里起长跑 `python
// driver.py`。driver.py 从同目录 import user_handler（Python 把脚本目录放 sys.path[0]）。
func (a *SandboxAdapter) Spawn(ctx context.Context, owner sandboxdomain.Owner, handlerID, versionID, classCode string) (sandboxdomain.LongLivedHandle, error) {
	verDir := a.versionDir(handlerID, versionID)
	if err := os.MkdirAll(verDir, 0o755); err != nil {
		return nil, fmt.Errorf("handlerapp.SandboxAdapter.Spawn: mkdir: %w", err)
	}
	if err := writeAtomic(filepath.Join(verDir, "user_handler.py"), []byte(classCode), 0o644); err != nil {
		return nil, fmt.Errorf("handlerapp.SandboxAdapter.Spawn: write user_handler.py: %w", err)
	}
	driverPath := filepath.Join(verDir, "driver.py")
	if err := writeAtomic(driverPath, []byte(DriverScript), 0o644); err != nil {
		return nil, fmt.Errorf("handlerapp.SandboxAdapter.Spawn: write driver.py: %w", err)
	}
	handle, err := a.svc.SpawnLongLived(ctx, owner, sandboxdomain.SpawnOpts{
		Cmd:       "python",
		Args:      []string{driverPath},
		LongLived: true,
	})
	if err != nil {
		return nil, err // ErrEnvNotFound propagates so the Service can rebuild + retry
	}
	return handle, nil
}

// Destroy removes every env owned by the handler and its on-disk code dir.
func (a *SandboxAdapter) Destroy(ctx context.Context, handlerID string) error {
	envs, err := a.svc.ListEnvs(ctx, sandboxdomain.OwnerKindHandler)
	if err != nil {
		return fmt.Errorf("handlerapp.SandboxAdapter.Destroy: list envs: %w", err)
	}
	prefix := handlerID + "_"
	for _, e := range envs {
		if !strings.HasPrefix(e.OwnerID, prefix) {
			continue
		}
		if err := a.svc.Destroy(ctx, sandboxdomain.Owner{Kind: sandboxdomain.OwnerKindHandler, ID: e.OwnerID}); err != nil {
			return fmt.Errorf("handlerapp.SandboxAdapter.Destroy %s: %w", e.OwnerID, err)
		}
	}
	if err := os.RemoveAll(filepath.Join(a.dataDir, "handlers", handlerID)); err != nil {
		return fmt.Errorf("handlerapp.SandboxAdapter.Destroy: rm code dir: %w", err)
	}
	return nil
}

// DestroyEnv reclaims one per-version env by owner key (delegates to the sandbox service,
// which no-ops if the env was never materialized).
//
// DestroyEnv 按 owner key 回收单个 per-version env（委托 sandbox service，env 从未物化则 no-op）。
func (a *SandboxAdapter) DestroyEnv(ctx context.Context, owner sandboxdomain.Owner) error {
	return a.svc.Destroy(ctx, owner)
}

func (a *SandboxAdapter) versionDir(handlerID, versionID string) string {
	return filepath.Join(a.dataDir, "handlers", handlerID, "versions", versionID)
}

// writeAtomic writes via a unique temp file + rename so concurrent writers never collide.
func writeAtomic(path string, data []byte, mode os.FileMode) error {
	dir, base := filepath.Split(path)
	f, err := os.CreateTemp(dir, base+".*.tmp")
	if err != nil {
		return err
	}
	tmp := f.Name()
	if _, err := f.Write(data); err != nil {
		f.Close()
		os.Remove(tmp)
		return err
	}
	if err := f.Chmod(mode); err != nil {
		f.Close()
		os.Remove(tmp)
		return err
	}
	if err := f.Close(); err != nil {
		os.Remove(tmp)
		return err
	}
	if err := os.Rename(tmp, path); err != nil {
		os.Remove(tmp)
		return err
	}
	return nil
}
