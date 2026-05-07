// fake_registry.go — in-memory RegistrySource for tests. Wired by
// test/harness/harness.go with a small set of deterministic entries
// (including the `everything` MCP test server that D9 pipeline tests
// rely on). Avoids network calls in unit + integration tests; the real
// OfficialRegistrySource only fires in production.
//
// fake_registry.go ——给测试用的内存 RegistrySource。test/harness/harness.go
// 注入小的确定条目集（含 D9 pipeline 依赖的 `everything` MCP 测试 server）。
// 避免单元 + 集成测试发网络请求；真 OfficialRegistrySource 仅生产用。
package mcp

import (
	"context"
	"fmt"
	"sort"

	mcpdomain "github.com/sunweilin/forgify/backend/internal/domain/mcp"
)

// FakeRegistrySource implements mcpdomain.RegistrySource against a static
// in-memory entry list. Tests construct it via NewFakeRegistrySource with
// whatever fixture entries the test scenario needs.
//
// FakeRegistrySource 用静态内存条目列表实现 mcpdomain.RegistrySource。
// 测试经 NewFakeRegistrySource 构造，传该场景需要的 fixture 条目。
type FakeRegistrySource struct {
	entries []mcpdomain.RegistryEntry
}

// NewFakeRegistrySource constructs a fake source backed by the given
// entries. Defensive copy so test mutation of the input slice doesn't
// affect later List/Get calls. If entries is nil, the source returns an
// empty (non-nil) list — matches the "marketplace exists but empty"
// production case rather than the "registry unavailable" path.
//
// NewFakeRegistrySource 构造由给定 entries 支撑的 fake source。深拷贝防测试
// 改入参 slice 影响后续 List/Get。entries 为 nil 时返非 nil 空 list——匹配
// 生产里"marketplace 存在但为空"路径，而非"registry 不可达"路径。
func NewFakeRegistrySource(entries []mcpdomain.RegistryEntry) *FakeRegistrySource {
	cp := make([]mcpdomain.RegistryEntry, len(entries))
	copy(cp, entries)
	// Stable name sort so iteration order matches what production sources
	// would surface (LLM rerank tests + UI alphabetical display rely on it).
	// 按 name 稳定排序让迭代顺序匹配生产 source（LLM 重排测试 + UI 字母序展示靠它）。
	sort.Slice(cp, func(i, j int) bool { return cp[i].Name < cp[j].Name })
	return &FakeRegistrySource{entries: cp}
}

// List returns a defensive copy of the seeded entries. Never returns
// ErrMarketplaceUnavailable — the fake is always "reachable".
//
// List 返已注入 entries 的深拷贝。永不返 ErrMarketplaceUnavailable——fake
// 永远"可达"。
func (f *FakeRegistrySource) List(_ context.Context) ([]mcpdomain.RegistryEntry, error) {
	out := make([]mcpdomain.RegistryEntry, len(f.entries))
	copy(out, f.entries)
	return out, nil
}

// Get returns the entry matching name; returns ErrRegistryEntryNotFound
// when name is absent.
//
// Get 返匹配 name 的条目；不存在返 ErrRegistryEntryNotFound。
func (f *FakeRegistrySource) Get(_ context.Context, name string) (*mcpdomain.RegistryEntry, error) {
	for i := range f.entries {
		if f.entries[i].Name == name {
			cp := f.entries[i]
			return &cp, nil
		}
	}
	return nil, fmt.Errorf("fake: %w: %q", mcpdomain.ErrRegistryEntryNotFound, name)
}

// Refresh is a no-op for the fake — entries are immutable post-construction.
//
// Refresh 对 fake 是 no-op——entries 构造后不可变。
func (f *FakeRegistrySource) Refresh(_ context.Context) error {
	return nil
}
