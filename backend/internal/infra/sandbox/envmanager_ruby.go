// envmanager_ruby.go — Bundler-backed EnvManager for Ruby plugin envs.
//
// Per-env isolation strategy:
//
//   - BUNDLE_PATH=<envPath>/bundle  → Bundler installs gems under
//     <envPath>/bundle/ instead of the system / user gem dir.
//   - GEM_HOME = BUNDLE_PATH for non-Bundler `gem install` use cases
//     (rare; most Ruby plugins ship with a Gemfile and use Bundler).
//   - Per-env Gemfile written by CreateEnv if none exists; subsequent
//     `bundle add <gem>` updates it.
//
// envmanager_ruby.go ——基于 Bundler 的 Ruby plugin env EnvManager。
//
// 隔离策略：BUNDLE_PATH=<envPath>/bundle 让 Bundler 把 gem 装到
// <envPath>/bundle/ 而非系统/用户 gem 目录；GEM_HOME=BUNDLE_PATH 给非
// Bundler 的 `gem install` 用（罕见，多数 Ruby plugin 带 Gemfile 走 Bundler）。
// CreateEnv 不存在时写 per-env Gemfile；后续 `bundle add <gem>` 更新它。

package sandbox

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// RubyEnvManager satisfies sandboxdomain.EnvManager for Ruby.
//
// RubyEnvManager 满足 sandboxdomain.EnvManager 的 Ruby 实现。
type RubyEnvManager struct {
	bundleBin string // absolute path to bundle binary
}

// NewRubyEnvManager constructs the manager. bundleBin must point at a
// working `bundle` executable (typically Ruby's runtime install ships
// it; mise puts it at <runtimePath>/bin/bundle).
//
// NewRubyEnvManager 构造 manager。bundleBin 必须指有效 `bundle` 可执行
// （通常 Ruby runtime 自带；mise 装的在 <runtimePath>/bin/bundle）。
func NewRubyEnvManager(bundleBin string) *RubyEnvManager {
	return &RubyEnvManager{bundleBin: bundleBin}
}

// Kind reports the dispatch key.
//
// Kind 报告派发键。
func (r *RubyEnvManager) Kind() string { return "ruby" }

// CreateEnv mkdirs envPath/bundle (BUNDLE_PATH) and writes a minimal
// Gemfile if absent. Idempotent.
//
// CreateEnv mkdir envPath/bundle（BUNDLE_PATH）+ 不存在时写最小 Gemfile。
// 幂等。
func (r *RubyEnvManager) CreateEnv(ctx context.Context, runtimePath, envPath string) error {
	bundleDir := filepath.Join(envPath, "bundle")
	gemfile := filepath.Join(envPath, "Gemfile")
	if _, err := os.Stat(gemfile); err == nil {
		return nil
	}
	if err := os.MkdirAll(bundleDir, 0o755); err != nil {
		return fmt.Errorf("sandbox.RubyEnvManager.CreateEnv: mkdir bundle: %w (env: %w)", err, sandboxdomain.ErrEnvCreateFailed)
	}
	const gemfileContents = "source \"https://rubygems.org\"\n"
	if err := os.WriteFile(gemfile, []byte(gemfileContents), 0o644); err != nil {
		return fmt.Errorf("sandbox.RubyEnvManager.CreateEnv: write Gemfile: %w (env: %w)", err, sandboxdomain.ErrEnvCreateFailed)
	}
	return nil
}

// InstallDeps runs `bundle add <gem>` per dep with BUNDLE_PATH +
// BUNDLE_GEMFILE env vars pinned to the env. deps are gem names with
// optional version constraints (e.g. "rails", "rails:~>7.0").
//
// InstallDeps 对每个 dep 跑 `bundle add <gem>` + BUNDLE_PATH/BUNDLE_GEMFILE
// 钉 env。deps 是 gem 名带可选版本约束（如 "rails"、"rails:~>7.0"）。
func (r *RubyEnvManager) InstallDeps(ctx context.Context, runtimePath, envPath string, deps []string, stream sandboxdomain.ProgressFunc) error {
	if len(deps) == 0 {
		return nil
	}
	bundleDir := filepath.Join(envPath, "bundle")
	gemfile := filepath.Join(envPath, "Gemfile")

	for _, dep := range deps {
		cmd := exec.CommandContext(ctx, r.bundleBin, "add", dep)
		cmd.Env = append(os.Environ(),
			"BUNDLE_PATH="+bundleDir,
			"BUNDLE_GEMFILE="+gemfile,
			"GEM_HOME="+bundleDir,
		)
		cmd.Dir = envPath

		stderrPipe, err := cmd.StderrPipe()
		if err != nil {
			return fmt.Errorf("sandbox.RubyEnvManager.InstallDeps: stderr pipe %s: %w", dep, err)
		}
		if err := cmd.Start(); err != nil {
			return fmt.Errorf("sandbox.RubyEnvManager.InstallDeps: start %s: %w", dep, err)
		}

		if stream != nil {
			scanner := bufio.NewScanner(stderrPipe)
			for scanner.Scan() {
				stream("installing-deps", scanner.Text(), -1)
			}
		} else {
			_, _ = io.Copy(io.Discard, stderrPipe)
		}

		if err := cmd.Wait(); err != nil {
			return fmt.Errorf("sandbox.RubyEnvManager.InstallDeps %s: %w", dep, sandboxdomain.ErrDepInstallFailed)
		}
	}
	return nil
}

// InstallExtras is a no-op — Ruby plugins use deps only.
//
// InstallExtras no-op——Ruby plugin 仅用 deps。
func (r *RubyEnvManager) InstallExtras(ctx context.Context, runtimePath, envPath string, extras []string, stream sandboxdomain.ProgressFunc) error {
	return nil
}

// EnvBin returns the absolute path to a binary inside the env's bundle
// dir (Bundler installs gem-provided binaries under bundle/bin/).
//
// EnvBin 返 env 的 bundle 目录内某 binary 绝对路径（Bundler 把 gem 提供的
// binary 装到 bundle/bin/）。
func (r *RubyEnvManager) EnvBin(envPath, binName string) string {
	if runtime.GOOS == "windows" && filepath.Ext(binName) == "" {
		binName += ".bat"
	}
	return filepath.Join(envPath, "bundle", "bin", binName)
}

// EnvDir returns the env root.
//
// EnvDir 返 env 根目录。
func (r *RubyEnvManager) EnvDir(envPath string) string { return envPath }
