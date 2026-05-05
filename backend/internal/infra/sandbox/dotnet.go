// dotnet.go — .NET runtime support: DotnetInstaller (Microsoft's
// official dotnet-install.sh / .ps1 script wrapper, deliberately
// bypassing mise per sandbox.md §4) + DotnetEnvManager (per-env
// project file + nuget.config so `dotnet add package` lands in the
// env's local packages folder).
//
// Layout per (kind, version) install:
//
//	<sandboxRoot>/dotnet-installs/<version>/dotnet[.exe]
//
// Per-env scaffolding:
//
//	<envPath>/env.csproj         minimal class-library project
//	<envPath>/nuget.config       globalPackagesFolder = ./packages
//	<envPath>/.dotnet/           DOTNET_CLI_HOME (env-local CLI cache)
//	<envPath>/packages/          NuGet downloads land here per nuget.config
//
// dotnet.go ——.NET runtime 支持：DotnetInstaller（包微软官方
// dotnet-install.sh / .ps1 脚本，sandbox.md §4 故意绕开 mise）+
// DotnetEnvManager（per-env project file + nuget.config，让
// `dotnet add package` 落到 env 本地 packages 目录）。

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

// ── DotnetInstaller ──────────────────────────────────────────────────

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

// ── DotnetEnvManager ─────────────────────────────────────────────────

// minimalCsprojContents is a barebones C# class library project file —
// enough for `dotnet add package` to succeed without any source code.
//
// minimalCsprojContents 是裸骨 C# 类库项目文件——让 `dotnet add package`
// 不带源码也能成功。
const minimalCsprojContents = `<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
</Project>
`

// minimalNugetConfigContents pins the NuGet package install location to
// <envPath>/packages/ so the env stays self-contained.
//
// minimalNugetConfigContents 钉 NuGet 包装机位置到 <envPath>/packages/ 让
// env 自包含。
const minimalNugetConfigContents = `<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <config>
    <add key="globalPackagesFolder" value="./packages" />
  </config>
</configuration>
`

// DotnetEnvManager satisfies sandboxdomain.EnvManager for .NET.
//
// DotnetEnvManager 满足 sandboxdomain.EnvManager 的 .NET 实现。
type DotnetEnvManager struct{}

// NewDotnetEnvManager constructs the manager. dotnet binary path is
// resolved via runtimePath at call time (no construction param).
//
// NewDotnetEnvManager 构造 manager。dotnet 二进制路径在调用时通过
// runtimePath 解析（无构造参数）。
func NewDotnetEnvManager() *DotnetEnvManager { return &DotnetEnvManager{} }

// Kind reports the dispatch tag — paired with DotnetInstaller.Kind().
//
// Kind 报告派发 tag——与 DotnetInstaller.Kind() 配对。
func (d *DotnetEnvManager) Kind() string { return "dotnet" }

// CreateEnv writes a minimal env.csproj + nuget.config + mkdirs the
// .dotnet CLI home dir. Idempotent.
//
// CreateEnv 写最小 env.csproj + nuget.config + mkdir .dotnet CLI home。
// 幂等。
func (d *DotnetEnvManager) CreateEnv(ctx context.Context, runtimePath, envPath string) error {
	csproj := filepath.Join(envPath, "env.csproj")
	if _, err := os.Stat(csproj); err == nil {
		return nil
	}
	if err := os.MkdirAll(filepath.Join(envPath, ".dotnet"), 0o755); err != nil {
		return fmt.Errorf("sandbox.DotnetEnvManager.CreateEnv: mkdir .dotnet: %w (env: %w)", err, sandboxdomain.ErrEnvCreateFailed)
	}
	if err := os.WriteFile(csproj, []byte(minimalCsprojContents), 0o644); err != nil {
		return fmt.Errorf("sandbox.DotnetEnvManager.CreateEnv: write csproj: %w (env: %w)", err, sandboxdomain.ErrEnvCreateFailed)
	}
	if err := os.WriteFile(filepath.Join(envPath, "nuget.config"), []byte(minimalNugetConfigContents), 0o644); err != nil {
		return fmt.Errorf("sandbox.DotnetEnvManager.CreateEnv: write nuget.config: %w (env: %w)", err, sandboxdomain.ErrEnvCreateFailed)
	}
	return nil
}

// InstallDeps runs `dotnet add package <pkg>` per dep. cwd is envPath so
// the project file is found; DOTNET_CLI_HOME points at env-local dir.
//
// InstallDeps 对每个 dep 跑 `dotnet add package <pkg>`。cwd 是 envPath 让
// project 文件被找到；DOTNET_CLI_HOME 指 env-local 目录。
func (d *DotnetEnvManager) InstallDeps(ctx context.Context, runtimePath, envPath string, deps []string, stream sandboxdomain.ProgressFunc) error {
	if len(deps) == 0 {
		return nil
	}
	dotnetBin := filepath.Join(runtimePath, "dotnet"+exeSuffix())

	for _, dep := range deps {
		cmd := exec.CommandContext(ctx, dotnetBin, "add", "package", dep)
		cmd.Env = append(os.Environ(), "DOTNET_CLI_HOME="+filepath.Join(envPath, ".dotnet"))
		cmd.Dir = envPath

		stderrPipe, err := cmd.StderrPipe()
		if err != nil {
			return fmt.Errorf("sandbox.DotnetEnvManager.InstallDeps: stderr pipe %s: %w", dep, err)
		}
		if err := cmd.Start(); err != nil {
			return fmt.Errorf("sandbox.DotnetEnvManager.InstallDeps: start %s: %w", dep, err)
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
			return fmt.Errorf("sandbox.DotnetEnvManager.InstallDeps %s: %w", dep, sandboxdomain.ErrDepInstallFailed)
		}
	}
	return nil
}

// InstallExtras is a no-op — .NET plugins use deps only.
//
// InstallExtras no-op——.NET plugin 仅用 deps。
func (d *DotnetEnvManager) InstallExtras(ctx context.Context, runtimePath, envPath string, extras []string, stream sandboxdomain.ProgressFunc) error {
	return nil
}

// EnvBin returns runtimePath/<binName> with .exe on Windows. Like
// JavaEnvManager, .NET envs don't have their own bin dir — caller uses
// runtimePath's dotnet to invoke env-installed assemblies.
//
// EnvBin 返 runtimePath/<binName> + Windows .exe。跟 JavaEnvManager 一样，
// .NET env 没自己 bin 目录——调用方用 runtimePath 的 dotnet 调 env 装的
// assembly。
func (d *DotnetEnvManager) EnvBin(envPath, binName string) string {
	if runtime.GOOS == "windows" && filepath.Ext(binName) == "" {
		binName += ".exe"
	}
	_ = envPath
	return binName
}

// EnvDir returns the env root.
//
// EnvDir 返 env 根目录。
func (d *DotnetEnvManager) EnvDir(envPath string) string { return envPath }
