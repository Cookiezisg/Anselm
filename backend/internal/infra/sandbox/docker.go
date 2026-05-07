// docker.go — DockerInstaller (verifies the daemon, never installs Docker
// itself) + DockerEnvManager (per-MCP-server image pull + workspace mount
// dir) + BuildDockerRunArgs helper that callers (e.g. mcp adapter) use to
// stitch the final `docker run -i --rm -v <env>:/workspace -e ... <image>`
// command stored in mcp.json.
//
// Why "Install" doesn't actually install Docker: docker is a system service
// (Mac/Win → Docker Desktop ~1.2 GB GUI + embedded Linux VM; Linux →
// dockerd systemd service requiring root). Forgify is a userland app and
// CANNOT silently install Docker — DockerInstaller's job is purely to
// detect a working daemon and surface a platform-specific install URL
// when absent. Same shape as other RuntimeInstallers so the sandbox
// dispatch code stays uniform.
//
// Layout:
//
//	<sandboxRoot>/docker-marker          // empty marker recording detected server version
//	<sandboxRoot>/envs/mcp/<id>/         // per-server host dir, mounted into container as /workspace
//	(images are NOT under sandboxRoot — they live in the docker daemon's
//	system-wide image cache, NOT auto-cleaned on env destroy)
//
// docker.go ——DockerInstaller（探活 daemon，不替用户装 Docker）+
// DockerEnvManager（per-MCP-server image pull + workspace 挂卷目录）+
// BuildDockerRunArgs helper 给调用方（如 mcp adapter）拼最终
// `docker run -i --rm -v <env>:/workspace -e ... <image>` 命令进 mcp.json。
//
// "Install" 不真装 Docker：docker 是系统服务（Mac/Win → Docker Desktop
// ~1.2 GB GUI + 内嵌 Linux VM；Linux → dockerd systemd 要 root）。Forgify
// 是 userland app 不能静默装 Docker——DockerInstaller 只探活 daemon，
// 缺则给平台对应安装链接。形态与其他 RuntimeInstaller 一致让 sandbox
// 派发代码同形。
package sandbox

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	"go.uber.org/zap"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

const (
	// dockerMarkerFile holds the detected server version; a present file
	// means "we've successfully verified docker daemon at least once
	// against this sandboxRoot". Mostly cosmetic — sandbox bookkeeping
	// reads it via Locate so the dispatch code has a non-empty path.
	//
	// dockerMarkerFile 存检测到的 server 版本；文件存在 = 至少成功探活过
	// 一次。主要走形式——sandbox 簿记经 Locate 读它让派发代码有非空路径。
	dockerMarkerFile = "docker-marker"

	// DockerWorkspaceMount is the in-container path the per-env host dir
	// gets mounted at. Containers see /workspace; the mcp server can write
	// caches/state files there and they survive container `--rm` since
	// the host bind keeps them.
	//
	// DockerWorkspaceMount 是 per-env 宿主目录在容器内挂载的路径。容器看
	// /workspace；mcp server 可写 cache/state 文件，容器 `--rm` 后仍存
	// （host bind 保留）。
	DockerWorkspaceMount = "/workspace"
)

// ── DockerInstaller ──────────────────────────────────────────────────

// DockerInstaller satisfies sandboxdomain.RuntimeInstaller for the docker
// "runtime". It does NOT install docker (system service, requires root /
// admin) — Install verifies the local daemon is reachable and returns a
// sentinel error when not, so callers can surface a platform-specific
// install URL to the user.
//
// DockerInstaller 满足 sandboxdomain.RuntimeInstaller 给 docker "runtime"。
// 不真装 docker（系统服务，要 root/admin）—— Install 探活本地 daemon，缺则
// 返 sentinel 让调用方给用户平台对应安装链接。
type DockerInstaller struct {
	log *zap.Logger
}

// NewDockerInstaller constructs the installer. log is required (panics on
// nil) — daemon detection logs warnings.
//
// NewDockerInstaller 构造 installer。log 必填（nil panic）——daemon 探活 log warn。
func NewDockerInstaller(log *zap.Logger) *DockerInstaller {
	if log == nil {
		panic("sandbox.NewDockerInstaller: nil logger")
	}
	return &DockerInstaller{log: log}
}

// Kind returns the runtime dispatch tag.
//
// Kind 返 runtime 派发 tag。
func (d *DockerInstaller) Kind() string { return "docker" }

