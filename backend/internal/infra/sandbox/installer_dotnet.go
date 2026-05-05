// installer_dotnet.go — RuntimeInstaller for .NET via Microsoft's
// official install scripts. mise has dotnet support but Microsoft's
// scripts are simpler + the canonical install path; sandbox.md §4
// explicitly designates dotnet as a "v1 单独走专用 installer" entry.
//
// Strategy:
//
//   - On unix: download dotnet-install.sh from dot.net, run with
//     --install-dir=<sandboxRoot>/dotnet-installs/<version>/.
//   - On Windows: download dotnet-install.ps1 + run via powershell.
//   - Each (kind, version) gets its own dotnet install (no global SDK
//     sharing) for clean isolation. Trade-off matches the rest of the
//     sandbox philosophy.
//
// installer_dotnet.go ——通过微软官方 install 脚本装 .NET 的 RuntimeInstaller。
// mise 也支持 dotnet 但微软脚本更简单 + 是规范装机路径；sandbox.md §4 明确
// 把 dotnet 列为"v1 单独走专用 installer"。
//
// 策略：unix 下下 dotnet-install.sh + 跑 --install-dir=<sandboxRoot>/dotnet-installs/<version>/；
// Windows 下下 dotnet-install.ps1 + powershell 跑。每 (kind, version) 一个
// 独立 dotnet install（无全局 SDK 共享），跟 sandbox 其余隔离哲学一致。

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

// dotnetInstallsSubdir holds all DotnetInstaller installs; one per
// version under <sandboxRoot>/dotnet-installs/.
//
// dotnetInstallsSubdir 收所有 DotnetInstaller install；每版本一个，位于
// <sandboxRoot>/dotnet-installs/。
const dotnetInstallsSubdir = "dotnet-installs"

// dotnetInstallScriptURLs lookup by GOOS — the script source matters
// because Microsoft updates them. We fetch fresh on each install (small,
// few KB) rather than baking them into the binary.
//
// dotnetInstallScriptURLs 按 GOOS 查——脚本源很重要因微软会更新。每次 install
// 都拉新（小，几 KB）而非编进 binary。
var dotnetInstallScriptURLs = map[string]string{
	"linux":   "https://dot.net/v1/dotnet-install.sh",
	"darwin":  "https://dot.net/v1/dotnet-install.sh",
	"windows": "https://dot.net/v1/dotnet-install.ps1",
}

// DotnetInstaller installs the requested .NET SDK version via Microsoft's
// dotnet-install.sh / .ps1. Kind() == "dotnet"; one installer instance
// per Forgify deployment (defaultVersion baked at construction time).
//
// DotnetInstaller 通过微软 dotnet-install.sh / .ps1 装请求的 .NET SDK 版本。
// Kind() == "dotnet"；每 Forgify 部署一个 installer 实例（构造时固化
// defaultVersion）。
type DotnetInstaller struct {
	defaultVersion string // e.g. "8.0" — passed to --version
}

// NewDotnetInstaller constructs the installer with a default SDK version
// (e.g. "8.0", "9.0", "LTS"). Microsoft's script accepts version
// patterns and resolves them at install time.
//
// NewDotnetInstaller 构造 installer 带默认 SDK 版本（如 "8.0"、"9.0"、"LTS"）。
// 微软脚本接受版本约束并在装机时解析。
func NewDotnetInstaller(defaultVersion string) *DotnetInstaller {
	return &DotnetInstaller{defaultVersion: defaultVersion}
}

// Kind reports the dispatch tag.
//
// Kind 报告派发 tag。
func (d *DotnetInstaller) Kind() string { return "dotnet" }

