// dotnet_test.go — pure-function unit tests for DotnetInstaller +
// DotnetEnvManager. Real install-script download / execution and
// `dotnet add package` belong in the D9 pipeline suite.
//
// dotnet_test.go ——DotnetInstaller + DotnetEnvManager 的 pure-function 单测。
// 真 install 脚本下载/执行 和 `dotnet add package` 归 D9 pipeline 套。

package sandbox

import (
	"context"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// ── DotnetInstaller ──────────────────────────────────────────────────

var _ sandboxdomain.RuntimeInstaller = (*DotnetInstaller)(nil)

func TestDotnetInstaller_Kind(t *testing.T) {
	di := NewDotnetInstaller("8.0")
	if got := di.Kind(); got != "dotnet" {
		t.Errorf("Kind() = %q, want dotnet", got)
	}
}

func TestDotnetInstaller_ResolveDefault_ReturnsConstructionVersion(t *testing.T) {
	for _, v := range []string{"8.0", "9.0", "LTS", ""} {
		di := NewDotnetInstaller(v)
		got, err := di.ResolveDefault(context.Background())
		if err != nil {
			t.Errorf("ResolveDefault(%q): %v", v, err)
			continue
		}
		if got != v {
			t.Errorf("ResolveDefault(%q) = %q, want %q", v, got, v)
		}
	}
}

func TestDotnetInstaller_ListAvailable_Nil(t *testing.T) {
	di := NewDotnetInstaller("8.0")
	got, err := di.ListAvailable(context.Background())
	if err != nil {
		t.Fatalf("ListAvailable: %v", err)
	}
	if got != nil {
		t.Errorf("ListAvailable: want nil (UI shows curated set), got %v", got)
	}
}

func TestDotnetInstaller_Locate_PerOS(t *testing.T) {
	di := NewDotnetInstaller("8.0")
	got, err := di.Locate("8.0", "/data/sandbox")
	if err != nil {
		t.Fatalf("Locate: %v", err)
	}
	binName := "dotnet"
	if runtime.GOOS == "windows" {
		binName = "dotnet.exe"
	}
	want := filepath.Join("/data/sandbox", dotnetInstallsSubdir, "8.0", binName)
	if got != want {
		t.Errorf("Locate = %q, want %q", got, want)
	}
}

// ── DotnetEnvManager ─────────────────────────────────────────────────

var _ sandboxdomain.EnvManager = (*DotnetEnvManager)(nil)

func TestDotnetEnvManager_Kind(t *testing.T) {
	dm := NewDotnetEnvManager()
	if got := dm.Kind(); got != "dotnet" {
		t.Errorf("Kind() = %q, want dotnet", got)
	}
}

func TestDotnetEnvManager_CreateEnv_WritesScaffolding(t *testing.T) {
	dm := NewDotnetEnvManager()
	envPath := filepath.Join(t.TempDir(), "envs", "conv", "cv:dotnet")
	if err := dm.CreateEnv(context.Background(), "/tmp/dotnet", envPath); err != nil {
		t.Fatalf("CreateEnv: %v", err)
	}

	csproj, err := os.ReadFile(filepath.Join(envPath, "env.csproj"))
	if err != nil {
		t.Fatalf("read env.csproj: %v", err)
	}
	if !strings.Contains(string(csproj), "Microsoft.NET.Sdk") {
		t.Errorf("env.csproj missing Microsoft.NET.Sdk: %s", csproj)
	}

	nugetCfg, err := os.ReadFile(filepath.Join(envPath, "nuget.config"))
	if err != nil {
		t.Fatalf("read nuget.config: %v", err)
	}
	if !strings.Contains(string(nugetCfg), "globalPackagesFolder") {
		t.Errorf("nuget.config missing globalPackagesFolder: %s", nugetCfg)
	}
	if !strings.Contains(string(nugetCfg), "./packages") {
		t.Errorf("nuget.config not pinned to ./packages (env-local): %s", nugetCfg)
	}

	if _, err := os.Stat(filepath.Join(envPath, ".dotnet")); err != nil {
		t.Errorf(".dotnet CLI home dir not created: %v", err)
	}
}

func TestDotnetEnvManager_EnvBin_ReturnsBinNameOnly(t *testing.T) {
	dm := NewDotnetEnvManager()
	got := dm.EnvBin("/data/envs/conv/cv:dotnet", "dotnet")
	var want string
	if runtime.GOOS == "windows" {
		want = "dotnet.exe"
	} else {
		want = "dotnet"
	}
	if got != want {
		t.Errorf("EnvBin = %q, want %q (.NET envs have no per-env bin dir)", got, want)
	}
}
