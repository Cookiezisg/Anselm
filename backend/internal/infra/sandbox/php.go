// envmanager_php.go — Composer-backed EnvManager for PHP plugin envs.
//
// Per-env isolation strategy:
//
//   - composer --working-dir=<envPath>  → all package operations target
//     <envPath>/composer.json + <envPath>/vendor/.
//   - COMPOSER_HOME=<envPath>/.composer  → cache + global config local
//     to env (no fallback to ~/.composer/).
//
// envmanager_php.go ——基于 Composer 的 PHP plugin env EnvManager。
//
// 隔离策略：composer --working-dir=<envPath> 让所有包操作针对
// <envPath>/composer.json + <envPath>/vendor/。COMPOSER_HOME=<envPath>/.composer
// 让 cache + 全局 config 本地化（不 fallback 到 ~/.composer/）。

package sandbox

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// PHPEnvManager satisfies sandboxdomain.EnvManager for PHP.
//
// PHPEnvManager 满足 sandboxdomain.EnvManager 的 PHP 实现。
type PHPEnvManager struct {
	tools sandboxdomain.ToolRegistry // resolves composer binary lazily on first use
}

// NewPHPEnvManager constructs the manager. tools must be a working
// ToolRegistry; PHPEnvManager calls tools.EnsureTool(ctx, "composer", "")
// whenever it needs the composer CLI.
//
// NewPHPEnvManager 构造 manager。tools 必须是可工作的 ToolRegistry；
// PHPEnvManager 需要 composer CLI 时调 tools.EnsureTool(ctx, "composer", "")。
func NewPHPEnvManager(tools sandboxdomain.ToolRegistry) *PHPEnvManager {
	return &PHPEnvManager{tools: tools}
}

// Kind reports the dispatch key.
//
// Kind 报告派发键。
func (p *PHPEnvManager) Kind() string { return "php" }

// CreateEnv writes a minimal composer.json if absent and mkdirs
// envPath/.composer (COMPOSER_HOME). Idempotent.
//
// CreateEnv 不存在时写最小 composer.json + mkdir envPath/.composer
// （COMPOSER_HOME）。幂等。
func (p *PHPEnvManager) CreateEnv(ctx context.Context, runtimePath, envPath string) error {
	composerJSON := filepath.Join(envPath, "composer.json")
	composerHome := filepath.Join(envPath, ".composer")
	if _, err := os.Stat(composerJSON); err == nil {
		return nil
	}
	if err := os.MkdirAll(composerHome, 0o755); err != nil {
		return fmt.Errorf("sandbox.PHPEnvManager.CreateEnv: mkdir composer home: %w (env: %w)", err, sandboxdomain.ErrEnvCreateFailed)
	}
	if err := os.MkdirAll(envPath, 0o755); err != nil {
		return fmt.Errorf("sandbox.PHPEnvManager.CreateEnv: mkdir env: %w (env: %w)", err, sandboxdomain.ErrEnvCreateFailed)
	}
	manifest := map[string]any{
		"name":        "forgify/env-" + filepath.Base(envPath),
		"description": "Forgify-managed PHP env",
		"require":     map[string]string{},
	}
	data, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return fmt.Errorf("sandbox.PHPEnvManager.CreateEnv: marshal: %w", err)
	}
	if err := os.WriteFile(composerJSON, data, 0o644); err != nil {
		return fmt.Errorf("sandbox.PHPEnvManager.CreateEnv: write composer.json: %w (env: %w)", err, sandboxdomain.ErrEnvCreateFailed)
	}
	return nil
}

// InstallDeps runs `composer require <pkg>` per dep with --working-dir
// pinned to env + COMPOSER_HOME pointed at env's .composer cache. deps
// are package names with optional version constraints (e.g.
// "monolog/monolog", "monolog/monolog:^3.0").
//
// InstallDeps 对每个 dep 跑 `composer require <pkg>` + --working-dir 钉 env
// + COMPOSER_HOME 指 env 的 .composer cache。deps 是包名带可选版本约束
// （如 "monolog/monolog"、"monolog/monolog:^3.0"）。
func (p *PHPEnvManager) InstallDeps(ctx context.Context, runtimePath, envPath string, deps []string, stream sandboxdomain.ProgressFunc) error {
	if len(deps) == 0 {
		return nil
	}
	composerHome := filepath.Join(envPath, ".composer")
	composerBin, err := p.tools.EnsureTool(ctx, "composer", "")
	if err != nil {
		return fmt.Errorf("sandbox.PHPEnvManager.InstallDeps: locate composer: %w", err)
	}

	for _, dep := range deps {
		cmd := exec.CommandContext(ctx, composerBin,
			"require",
			"--working-dir="+envPath,
			"--no-interaction",
			dep,
		)
		cmd.Env = append(os.Environ(), "COMPOSER_HOME="+composerHome)

		if err := RunWithStderrCapture(cmd, stream,
			sandboxdomain.ErrDepInstallFailed,
			fmt.Sprintf("sandbox.PHPEnvManager.InstallDeps %s", dep)); err != nil {
			return err
		}
	}
	return nil
}

// InstallExtras is a no-op — PHP plugins use deps only.
//
// InstallExtras no-op——PHP plugin 仅用 deps。
func (p *PHPEnvManager) InstallExtras(ctx context.Context, runtimePath, envPath string, extras []string, stream sandboxdomain.ProgressFunc) error {
	return nil
}

// EnvBin returns the absolute path to a binary inside the env's
// vendor/bin/ dir (Composer's convention for package-shipped binaries).
//
// EnvBin 返 env 的 vendor/bin/ 目录内某 binary 绝对路径
// （Composer 包提供 binary 的惯例位置）。
func (p *PHPEnvManager) EnvBin(envPath, binName string) string {
	if runtime.GOOS == "windows" && filepath.Ext(binName) == "" {
		binName += ".bat"
	}
	return filepath.Join(envPath, "vendor", "bin", binName)
}

// EnvDir returns the env root.
//
// EnvDir 返 env 根目录。
func (p *PHPEnvManager) EnvDir(envPath string) string { return envPath }
