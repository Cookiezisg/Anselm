// envmanager_ruby_test.go — pure-function unit tests for RubyEnvManager.
// Real `bundle add` belongs in the D9 pipeline suite.
//
// envmanager_ruby_test.go ——RubyEnvManager pure-function 单测。
// 真 `bundle add` 归 D9 pipeline 套。

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

var _ sandboxdomain.EnvManager = (*RubyEnvManager)(nil)

func TestRubyEnvManager_Kind(t *testing.T) {
	rm := NewRubyEnvManager(newFakeToolRegistry(map[string]string{"bundler": "/tmp/bundle"}))
	if got := rm.Kind(); got != "ruby" {
		t.Errorf("Kind() = %q, want ruby", got)
	}
}

func TestRubyEnvManager_CreateEnv_WritesGemfile(t *testing.T) {
	rm := NewRubyEnvManager(newFakeToolRegistry(map[string]string{"bundler": "/tmp/bundle"}))
	envPath := filepath.Join(t.TempDir(), "envs", "conv", "cv:ruby")
	if err := rm.CreateEnv(context.Background(), "/tmp/ruby", envPath); err != nil {
		t.Fatalf("CreateEnv: %v", err)
	}
	if _, err := os.Stat(filepath.Join(envPath, "bundle")); err != nil {
		t.Errorf("bundle dir not created: %v", err)
	}
	gemfile, err := os.ReadFile(filepath.Join(envPath, "Gemfile"))
	if err != nil {
		t.Fatalf("read Gemfile: %v", err)
	}
	if !strings.Contains(string(gemfile), "rubygems.org") {
		t.Errorf("Gemfile missing rubygems.org source: %s", gemfile)
	}
}

func TestRubyEnvManager_EnvBin_PerOS(t *testing.T) {
	rm := NewRubyEnvManager(newFakeToolRegistry(map[string]string{"bundler": "/tmp/bundle"}))
	got := rm.EnvBin("/data/envs/conv/cv:ruby", "rake")
	var want string
	if runtime.GOOS == "windows" {
		want = "/data/envs/conv/cv:ruby/bundle/bin/rake.bat"
	} else {
		want = "/data/envs/conv/cv:ruby/bundle/bin/rake"
	}
	if got != want {
		t.Errorf("EnvBin = %q, want %q", got, want)
	}
}