// Install probes the docker daemon via `docker version --format
// {{.Server.Version}}` and writes a marker file to sandboxRoot recording
// the detected server version. Returns ErrDockerNotInstalled when the
// `docker` CLI is missing from PATH; ErrDockerDaemonDown when the CLI
// works but the daemon doesn't respond. version arg is ignored — docker
// version is determined by the user's installation, not by Forgify.
//
// Install 经 `docker version --format {{.Server.Version}}` 探 daemon，
// 把检测到的 server 版本写 marker 文件到 sandboxRoot。`docker` CLI 不在
// PATH 返 ErrDockerNotInstalled；CLI 工作但 daemon 不响应返
// ErrDockerDaemonDown。version 入参忽略——docker 版本由用户装的版本决定。
func (d *DockerInstaller) Install(ctx context.Context, version, sandboxRoot string, stream sandboxdomain.ProgressFunc) (string, error) {
	if stream != nil {
		stream("checking", "verifying docker daemon", -1)
	}

	cmd := exec.CommandContext(ctx, "docker", "version", "--format", "{{.Server.Version}}")
	out, err := cmd.Output()
	if err != nil {
		// errors.Is(err, exec.ErrNotFound) only fires when LookPath
		// fails up front; on some platforms the error comes through as
		// *exec.Error wrapping ErrNotFound — check both.
		// errors.Is(err, exec.ErrNotFound) 只在 LookPath 前置失败时触发；
		// 某些平台错误形态是 *exec.Error 包裹 ErrNotFound——两者都查。
		if errors.Is(err, exec.ErrNotFound) || strings.Contains(err.Error(), "executable file not found") {
			return "", fmt.Errorf("sandbox.DockerInstaller.Install: %w: %s",
				sandboxdomain.ErrDockerNotInstalled, dockerInstallGuide())
		}
		// Otherwise CLI exists but exit non-zero — daemon likely unreachable.
		// `docker version` prints client info to stdout even when daemon
		// is down, so an exit error usually means the server portion failed.
		// 否则 CLI 在但非零退出—— daemon 多半不可达。`docker version` 即便
		// daemon 挂也会输出 client 信息，非零退出多是 server 段失败。
		stderrSnippet := errSnippet(err)
		return "", fmt.Errorf("sandbox.DockerInstaller.Install: %w: docker CLI works but daemon is not responding (%s)",
			sandboxdomain.ErrDockerDaemonDown, dockerStartGuide()+strings.TrimSpace(stderrSnippet))
	}

	serverVersion := strings.TrimSpace(string(out))
	if serverVersion == "" {
		// Daemon responded but with no version — extremely unusual; treat as down.
		// daemon 响应了但无版本——极罕见；当 down 处理。
		return "", fmt.Errorf("sandbox.DockerInstaller.Install: %w: docker version returned empty server version",
			sandboxdomain.ErrDockerDaemonDown)
	}

	if stream != nil {
		stream("ready", "docker daemon ready (server "+serverVersion+")", -1)
	}

	if err := os.MkdirAll(sandboxRoot, 0o755); err != nil {
		return "", fmt.Errorf("sandbox.DockerInstaller.Install: mkdir sandbox root: %w", err)
	}
	markerAbs := filepath.Join(sandboxRoot, dockerMarkerFile)
	if err := os.WriteFile(markerAbs, []byte(serverVersion), 0o644); err != nil {
		return "", fmt.Errorf("sandbox.DockerInstaller.Install: write marker: %w", err)
	}
	return dockerMarkerFile, nil
}

// Locate returns the path to the docker CLI. Always returns "docker" —
// the system docker on PATH is what we use (validated earlier in Install).
// Sandbox dispatch never invokes this binary directly for docker envs;
// callers (e.g. mcp adapter via BuildDockerRunArgs) build the full
// `docker run ...` command themselves.
//
// Locate 返 docker CLI 路径。始终返 "docker"——用系统 PATH 上的 docker
// （Install 时已验过）。sandbox 派发不直接调本 binary；调用方（如 mcp
// adapter 经 BuildDockerRunArgs）自己拼完整 `docker run ...` 命令。
func (d *DockerInstaller) Locate(version, sandboxRoot string) (string, error) {
	return "docker", nil
}

// ListAvailable returns nil — Forgify does not enumerate Docker versions;
// the user-installed Docker Desktop / Docker Engine is what we use.
//
// ListAvailable 返 nil——Forgify 不枚举 Docker 版本；用用户装的 Docker Desktop
// / Docker Engine。
func (d *DockerInstaller) ListAvailable(ctx context.Context) ([]string, error) {
	return nil, nil
}

// ResolveDefault returns "" — docker has no version concept managed by
// Forgify; the daemon's reported version is informational only.
//
// ResolveDefault 返 ""——docker 没有 Forgify 管的版本概念；daemon 报的版本
// 仅作信息。
func (d *DockerInstaller) ResolveDefault(ctx context.Context) (string, error) {
	return "", nil
}

