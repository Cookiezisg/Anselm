// envmanager_python_test.go — pure-function unit tests for PythonEnvManager.
//
// Path-derivation logic (EnvBin / EnvDir, per-OS subdirs and exe suffixes)
// is the bulk of what's testable without spawning uv. Real CreateEnv /
// InstallDeps belong in the pipeline test suite — they shell out to uv
// and write venvs to disk.
//
// envmanager_python_test.go ——PythonEnvManager 的 pure-function 单测。
//
// 路径推导逻辑（EnvBin / EnvDir，per-OS 子目录与 exe 后缀）是不起 uv 能测
// 的主要部分。真 CreateEnv / InstallDeps 归 pipeline 测试套——会 shell out
// 到 uv 并往磁盘写 venv。

package sandbox

import (
	"runtime"
	"testing"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// compile-time interface satisfaction check.
var _ sandboxdomain.EnvManager = (*PythonEnvManager)(nil)

func TestPythonEnvManager_Kind(t *testing.T) {
	pm := NewPythonEnvManager("/tmp/uv")
	if got := pm.Kind(); got != "python" {
		t.Errorf("Kind() = %q, want python", got)
	}
}

func TestPythonEnvManager_EnvBin_PerOS(t *testing.T) {
	pm := NewPythonEnvManager("/tmp/uv")
	got := pm.EnvBin("/data/envs/forge/abc", "python")

	var want string
	if runtime.GOOS == "windows" {
		want = "/data/envs/forge/abc/.venv/Scripts/python.exe"
	} else {
		want = "/data/envs/forge/abc/.venv/bin/python"
	}
	if got != want {
		t.Errorf("EnvBin = %q, want %q", got, want)
	}
}

// TestPythonEnvManager_EnvBin_PreservesExplicitExtension confirms that
// callers passing an explicit extension (e.g. "uvicorn.exe") aren't
// double-suffixed on Windows.
//
// TestPythonEnvManager_EnvBin_PreservesExplicitExtension 确认调用方传带
// 显式扩展名（如 "uvicorn.exe"）时 Windows 不会被重复加后缀。
func TestPythonEnvManager_EnvBin_PreservesExplicitExtension(t *testing.T) {
	pm := NewPythonEnvManager("/tmp/uv")
	got := pm.EnvBin("/data/envs/forge/abc", "uvicorn.exe")

	var want string
	if runtime.GOOS == "windows" {
		want = "/data/envs/forge/abc/.venv/Scripts/uvicorn.exe"
	} else {
		want = "/data/envs/forge/abc/.venv/bin/uvicorn.exe"
	}
	if got != want {
		t.Errorf("EnvBin = %q, want %q", got, want)
	}
}

func TestPythonEnvManager_EnvDir_ReturnsInputUnchanged(t *testing.T) {
	pm := NewPythonEnvManager("/tmp/uv")
	if got := pm.EnvDir("/data/envs/conv/cv_abc:python"); got != "/data/envs/conv/cv_abc:python" {
		t.Errorf("EnvDir = %q, want input unchanged", got)
	}
}