// Install fetches the platform install script, runs it with
// --install-dir pointed at <sandboxRoot>/dotnet-installs/<version>/.
// Returns the install dir relative to sandboxRoot.
//
// Install 拉平台 install 脚本，跑 --install-dir 指
// <sandboxRoot>/dotnet-installs/<version>/。返 install 目录相对 sandboxRoot
// 的路径。
func (d *DotnetInstaller) Install(ctx context.Context, version, sandboxRoot string, stream sandboxdomain.ProgressFunc) (string, error) {
	scriptURL, ok := dotnetInstallScriptURLs[runtime.GOOS]
	if !ok {
		return "", fmt.Errorf("sandbox.DotnetInstaller.Install: no install script URL for %s: %w",
			runtime.GOOS, sandboxdomain.ErrRuntimeInstallFailed)
	}

	installDir := filepath.Join(sandboxRoot, dotnetInstallsSubdir, version)
	if err := os.MkdirAll(installDir, 0o755); err != nil {
		return "", fmt.Errorf("sandbox.DotnetInstaller.Install: mkdir install dir: %w", err)
	}

	// Fetch script to a temp file under sandboxRoot so we don't pollute
	// /tmp on systems with mounted-noexec /tmp.
	//
	// 把脚本拉到 sandboxRoot 下临时文件（避免有 mounted-noexec /tmp 的系统）。
	scriptName := "dotnet-install.sh"
	if runtime.GOOS == "windows" {
		scriptName = "dotnet-install.ps1"
	}
	scriptPath := filepath.Join(installDir, scriptName)
	scriptBody, err := httpGetBytesStatic(ctx, scriptURL)
	if err != nil {
		return "", fmt.Errorf("sandbox.DotnetInstaller.Install: fetch script: %w (runtime: %w)", err, sandboxdomain.ErrRuntimeInstallFailed)
	}
	if err := os.WriteFile(scriptPath, scriptBody, 0o755); err != nil {
		return "", fmt.Errorf("sandbox.DotnetInstaller.Install: write script: %w", err)
	}

	// Build install command per platform.
	// 按平台构造 install 命令。
	var cmd *exec.Cmd
	if runtime.GOOS == "windows" {
		cmd = exec.CommandContext(ctx, "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
			"-File", scriptPath,
			"-Version", version,
			"-InstallDir", installDir,
		)
	} else {
		cmd = exec.CommandContext(ctx, "bash", scriptPath,
			"--version", version,
			"--install-dir", installDir,
		)
	}

	stderrPipe, err := cmd.StderrPipe()
	if err != nil {
		return "", fmt.Errorf("sandbox.DotnetInstaller.Install: stderr pipe: %w", err)
	}
	if err := cmd.Start(); err != nil {
		return "", fmt.Errorf("sandbox.DotnetInstaller.Install: start: %w", err)
	}

	if stream != nil {
		scanner := bufio.NewScanner(stderrPipe)
		for scanner.Scan() {
			stream("installing", scanner.Text(), -1)
		}
	} else {
		_, _ = io.Copy(io.Discard, stderrPipe)
	}

	if err := cmd.Wait(); err != nil {
		return "", fmt.Errorf("sandbox.DotnetInstaller.Install %s: %w", version, sandboxdomain.ErrRuntimeInstallFailed)
	}

	return filepath.Join(dotnetInstallsSubdir, version), nil
}

// Locate returns the absolute path to the dotnet binary for an installed
// version. Microsoft's installer puts dotnet at <installDir>/dotnet (or
// dotnet.exe on Windows).
//
// Locate 返已装版本的 dotnet 二进制绝对路径。微软 installer 把 dotnet 放
// <installDir>/dotnet（Windows 是 dotnet.exe）。
func (d *DotnetInstaller) Locate(version, sandboxRoot string) (string, error) {
	binName := "dotnet"
	if runtime.GOOS == "windows" {
		binName = "dotnet.exe"
	}
	return filepath.Join(sandboxRoot, dotnetInstallsSubdir, version, binName), nil
}

// ListAvailable returns nil — we don't enumerate every .NET SDK version
// (Microsoft publishes many). Caller (UI) shows a curated set.
//
// ListAvailable 返 nil——不枚举每个 .NET SDK 版本（微软发了很多）。
// 调用方（UI）展示精选集。
func (d *DotnetInstaller) ListAvailable(ctx context.Context) ([]string, error) {
	return nil, nil
}

// ResolveDefault returns the construction-time default version (e.g. "8.0").
//
// ResolveDefault 返构造时默认版本（如 "8.0"）。
func (d *DotnetInstaller) ResolveDefault(ctx context.Context) (string, error) {
	return d.defaultVersion, nil
}
