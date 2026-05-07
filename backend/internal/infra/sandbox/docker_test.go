// docker_test.go — pure-function unit tests for DockerInstaller +
// DockerEnvManager + BuildDockerRunArgs. Real `docker pull` /
// daemon-bound integration belongs in a separate gated test (see
// requireDocker helper) — here we cover identity / no-op paths /
// path derivation / arg-list assembly.
//
// docker_test.go ——DockerInstaller + DockerEnvManager + BuildDockerRunArgs
// 的 pure-function 单测。真 `docker pull` / 绑 daemon 的集成走单独 gated
// 测试（见 requireDocker helper）；此处覆盖 identity / no-op / 路径推导 /
// arg-list 装配。

package sandbox

import (
	"context"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"go.uber.org/zap"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// ── Compile-time interface satisfaction ──────────────────────────────

var _ sandboxdomain.RuntimeInstaller = (*DockerInstaller)(nil)
var _ sandboxdomain.EnvManager = (*DockerEnvManager)(nil)

// ── DockerInstaller ──────────────────────────────────────────────────

func TestDockerInstaller_Kind(t *testing.T) {
	di := NewDockerInstaller(zap.NewNop())
	if got := di.Kind(); got != "docker" {
		t.Errorf("Kind() = %q, want docker", got)
	}
}

func TestDockerInstaller_ListAvailable_Nil(t *testing.T) {
	di := NewDockerInstaller(zap.NewNop())
	got, err := di.ListAvailable(context.Background())
	if err != nil {
		t.Fatalf("ListAvailable: %v", err)
	}
	if got != nil {
		t.Errorf("ListAvailable = %v, want nil", got)
	}
}

func TestDockerInstaller_ResolveDefault_Empty(t *testing.T) {
	di := NewDockerInstaller(zap.NewNop())
	got, err := di.ResolveDefault(context.Background())
	if err != nil {
		t.Fatalf("ResolveDefault: %v", err)
	}
	if got != "" {
		t.Errorf("ResolveDefault = %q, want empty (docker version comes from user-installed daemon)", got)
	}
}

func TestDockerInstaller_Locate_ReturnsSystemDocker(t *testing.T) {
	di := NewDockerInstaller(zap.NewNop())
	bin, err := di.Locate("any", "/tmp/sandbox")
	if err != nil {
		t.Fatalf("Locate: %v", err)
	}
	if bin != "docker" {
		t.Errorf("Locate = %q, want docker (system PATH)", bin)
	}
}

func TestDockerInstaller_NewWithNilLog_Panics(t *testing.T) {
	defer func() {
		if r := recover(); r == nil {
			t.Error("expected panic on nil logger")
		}
	}()
	_ = NewDockerInstaller(nil)
}

// ── DockerEnvManager ─────────────────────────────────────────────────

func TestDockerEnvManager_Kind(t *testing.T) {
	em := NewDockerEnvManager(zap.NewNop())
	if got := em.Kind(); got != "docker" {
		t.Errorf("Kind() = %q, want docker", got)
	}
}

func TestDockerEnvManager_CreateEnv_MakesDir(t *testing.T) {
	tmp := t.TempDir()
	envPath := filepath.Join(tmp, "envs", "mcp", "test-server")
	em := NewDockerEnvManager(zap.NewNop())

	if err := em.CreateEnv(context.Background(), "/unused/runtime", envPath); err != nil {
		t.Fatalf("CreateEnv: %v", err)
	}

	info, err := os.Stat(envPath)
	if err != nil {
		t.Fatalf("stat envPath: %v", err)
	}
	if !info.IsDir() {
		t.Errorf("envPath %s is not a directory", envPath)
	}
}

func TestDockerEnvManager_CreateEnv_Idempotent(t *testing.T) {
	tmp := t.TempDir()
	envPath := filepath.Join(tmp, "env")
	em := NewDockerEnvManager(zap.NewNop())
	if err := em.CreateEnv(context.Background(), "", envPath); err != nil {
		t.Fatalf("CreateEnv #1: %v", err)
	}
	if err := em.CreateEnv(context.Background(), "", envPath); err != nil {
		t.Fatalf("CreateEnv #2 (idempotent): %v", err)
	}
}

func TestDockerEnvManager_InstallDeps_NoDeps_NoError(t *testing.T) {
	em := NewDockerEnvManager(zap.NewNop())
	if err := em.InstallDeps(context.Background(), "", "", nil, nil); err != nil {
		t.Errorf("empty deps should be no-op: %v", err)
	}
	if err := em.InstallDeps(context.Background(), "", "", []string{}, nil); err != nil {
		t.Errorf("zero-len deps should be no-op: %v", err)
	}
}

func TestDockerEnvManager_InstallExtras_AlwaysNil(t *testing.T) {
	em := NewDockerEnvManager(zap.NewNop())
	if err := em.InstallExtras(context.Background(), "", "", []string{"anything"}, nil); err != nil {
		t.Errorf("InstallExtras should be no-op for docker: %v", err)
	}
}

func TestDockerEnvManager_EnvBin_ReturnsSystemDocker(t *testing.T) {
	em := NewDockerEnvManager(zap.NewNop())
	got := em.EnvBin("/sandboxes/env-1", "anything")
	if got != "docker" {
		t.Errorf("EnvBin = %q, want docker (binName arg ignored — caller builds full args via BuildDockerRunArgs)", got)
	}
}

func TestDockerEnvManager_EnvDir_PassesThrough(t *testing.T) {
	em := NewDockerEnvManager(zap.NewNop())
	got := em.EnvDir("/sandboxes/env-1")
	if got != "/sandboxes/env-1" {
		t.Errorf("EnvDir = %q, want pass-through", got)
	}
}

func TestDockerEnvManager_NewWithNilLog_Panics(t *testing.T) {
	defer func() {
		if r := recover(); r == nil {
			t.Error("expected panic on nil logger")
		}
	}()
	_ = NewDockerEnvManager(nil)
}

// ── BuildDockerRunArgs ───────────────────────────────────────────────

func TestBuildDockerRunArgs_Minimal(t *testing.T) {
	got := BuildDockerRunArgs("/host/env", "alpine:latest", nil, nil)
	want := []string{
		"run", "-i", "--rm",
		"-v", "/host/env:/workspace",
		"alpine:latest",
	}
	assertStringSlicesEqual(t, got, want)
}

func TestBuildDockerRunArgs_WithEnvVars(t *testing.T) {
	got := BuildDockerRunArgs(
		"/host/env",
		"mcp/server:1.0",
		[]string{"API_KEY=secret", "DEBUG=1"},
		nil,
	)
	want := []string{
		"run", "-i", "--rm",
		"-v", "/host/env:/workspace",
		"-e", "API_KEY=secret",
		"-e", "DEBUG=1",
		"mcp/server:1.0",
	}
	assertStringSlicesEqual(t, got, want)
}

func TestBuildDockerRunArgs_WithServerArgs(t *testing.T) {
	got := BuildDockerRunArgs(
		"/env",
		"mcp/sqlite:v2",
		nil,
		[]string{"--db-path", "/workspace/data.db"},
	)
	want := []string{
		"run", "-i", "--rm",
		"-v", "/env:/workspace",
		"mcp/sqlite:v2",
		"--db-path", "/workspace/data.db",
	}
	assertStringSlicesEqual(t, got, want)
}

func TestBuildDockerRunArgs_OrderEnvBeforeImageBeforeArgs(t *testing.T) {
	// Verifies the canonical ordering — env flags before image, server
	// args after image. Wrong order would either lose env vars (if put
	// after image, docker treats them as server args) or feed env to a
	// non-existent server (image-after-args breaks the invocation).
	//
	// 验证规范顺序——env flag 在 image 前，server args 在 image 后。错序
	// 会丢 env vars（在 image 后被当 server args）或喂 env 给不存在的 server。
	got := BuildDockerRunArgs("/e", "img", []string{"K=V"}, []string{"--flag"})
	imageIdx := indexOf(got, "img")
	envIdx := indexOf(got, "K=V")
	flagIdx := indexOf(got, "--flag")
	if envIdx < 0 || imageIdx < 0 || flagIdx < 0 {
		t.Fatalf("expected all tokens present: %v", got)
	}
	if envIdx >= imageIdx {
		t.Errorf("env var %d not before image %d", envIdx, imageIdx)
	}
	if flagIdx <= imageIdx {
		t.Errorf("server arg %d not after image %d", flagIdx, imageIdx)
	}
}

// ── helpers ──────────────────────────────────────────────────────────

func TestDockerWorkspaceMountConst(t *testing.T) {
	// Defend against accidental rename — downstream marketplace adapter
	// hardcodes /workspace in volume mount paths it constructs.
	// 防意外改名——下游 marketplace adapter 在拼挂卷路径时硬编码 /workspace。
	if DockerWorkspaceMount != "/workspace" {
		t.Errorf("DockerWorkspaceMount = %q, want /workspace", DockerWorkspaceMount)
	}
}

func TestDockerInstallGuide_PerPlatform(t *testing.T) {
	got := dockerInstallGuide()
	if got == "" {
		t.Fatal("dockerInstallGuide returned empty string")
	}
	switch runtime.GOOS {
	case "darwin":
		if !strings.Contains(got, "Docker Desktop") || !strings.Contains(got, "mac") {
			t.Errorf("darwin guide should mention Docker Desktop + mac, got: %q", got)
		}
	case "windows":
		if !strings.Contains(got, "Docker Desktop") || !strings.Contains(got, "windows") {
			t.Errorf("windows guide should mention Docker Desktop + windows, got: %q", got)
		}
	case "linux":
		if !strings.Contains(got, "Docker Engine") || !strings.Contains(got, "usermod") {
			t.Errorf("linux guide should mention Docker Engine + usermod, got: %q", got)
		}
	}
}

func TestDockerStartGuide_NotEmpty(t *testing.T) {
	got := dockerStartGuide()
	if got == "" {
		t.Error("dockerStartGuide returned empty string")
	}
}

// ── small test helpers (file-local to keep package-wide helpers minimal) ──

func assertStringSlicesEqual(t *testing.T, got, want []string) {
	t.Helper()
	if len(got) != len(want) {
		t.Errorf("length: got %d, want %d\ngot:  %v\nwant: %v", len(got), len(want), got, want)
		return
	}
	for i := range got {
		if got[i] != want[i] {
			t.Errorf("[%d]: got %q, want %q\nfull got:  %v\nfull want: %v", i, got[i], want[i], got, want)
		}
	}
}

func indexOf(s []string, target string) int {
	for i, v := range s {
		if v == target {
			return i
		}
	}
	return -1
}