// ── DockerEnvManager ─────────────────────────────────────────────────

// DockerEnvManager satisfies sandboxdomain.EnvManager for docker. CreateEnv
// mkdirs a per-server host directory used as the bind mount source for
// /workspace inside the container. InstallDeps treats deps[0] as the
// image reference and runs `docker pull <image>`; additional deps entries
// are ignored (one container = one image).
//
// DockerEnvManager 满足 sandboxdomain.EnvManager 给 docker。CreateEnv 建一个
// per-server 宿主目录作容器 /workspace 的 bind 挂载源。InstallDeps 把 deps[0]
// 当 image 引用 + 跑 `docker pull <image>`；额外 deps 条目忽略（一个容器 =
// 一个 image）。
type DockerEnvManager struct {
	log *zap.Logger
}

// NewDockerEnvManager constructs the manager. log is required (panics on
// nil) — pull progress + extra-deps warnings log through it.
//
// NewDockerEnvManager 构造 manager。log 必填（nil panic）——pull 进度 + 多
// deps 告警走它。
func NewDockerEnvManager(log *zap.Logger) *DockerEnvManager {
	if log == nil {
		panic("sandbox.NewDockerEnvManager: nil logger")
	}
	return &DockerEnvManager{log: log}
}

// Kind returns the runtime dispatch tag — must match DockerInstaller.Kind().
//
// Kind 返 runtime 派发 tag——必须匹配 DockerInstaller.Kind()。
func (d *DockerEnvManager) Kind() string { return "docker" }

// CreateEnv mkdirs envPath. The directory becomes the bind mount source
// for /workspace inside the container — mcp servers can write
// caches/state files there and they survive container `--rm`.
//
// CreateEnv mkdir envPath。该目录作容器 /workspace 的 bind 挂载源——mcp
// server 能写 cache/state 文件，容器 `--rm` 后仍存。
func (d *DockerEnvManager) CreateEnv(ctx context.Context, runtimePath, envPath string) error {
	if err := os.MkdirAll(envPath, 0o755); err != nil {
		return fmt.Errorf("sandbox.DockerEnvManager.CreateEnv: mkdir env: %w (env: %w)",
			err, sandboxdomain.ErrEnvCreateFailed)
	}
	return nil
}

// InstallDeps pulls the image specified in deps[0] via `docker pull`.
// Additional deps entries log a warning and are ignored — Docker envs are
// 1:1 with images. stream callbacks fire per stderr line (docker outputs
// pull progress on stderr).
//
// InstallDeps 经 `docker pull` 拉 deps[0] 指定的 image。多余 deps 条目 warn
// log 并忽略——Docker env 与 image 一对一。stream 在每行 stderr 触发（docker
// 把 pull 进度写 stderr）。
func (d *DockerEnvManager) InstallDeps(ctx context.Context, runtimePath, envPath string, deps []string, stream sandboxdomain.ProgressFunc) error {
	if len(deps) == 0 {
		return nil
	}
	if len(deps) > 1 {
		d.log.Warn("sandbox.DockerEnvManager.InstallDeps: multiple deps given; pulling only the first",
			zap.Strings("deps", deps),
			zap.String("pulled", deps[0]))
	}
	image := deps[0]
	if stream != nil {
		stream("pulling", "docker pull "+image, -1)
	}
	cmd := exec.CommandContext(ctx, "docker", "pull", image)
	return RunWithStderrCapture(cmd, stream,
		sandboxdomain.ErrDepInstallFailed,
		"sandbox.DockerEnvManager.InstallDeps "+image)
}

// InstallExtras is a no-op. Docker images are immutable and self-contained;
// post-install steps (Playwright's chromium download) don't apply.
//
// InstallExtras no-op。Docker image 不可变 + 自包含；post-install 步骤
// （Playwright 的 chromium 下载）不适用。
func (d *DockerEnvManager) InstallExtras(ctx context.Context, runtimePath, envPath string, extras []string, stream sandboxdomain.ProgressFunc) error {
	return nil
}

// EnvBin returns "docker" — the system docker CLI. The actual `docker run
// -i --rm -v ... -e ... <image>` command pattern is built by the caller
// via BuildDockerRunArgs since envBin alone can't carry image / mount /
// env knowledge.
//
// EnvBin 返 "docker"——系统 docker CLI。真正的 `docker run -i --rm -v ...
// -e ... <image>` 命令模式由调用方经 BuildDockerRunArgs 构造，因为单 EnvBin
// 承不了 image / 挂卷 / env 信息。
func (d *DockerEnvManager) EnvBin(envPath, binName string) string {
	return "docker"
}

