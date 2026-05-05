// envmanager_java_test.go — pure-function unit tests for JavaEnvManager.
// Real `mvn dependency:get` belongs in the D9 pipeline suite.
//
// envmanager_java_test.go ——JavaEnvManager pure-function 单测。
// 真 `mvn dependency:get` 归 D9 pipeline 套。

package sandbox

import (
	"context"
	"os"
	"path/filepath"
	"runtime"
	"testing"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

var _ sandboxdomain.EnvManager = (*JavaEnvManager)(nil)

func TestJavaEnvManager_Kind(t *testing.T) {
	jm := NewJavaEnvManager(newFakeToolRegistry(map[string]string{"maven": "/tmp/mvn"}))
	if got := jm.Kind(); got != "java" {
		t.Errorf("Kind() = %q, want java", got)
	}
}

func TestJavaEnvManager_CreateEnv_MakesM2AndLib(t *testing.T) {
	jm := NewJavaEnvManager(newFakeToolRegistry(map[string]string{"maven": "/tmp/mvn"}))
	envPath := filepath.Join(t.TempDir(), "envs", "conv", "cv:java")
	if err := jm.CreateEnv(context.Background(), "/tmp/jdk", envPath); err != nil {
		t.Fatalf("CreateEnv: %v", err)
	}
	if _, err := os.Stat(filepath.Join(envPath, "m2")); err != nil {
		t.Errorf("m2 dir not created: %v", err)
	}
	if _, err := os.Stat(filepath.Join(envPath, "lib")); err != nil {
		t.Errorf("lib dir not created: %v", err)
	}
}

// TestJavaEnvManager_EnvBin_PointsAtRuntime confirms the documented
// asymmetry: Java envs don't have their own bin dir; EnvBin returns
// just binName so callers resolve via the JDK's PATH (runtimePath/bin).
//
// TestJavaEnvManager_EnvBin_PointsAtRuntime 确认文档化的不对称：
// Java env 没自己 bin 目录；EnvBin 只返 binName 让调用方经 JDK PATH
// （runtimePath/bin）解析。
func TestJavaEnvManager_EnvBin_ReturnsBinNameOnly(t *testing.T) {
	jm := NewJavaEnvManager(newFakeToolRegistry(map[string]string{"maven": "/tmp/mvn"}))
	got := jm.EnvBin("/data/envs/conv/cv:java", "java")
	var want string
	if runtime.GOOS == "windows" {
		want = "java.exe"
	} else {
		want = "java"
	}
	if got != want {
		t.Errorf("EnvBin = %q, want %q (Java envs have no per-env bin dir)", got, want)
	}
}
