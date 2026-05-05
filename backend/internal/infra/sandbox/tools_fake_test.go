// tools_fake_test.go — shared in-memory ToolRegistry for unit tests.
//
// The 5 EnvManagers that need support tools (Python/uv, Node/pnpm,
// Java/maven, Ruby/bundler, PHP/composer) all take a
// sandboxdomain.ToolRegistry at construction. fakeToolRegistry pre-seeds
// arbitrary (kind → binPath) entries so unit tests can exercise EnvManager
// path-derivation logic without spinning a real sandbox Service or running
// mise installs.
//
// tools_fake_test.go ——单测共享的内存 ToolRegistry。
//
// 5 个需要支持工具的 EnvManager（Python/uv、Node/pnpm、Java/maven、
// Ruby/bundler、PHP/composer）构造时都接 sandboxdomain.ToolRegistry。
// fakeToolRegistry 预填任意 (kind → binPath) 条目，让单测能覆盖 EnvManager
// 路径推导逻辑，无需真起 sandbox Service 或跑 mise install。

package sandbox

import (
	"context"
	"fmt"

	sandboxdomain "github.com/sunweilin/forgify/backend/internal/domain/sandbox"
)

// fakeToolRegistry is a minimal sandboxdomain.ToolRegistry implementation
// for unit tests. paths is a (kind → absolute binary path) map seeded by
// the test; missing kinds return ErrRuntimeNotSupported wrapped with the
// requested kind for assertion clarity.
//
// fakeToolRegistry 是单测用的最小 sandboxdomain.ToolRegistry 实现。paths
// 是测试预填的 (kind → 绝对二进制路径) map；缺失 kind 返
// ErrRuntimeNotSupported 包装请求 kind 让断言清晰。
type fakeToolRegistry struct {
	paths map[string]string
}

// newFakeToolRegistry constructs a registry with the given (kind → path)
// pairs. Pass an empty map to test "tool missing" branches.
//
// newFakeToolRegistry 构造带给定 (kind → path) 对的 registry。传空 map 测
// "工具缺失"分支。
func newFakeToolRegistry(paths map[string]string) *fakeToolRegistry {
	return &fakeToolRegistry{paths: paths}
}

// EnsureTool returns the seeded path for kind, ignoring version (tests
// don't usually exercise version pinning). Returns the standard
// ErrRuntimeNotSupported sentinel when kind is missing so EnvManager
// error-path tests can errors.Is the result.
//
// EnsureTool 返 kind 对应预填路径，忽略 version（测试通常不演练版本钉）。
// kind 缺失返标准 ErrRuntimeNotSupported sentinel 让 EnvManager 错路径测试
// 能 errors.Is。
func (f *fakeToolRegistry) EnsureTool(ctx context.Context, kind, version string) (string, error) {
	p, ok := f.paths[kind]
	if !ok {
		return "", fmt.Errorf("fakeToolRegistry: kind %q not seeded: %w", kind, sandboxdomain.ErrRuntimeNotSupported)
	}
	return p, nil
}
