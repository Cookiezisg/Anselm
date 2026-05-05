// envmanager_php_test.go — pure-function unit tests for PHPEnvManager.
// Real `composer require` belongs in the D9 pipeline suite.
//
// envmanager_php_test.go ——PHPEnvManager pure-function 单测。
// 真 `composer require` 归 D9 pipeline 套。

package sandbox

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"testing"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

var _ sandboxdomain.EnvManager = (*PHPEnvManager)(nil)

func TestPHPEnvManager_Kind(t *testing.T) {
	pm := NewPHPEnvManager("/tmp/composer")
	if got := pm.Kind(); got != "php" {
		t.Errorf("Kind() = %q, want php", got)
	}
}

func TestPHPEnvManager_CreateEnv_WritesComposerJSON(t *testing.T) {
	pm := NewPHPEnvManager("/tmp/composer")
	envPath := filepath.Join(t.TempDir(), "envs", "conv", "cv:php")
	if err := pm.CreateEnv(context.Background(), "/tmp/php", envPath); err != nil {
		t.Fatalf("CreateEnv: %v", err)
	}
	if _, err := os.Stat(filepath.Join(envPath, ".composer")); err != nil {
		t.Errorf(".composer dir not created: %v", err)
	}
	data, err := os.ReadFile(filepath.Join(envPath, "composer.json"))
	if err != nil {
		t.Fatalf("read composer.json: %v", err)
	}
	var manifest map[string]any
	if err := json.Unmarshal(data, &manifest); err != nil {
		t.Fatalf("composer.json invalid JSON: %v", err)
	}
	name, _ := manifest["name"].(string)
	if name != "forgify/env-cv:php" {
		t.Errorf("manifest name = %q, want forgify/env-cv:php", name)
	}
}

func TestPHPEnvManager_EnvBin_PerOS(t *testing.T) {
	pm := NewPHPEnvManager("/tmp/composer")
	got := pm.EnvBin("/data/envs/conv/cv:php", "phpunit")
	var want string
	if runtime.GOOS == "windows" {
		want = "/data/envs/conv/cv:php/vendor/bin/phpunit.bat"
	} else {
		want = "/data/envs/conv/cv:php/vendor/bin/phpunit"
	}
	if got != want {
		t.Errorf("EnvBin = %q, want %q", got, want)
	}
}
