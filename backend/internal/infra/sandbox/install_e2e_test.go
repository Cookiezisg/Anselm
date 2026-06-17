//go:build e2e

package sandbox

import (
	"context"
	"os"
	"os/exec"
	"strings"
	"testing"

	sandboxdomain "github.com/sunweilin/anselm/backend/internal/domain/sandbox"
)

// TestE2E_DirectInstall actually downloads each runtime into a temp sandbox and execs it, proving the
// self-built directInstaller's download → checksum → extract → layout → run path works on a real
// host. dotnet is skipped by default (226 MB); set ANSELM_E2E_DOTNET=1 to include it.
//
// Run: go test -tags e2e -run TestE2E_DirectInstall -v -timeout 600s ./internal/infra/sandbox/
//
// TestE2E_DirectInstall 真把每个运行时下到临时 sandbox 并执行，证明自研 directInstaller 的
// 下载→校验→解压→布局→运行 整条链在真机可用。dotnet 默认跳过（226MB），ANSELM_E2E_DOTNET=1 纳入。
func TestE2E_DirectInstall(t *testing.T) {
	root := t.TempDir()
	ctx := context.Background()

	byKind := map[string]sandboxdomain.RuntimeInstaller{}
	for _, in := range DirectInstallers() {
		byKind[in.Kind()] = in
	}

	run := func(kind, version string, args ...string) {
		t.Run(kind, func(t *testing.T) {
			in := byKind[kind]
			rel, err := in.Install(ctx, version, root, nil)
			if err != nil {
				t.Fatalf("install %s@%s: %v", kind, version, err)
			}
			bin, err := in.Locate(version, root)
			if err != nil {
				t.Fatalf("locate %s@%s: %v", kind, version, err)
			}
			t.Logf("%s installed → %s (bin %s)", kind, rel, bin)

			out, err := exec.CommandContext(ctx, bin, args...).CombinedOutput()
			if err != nil {
				t.Fatalf("%s exec %v: %v (output: %s)", kind, args, err, out)
			}
			t.Logf("%s %v → %s", kind, args, strings.TrimSpace(string(out)))

			// Idempotent: a second Install short-circuits (binary already present).
			if _, err := in.Install(ctx, version, root, nil); err != nil {
				t.Fatalf("%s re-install (idempotent) failed: %v", kind, err)
			}
		})
	}

	run("uv", "0.11.4", "--version")
	run("node", "22", "--version")
	run("python", "3.12", "--version")

	// dotnet (226 MB) is validated on demand: ANSELM_E2E_DOTNET=1 go test -tags e2e ...
	// dotnet（226MB）按需验证：ANSELM_E2E_DOTNET=1 go test -tags e2e ...
	if os.Getenv("ANSELM_E2E_DOTNET") == "1" {
		run("dotnet", "10.0.300", "--version")
	}
}
