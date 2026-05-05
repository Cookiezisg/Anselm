// envmanager_dotnet_test.go — pure-function unit tests for
// DotnetEnvManager. Real `dotnet add package` belongs in D9 pipeline.
//
// envmanager_dotnet_test.go ——DotnetEnvManager pure-function 单测。
// 真 `dotnet add package` 归 D9 pipeline。

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
