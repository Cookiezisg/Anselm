// envmanager_java.go — Maven-backed EnvManager for Java plugin envs.
//
// Per-env isolation strategy (scheme A from sandbox.md §7):
//
//   - MAVEN_OPTS=-Dmaven.repo.local=<envPath>/m2  → every env has its
//     own local Maven repository at <envPath>/m2/. Each env redownloads
//     all jars; no cross-env hardlink (Maven has no content-addressable
//     store like uv/pnpm). Disk cost: each env's m2 directory grows
//     proportional to its dep tree.
//   - Compiled artifacts / classpath assembly are caller's responsibility
//     — sandbox doesn't compile or run; it just isolates the dep cache.
//
// Why scheme A vs scheme B (shared ~/.m2 + per-env classpath manifest):
// scheme A is simpler (one env var, no jar-resolution code in Forgify)
// and matches the venv philosophy ("env = self-contained dep universe").
// Scheme B's disk savings need careful manifest tracking we don't ship
// in v1. v2 may revisit if disk pressure becomes a real complaint.
//
// envmanager_java.go ——基于 Maven 的 Java plugin env EnvManager。
//
// 隔离策略（sandbox.md §7 方案 A）：MAVEN_OPTS=-Dmaven.repo.local=<env>/m2
// 让每 env 有独立 Maven local repo。每 env 重下所有 jar；无跨 env hardlink
// （Maven 无类似 uv/pnpm 的 content-addressable store）。每 env 的 m2 目录
// 按 dep 树大小增长。
//
// 编译产物 / classpath 组装是调用方的事——sandbox 不编不跑，仅隔离 dep
// 缓存。
//
// 为什么选方案 A 而非方案 B（共享 ~/.m2 + per-env classpath 清单）：A 简单
// （一个 env var，Forgify 无 jar 解析代码）+ 跟 venv 哲学一致（env = 自包含
// dep 宇宙）。B 的省磁盘要小心 manifest 追踪，v1 不上。v2 视磁盘压力是否
// 真投诉再优化。

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

// JavaEnvManager satisfies sandboxdomain.EnvManager for Java.
//
// JavaEnvManager 满足 sandboxdomain.EnvManager 的 Java 实现。
type JavaEnvManager struct {
	mvnBin string // absolute path to mvn binary (mise-installed at boot)
}

// NewJavaEnvManager constructs the manager. mvnBin must be an absolute
// path to a working Maven binary — typically mise installs Maven as a
// separate runtime kind and the path comes from MiseInstaller("maven").Locate.
//
// NewJavaEnvManager 构造 manager。mvnBin 必须是可工作 Maven 二进制绝对
// 路径——通常 mise 把 Maven 装为独立 runtime kind，路径来自
// MiseInstaller("maven").Locate。
func NewJavaEnvManager(mvnBin string) *JavaEnvManager {
	return &JavaEnvManager{mvnBin: mvnBin}
}

// Kind reports the dispatch key.
//
// Kind 报告派发键。
func (j *JavaEnvManager) Kind() string { return "java" }

// CreateEnv mkdirs envPath/m2 (the per-env Maven local repo) and an
// envPath/lib dir for assembled classpath jars. Idempotent.
//
// CreateEnv mkdir envPath/m2（per-env Maven local repo）+ envPath/lib（汇集
// classpath jar 用）。幂等。
func (j *JavaEnvManager) CreateEnv(ctx context.Context, runtimePath, envPath string) error {
	m2Dir := filepath.Join(envPath, "m2")
	libDir := filepath.Join(envPath, "lib")
	if _, err := os.Stat(m2Dir); err == nil {
		return nil
	}
	if err := os.MkdirAll(m2Dir, 0o755); err != nil {
		return fmt.Errorf("sandbox.JavaEnvManager.CreateEnv: mkdir m2: %w (env: %w)", err, sandboxdomain.ErrEnvCreateFailed)
	}
	if err := os.MkdirAll(libDir, 0o755); err != nil {
		return fmt.Errorf("sandbox.JavaEnvManager.CreateEnv: mkdir lib: %w (env: %w)", err, sandboxdomain.ErrEnvCreateFailed)
	}
	return nil
}