// EnvDir returns the env path. Used by Spawn as cwd; matters less for
// docker since the container has its own filesystem, but consistent with
// other EnvManagers.
//
// EnvDir 返 env path。Spawn 用作 cwd；docker 容器有自己的文件系统所以意义
// 不大，但与其他 EnvManager 保持一致。
func (d *DockerEnvManager) EnvDir(envPath string) string { return envPath }

// ── BuildDockerRunArgs (helper for callers) ──────────────────────────

// BuildDockerRunArgs assembles the `docker run` argument list for stdio
// MCP servers. The returned slice is passed as exec.Cmd.Args (positional
// after the "docker" command itself).
//
// Layout:
//
//	docker run -i --rm \
//	  -v <envPath>:/workspace \         // workspace dir auto-mounted
//	  -e KEY=VALUE -e KEY2=VALUE2 \     // user-supplied env vars
//	  <image> [serverArgs...]
//
// Defaults baked in:
//   - `-i`: keep stdin open (stdio MCP transport)
//   - `--rm`: auto-remove container on exit (no orphaned containers)
//   - `--network bridge` is docker's default (caller can override via custom args if needed)
//
// Security note: only envPath gets bind-mounted. Caller must NOT add
// host home-dir mounts without explicit user consent — that's a separate
// LLM-mediated decision (the install_mcp_server tool flow handles it).
//
// BuildDockerRunArgs 给 stdio MCP server 拼 `docker run` 参数列表。返的 slice
// 作 exec.Cmd.Args（"docker" 命令本身之后的位置参数）。
//
// 默认烧入：-i 保持 stdin 开（stdio MCP transport）；--rm 退出自动清容器
// （无孤儿容器）；--network bridge 是 docker 默认（调用方需要可经 customArgs 覆盖）。
//
// 安全：仅 envPath 被 bind 挂载。调用方不可加 host home-dir 挂载（那是
// install_mcp_server 工具流程的单独 LLM 决策）。
func BuildDockerRunArgs(envPath, image string, env []string, serverArgs []string) []string {
	args := []string{
		"run",
		"-i",
		"--rm",
		"-v", envPath + ":" + DockerWorkspaceMount,
	}
	for _, kv := range env {
		args = append(args, "-e", kv)
	}
	args = append(args, image)
	args = append(args, serverArgs...)
	return args
}

// ── helpers ──────────────────────────────────────────────────────────

// dockerInstallGuide returns a one-line, platform-specific instruction for
// installing Docker. Used by Install when the docker CLI is not on PATH.
//
// dockerInstallGuide 返 Docker 安装的一行平台对应指令。Install 在 docker
// CLI 不在 PATH 时用。
func dockerInstallGuide() string {
	switch runtime.GOOS {
	case "darwin":
		return "Install Docker Desktop from https://docs.docker.com/desktop/install/mac-install/ (Apple Silicon: pick the arm64 build)."
	case "windows":
		return "Install Docker Desktop from https://docs.docker.com/desktop/install/windows-install/ (requires WSL2 or Hyper-V)."
	case "linux":
		return "Install Docker Engine from https://docs.docker.com/engine/install/ then `sudo usermod -aG docker $USER` and re-login so the group takes effect."
	default:
		return "Install Docker from https://docs.docker.com/get-docker/."
	}
}

// dockerStartGuide returns a one-line, platform-specific instruction for
// starting the Docker daemon. Used when the CLI works but daemon is down.
//
// dockerStartGuide 返 Docker daemon 启动的一行平台对应指令。CLI 工作但
// daemon 挂时用。
func dockerStartGuide() string {
	switch runtime.GOOS {
	case "darwin", "windows":
		return "Start Docker Desktop from your applications folder. "
	case "linux":
		return "Start dockerd via `sudo systemctl start docker` (or `sudo service docker start`). "
	default:
		return "Start your Docker daemon. "
	}
}

// errSnippet trims a wrapped exec.Cmd error's text for inclusion in
// user-facing error messages. exec.Output() puts stderr in *exec.ExitError
// .Stderr — extract that when present, else format the error directly.
//
// errSnippet 截 exec.Cmd 错文本给用户面消息用。exec.Output() 把 stderr 放
// *exec.ExitError.Stderr——存在时取它；否则直接格式化 error。
func errSnippet(err error) string {
	var ee *exec.ExitError
	if errors.As(err, &ee) && len(ee.Stderr) > 0 {
		s := strings.TrimSpace(string(ee.Stderr))
		if len(s) > 200 {
			s = s[:200] + "..."
		}
		return s
	}
	return err.Error()
}
