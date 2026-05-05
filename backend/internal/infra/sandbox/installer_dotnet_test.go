// installer_dotnet_test.go — pure-function unit tests for DotnetInstaller.
// Real Microsoft install script download + execution belong in the D9
// pipeline suite (downloads ~200 MB of .NET SDK).
//
// installer_dotnet_test.go ——DotnetInstaller pure-function 单测。
// 真微软 install 脚本下载 + 执行归 D9 pipeline 套（下 ~200 MB .NET SDK）。

package sandbox

import (
	"context"
	"path/filepath"
	"runtime"
	"testing"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

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