// InstallDeps fetches each dep via `mvn dependency:get -Dartifact=<dep>`.
// deps are GAV coords ("groupId:artifactId:version", e.g.
// "org.apache.commons:commons-lang3:3.14.0"). Maven resolves transitive
// deps + downloads to the per-env local repo. Listening for stderr lines
// pipes through to ProgressFunc.
//
// InstallDeps 通过 `mvn dependency:get -Dartifact=<dep>` 拉每个 dep。
// deps 是 GAV 坐标（"groupId:artifactId:version"，如
// "org.apache.commons:commons-lang3:3.14.0"）。Maven 解传递 deps + 下到
// per-env local repo。stderr 行流到 ProgressFunc。
func (j *JavaEnvManager) InstallDeps(ctx context.Context, runtimePath, envPath string, deps []string, stream sandboxdomain.ProgressFunc) error {
	if len(deps) == 0 {
		return nil
	}
	m2Dir := filepath.Join(envPath, "m2")

	for _, dep := range deps {
		cmd := exec.CommandContext(ctx, j.mvnBin,
			"dependency:get",
			"-Dartifact="+dep,
			"-Dmaven.repo.local="+m2Dir,
		)
		// JAVA_HOME from runtimePath so Maven uses the env's pinned JDK.
		// JAVA_HOME 从 runtimePath 设，让 Maven 用 env 钉的 JDK。
		cmd.Env = append(os.Environ(), "JAVA_HOME="+runtimePath)

		stderrPipe, err := cmd.StderrPipe()
		if err != nil {
			return fmt.Errorf("sandbox.JavaEnvManager.InstallDeps: stderr pipe %s: %w", dep, err)
		}
		if err := cmd.Start(); err != nil {
			return fmt.Errorf("sandbox.JavaEnvManager.InstallDeps: start %s: %w", dep, err)
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
			return fmt.Errorf("sandbox.JavaEnvManager.InstallDeps %s: %w", dep, sandboxdomain.ErrDepInstallFailed)
		}
	}
	return nil
}

// InstallExtras is a no-op — Java plugins use deps only.
//
// InstallExtras no-op——Java plugin 仅用 deps。
func (j *JavaEnvManager) InstallExtras(ctx context.Context, runtimePath, envPath string, extras []string, stream sandboxdomain.ProgressFunc) error {
	return nil
}

// EnvBin returns runtimePath/bin/java-style binaries — for Java envs the
// "binary" is typically java itself or javac. binName is e.g. "java",
// "javac", "jar". Returns the path inside the JDK runtime, NOT inside
// the env (Java envs don't have their own bin dir, just jars in m2/lib).
//
// EnvBin 返 runtimePath/bin/java 风格二进制——Java env 的 "binary" 通常是
// java / javac / jar。返 JDK runtime 内的路径，**不**是 env 内（Java env
// 没自己的 bin 目录，只有 m2/lib 里的 jar）。
//
// Note: caller passes envPath but we deliberately only use binName +
// runtimePath. Asymmetry vs other EnvManagers (which return env-local
// paths) is documented; the alternative would be wrapper scripts in
// envPath/bin pointing at runtimePath/bin/<binary>, which is busy work.
//
// 注意：调用方传 envPath 但我们故意只用 binName + runtimePath。跟其他
// EnvManager（返 env-local 路径）不对称是设计上的；替代方案是 envPath/bin
// 写指向 runtimePath/bin/<binary> 的 wrapper 脚本，是 busy work。
func (j *JavaEnvManager) EnvBin(envPath, binName string) string {
	if runtime.GOOS == "windows" && filepath.Ext(binName) == "" {
		binName += ".exe"
	}
	// envPath unused — see godoc rationale.
	_ = envPath
	return binName
}

// EnvDir returns the env root.
//
// EnvDir 返 env 根目录。
func (j *JavaEnvManager) EnvDir(envPath string) string { return envPath }
