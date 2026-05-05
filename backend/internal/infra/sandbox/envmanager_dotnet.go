// envmanager_dotnet.go — dotnet-backed EnvManager for .NET plugin envs.
//
// Per-env isolation strategy:
//
//   - <envPath>/nuget.config sets <packageSourceCredentials> /
//     <fallbackPackageFolders> so NuGet packages land at
//     <envPath>/packages/ instead of the user's global ~/.nuget/packages.
//   - DOTNET_CLI_HOME=<envPath>/.dotnet  → dotnet CLI cache + telemetry
//     state local to the env.
//   - `dotnet add package <pkg>` runs in envPath as cwd; consumes a
//     dotnet project file (sandbox writes a minimal one if absent).
//
// envmanager_dotnet.go ——基于 dotnet 的 .NET plugin env EnvManager。
//
// 隔离策略：<envPath>/nuget.config 让 NuGet 包到 <envPath>/packages/ 而非
// 用户全局 ~/.nuget/packages；DOTNET_CLI_HOME=<envPath>/.dotnet 让 dotnet
// CLI cache + telemetry 本地化；`dotnet add package <pkg>` 在 envPath 当 cwd
// 跑，需要 dotnet project 文件（sandbox 不存在时写最小的）。

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
