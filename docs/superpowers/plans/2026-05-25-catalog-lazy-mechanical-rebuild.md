# Catalog 懒生成 + Mechanical 重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Capability Catalog 从"1s 后台轮询 + per-user 扇出 + LLM 润色 + 磁盘 cache + 版本 history"收敛成"开聊时按需、纯 mechanical 拼装"的能力清单,并把 document 移出 catalog。

**Architecture:** Catalog 退化成一个无状态 service:`build(ctx)` 现查 function/handler/skill/mcp 四个 source、拼成 `## Available capabilities` Markdown。`GetForSystemPrompt(ctx)`(chat runner 用)和 `Get(ctx)`(HTTP 巡检用)都直接走 `build`。删除轮询/磁盘/版本/指纹/LLM-generator/history 全部脚手架。保留 domain `Generator` 接口当未来"压缩/检索"的缝(本次不实现)。

**Tech Stack:** Go 1.x · GORM + modernc.org/sqlite · zap · Vue 3 + Pinia(testend)。测试:`make test-unit`(in-memory SQLite)、`make test-pipeline`(`-tags=pipeline`,fake LLM)、`staticcheck ./...`。

> 依据 spec:`docs/superpowers/specs/2026-05-25-catalog-lazy-mechanical-redesign.md`。

---

## 关键不变量(贯穿全程)

- **`GeneratedBy` 值统一为 `"mechanical"`**(原 `"mechanical-fallback"`)。所有断言、testend 类型、TopBar 徽标随之改。
- **新签名:** `GetForSystemPrompt(ctx context.Context) string`、`Get(ctx) (*Catalog, error)`、内部 `build(ctx) (*Catalog, error)`。三者都要求 ctx 带 userID(`reqctxpkg.GetUserID`),缺失返 `reqctxpkg.ErrMissingUserID` 包装。
- **瘦身后的 `catalogdomain.Catalog`:** 只有 `Summary` / `Coverage` / `GeneratedAt` / `GeneratedBy`。删 `Fingerprint` / `Version` / `SourcesAt`。
- **测试里取 user-ctx 一律用 `h.LocalCtx()`**(harness 已有,返回带 local user 的 ctx);单测里用 `reqctxpkg.SetUserID(context.Background(), "test-user")`。
- **每个 Task 落 green 再 commit**;commit message 无 AI attribution;commit 后 `git push`。

---

## File Structure

**Delete(整文件):**
- `backend/internal/app/catalog/polling.go`(Start/Stop/pollLoop/tryRefresh/RefreshAll/Refresh/fingerprint/historyID)
- `backend/internal/app/catalog/disk.go`(loadFromDisk/saveToDisk)
- `backend/internal/app/catalog/generator.go`(LLMGenerator + prompt 模板)
- `backend/internal/app/catalog/generator_test.go`
- `backend/internal/domain/catalog/history.go`(HistoryEntry / HistoryRepository)
- `backend/internal/infra/store/cataloghistory/`(整包)

**Rewrite:**
- `backend/internal/domain/catalog/catalog.go`(Catalog 瘦身 + SystemPromptProvider 改签名 + 删 LLM 错误)
- `backend/internal/app/catalog/catalog.go`(Service 瘦身 + New(log) + build/Get/GetForSystemPrompt)
- `backend/internal/app/catalog/catalog_test.go`(单测全重写)
- `backend/internal/transport/httpapi/handlers/catalog.go`(只留 GET /catalog)
- `backend/test/catalog/catalog_test.go` / `trinity_catalog_test.go` / `document_catalog_test.go`(pipeline,document 反转为"排除")

**Modify(局部):**
- `backend/internal/app/catalog/mechanical.go`(func 改名 `assemble` + GeneratedBy `"mechanical"`)
- `backend/internal/app/chat/runner.go:210`(传 ctx)
- `backend/internal/transport/httpapi/handlers/prompts.go`(删 catalog.generator 条目 + import)
- `backend/cmd/server/main.go`(import / AutoMigrate / New / wiring / document source / Start / Stop)
- `backend/test/harness/harness.go`(catalog 构造)
- `backend/test/integration/d9_test.go`(删 fsnotify→regen-chain 断言)
- testend:`stores/catalog.ts` / `api/resources.ts` / `api/misc.ts` / `types/domain.ts` / `views/observe/Catalog.vue` / `components/layout/TopBar.vue`
- 文档 7 份(§S14)

---

## Task 1: 后端 Go 重构(原子单元 — Go 编译耦合,整组一起落 green)

> 这是一次删除为主的紧耦合重构:domain 接口 + struct 一改,app/handler/main/所有测试同时断,只有全改完 `go build ./...` 才过。按下面步骤顺序改,最后统一 build + test。

**Files:** 见上方 File Structure 的 backend 部分。

- [ ] **Step 1.1: 重写 domain `catalog.go`**

`backend/internal/domain/catalog/catalog.go` 全文替换为:

```go
// Package catalog is the domain layer for the Capability Catalog injected into chat system prompts.
//
// Package catalog 是注入 chat system prompt 的能力清单的 domain 层。
package catalog

import (
	"context"
	"errors"
	"time"
)

// Catalog is the derived view injected into chat system prompts; built on demand, never cached.
//
// Catalog 是注入 chat system prompt 的派生视图,按需构建、不缓存。
type Catalog struct {
	Summary     string              `json:"summary"`
	Coverage    map[string][]string `json:"coverage"`
	GeneratedAt time.Time           `json:"generatedAt"`
	GeneratedBy string              `json:"generatedBy"` // 恒为 "mechanical"
}

// ErrAllSourcesFailed is returned when every registered source errored; mapped to 503 in errmap.
//
// ErrAllSourcesFailed 所有 source 报错时返回;errmap 映射 503。
var ErrAllSourcesFailed = errors.New("catalog: all sources failed")

// SystemPromptProvider is the narrow interface chat.runner consumes to fetch the catalog text.
//
// SystemPromptProvider 是 chat.runner 取 catalog 文本的窄接口。
type SystemPromptProvider interface {
	GetForSystemPrompt(ctx context.Context) string
}
```

- [ ] **Step 1.2: 删除 domain `history.go`**

```bash
git rm backend/internal/domain/catalog/history.go
```

(`source.go` 保留不动。)

- [ ] **Step 1.3: 重写 app `catalog.go`(Service 瘦身)**

`backend/internal/app/catalog/catalog.go` 全文替换为:

```go
// Package catalog is the service layer for the Capability Catalog.
//
// Package catalog 提供 Capability Catalog 的 service 层:按需现查 + mechanical 拼装。
package catalog

import (
	"context"
	"fmt"
	"sync"
	"time"

	"go.uber.org/zap"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// Generator is the optional summary builder seam; nil (the default) → mechanical.
// Kept as a port for a future size-gated compression/retrieval strategy; not wired today.
//
// Generator 是可选的 summary 构建缝;nil(默认)→ mechanical。
// 留作将来按规模触发的压缩/检索策略,本次不接。
type Generator interface {
	Generate(ctx context.Context, items []catalogdomain.Item, gMap map[string]catalogdomain.Granularity) (*catalogdomain.Catalog, error)
}

// Service builds the capability catalog on demand from registered sources.
//
// Service 按需从已注册 source 构建能力清单;无后台、无缓存、无磁盘。
type Service struct {
	log *zap.Logger

	sourcesMu sync.RWMutex
	sources   []catalogdomain.CatalogSource
}

// New constructs a Service. Register sources, then call Get / GetForSystemPrompt.
//
// New 构造 Service;注册 source 后即可 Get / GetForSystemPrompt。
func New(log *zap.Logger) *Service {
	if log == nil {
		panic("catalog.New: logger is nil")
	}
	return &Service{log: log}
}

// RegisterSource adds a source; safe at any time.
//
// RegisterSource 加 source,任意时点安全。
func (s *Service) RegisterSource(src catalogdomain.CatalogSource) {
	s.sourcesMu.Lock()
	defer s.sourcesMu.Unlock()
	s.sources = append(s.sources, src)
}

func (s *Service) snapshotSources() []catalogdomain.CatalogSource {
	s.sourcesMu.RLock()
	defer s.sourcesMu.RUnlock()
	out := make([]catalogdomain.CatalogSource, len(s.sources))
	copy(out, s.sources)
	return out
}

// build collects items from all sources (scoped to the ctx user) and assembles
// the mechanical capability list. Caller MUST supply a ctx with userID.
// All sources failing → ErrAllSourcesFailed; partial failure → use what succeeded.
//
// build 现查所有 source(按 ctx 用户)拼 mechanical 清单;ctx 必须带 userID。
// 全失败 → ErrAllSourcesFailed;部分失败 → 用成功的拼。
func (s *Service) build(ctx context.Context) (*catalogdomain.Catalog, error) {
	if _, ok := reqctxpkg.GetUserID(ctx); !ok {
		return nil, fmt.Errorf("catalog.build: %w", reqctxpkg.ErrMissingUserID)
	}
	sources := s.snapshotSources()

	items := []catalogdomain.Item{}
	gMap := map[string]catalogdomain.Granularity{}
	failed := 0
	for _, src := range sources {
		srcItems, err := src.ListItems(ctx)
		if err != nil {
			s.log.Warn("catalog source ListItems failed; substituting empty",
				zap.String("source", src.Name()), zap.Error(err))
			failed++
			continue
		}
		items = append(items, srcItems...)
		gMap[src.Name()] = src.Granularity()
	}
	if len(sources) > 0 && failed == len(sources) {
		return nil, fmt.Errorf("catalogapp.build: all %d sources failed: %w",
			len(sources), catalogdomain.ErrAllSourcesFailed)
	}

	cat := assemble(items, gMap)
	cat.GeneratedAt = time.Now().UTC()
	return cat, nil
}

// Get builds the current catalog on demand (HTTP inspection).
//
// Get 按需构建当前 catalog(HTTP 巡检)。
func (s *Service) Get(ctx context.Context) (*catalogdomain.Catalog, error) {
	return s.build(ctx)
}

// GetForSystemPrompt builds the capability list for chat injection; "" on any failure.
//
// GetForSystemPrompt 为 chat 注入构建能力清单;任何失败返 ""(聊天照常)。
func (s *Service) GetForSystemPrompt(ctx context.Context) string {
	cat, err := s.build(ctx)
	if err != nil {
		s.log.Warn("catalog build failed; omitting capability section", zap.Error(err))
		return ""
	}
	return cat.Summary
}
```

> 注:保留 `Generator` 接口(缝)但不存字段、不接 LLM。`reqctxpkg.ErrMissingUserID` 已存在(原 polling.go 用过)。

- [ ] **Step 1.4: 改 `mechanical.go`(func 改名 + GeneratedBy)**

在 `backend/internal/app/catalog/mechanical.go`:
- 把函数签名 `func mechanicalFallback(` 改为 `func assemble(`。
- 把注释首行改为:`// assemble enumerates items per-source into a Markdown capability list.` / 中文:`// assemble 按 source 把 item 拼成 Markdown 能力清单。`
- 把返回结构里 `GeneratedBy: "mechanical-fallback",` 改为 `GeneratedBy: "mechanical",`。

其余(groupBySource、排序、空库跳段、尾句)不动。

- [ ] **Step 1.5: 删除轮询/磁盘/LLM-generator 文件**

```bash
git rm backend/internal/app/catalog/polling.go \
       backend/internal/app/catalog/disk.go \
       backend/internal/app/catalog/generator.go \
       backend/internal/app/catalog/generator_test.go
```

- [ ] **Step 1.6: 删除 cataloghistory store 包**

```bash
git rm -r backend/internal/infra/store/cataloghistory
```

- [ ] **Step 1.7: 改 chat `runner.go`(传 ctx)**

`backend/internal/app/chat/runner.go:210`,把:

```go
		if catalogText := s.catalog.GetForSystemPrompt(); catalogText != "" {
```

改为:

```go
		if catalogText := s.catalog.GetForSystemPrompt(ctx); catalogText != "" {
```

(`ctx` 是 `SystemPromptSections(ctx, conv)` 的入参,已在作用域内。`chat.go` 的字段类型 `catalogdomain.SystemPromptProvider` 与 `SetSystemPromptProvider` 不用改 —— 接口方法签名变了,`*catalogapp.Service` 仍满足。)

- [ ] **Step 1.8: 重写 handler `catalog.go`(只留 GET /catalog)**

`backend/internal/transport/httpapi/handlers/catalog.go` 全文替换为:

```go
package handlers

import (
	"net/http"

	"go.uber.org/zap"

	catalogapp "github.com/sunweilin/forgify/backend/internal/app/catalog"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// CatalogHandler hosts the catalog inspection endpoint.
//
// CatalogHandler 持 catalog 巡检端点。
type CatalogHandler struct {
	svc *catalogapp.Service
	log *zap.Logger
}

func NewCatalogHandler(svc *catalogapp.Service, log *zap.Logger) *CatalogHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &CatalogHandler{svc: svc, log: log.Named("handlers.catalog")}
}

func (h *CatalogHandler) Register(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/catalog", h.Get)
}

// Get builds and returns the current capability catalog for the request user.
//
// Get 按需构建并返回当前用户的能力清单。
func (h *CatalogHandler) Get(w http.ResponseWriter, r *http.Request) {
	cat, err := h.svc.Get(r.Context())
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, cat)
}
```

> 删掉 `Refresh` / `History` / `Diff` / `stringSet` 及 `strconv` import。`ErrAllSourcesFailed` 经 `FromDomainError`→errmap 映射为 503 `CATALOG_ALL_SOURCES_FAILED`(已登记,不动)。内联码 `CATALOG_HISTORY_UNAVAILABLE` / `CATALOG_VERSION_NOT_FOUND` 随方法删除消失。

- [ ] **Step 1.9: 改 `prompts.go`(删 §18 catalog.generator 条目)**

`backend/internal/transport/httpapi/handlers/prompts.go`:
- 删掉这 4 行(原 78-81):

```go
	entries = append(entries, mkEntry("catalog.generator", "internal-llm",
		"Catalog summary generator LLM prompt template",
		catalogapp.GeneratorPromptTemplate(),
		"backend/internal/app/catalog/generator.go::generatorPromptTemplate"))
```

- 删掉文件顶部的 `catalogapp "github.com/sunweilin/forgify/backend/internal/app/catalog"` import(删条目后唯一用处消失)。

- [ ] **Step 1.10: 改 `main.go`(拆所有旧接线)**

`backend/cmd/server/main.go`:
- 删 import(原 L99):`cataloghistorystore "github.com/sunweilin/forgify/backend/internal/infra/store/cataloghistory"`
- 删 AutoMigrate 行(原 L188):`&catalogdomain.HistoryEntry{},`
- 把 catalog 构造块(原 L405-426)替换为:

```go
	catalogService := catalogapp.New(log)
	// Sources = "things the LLM can call from chat as capabilities":
	// function / handler / skill / mcp. Documents are intentionally excluded —
	// they enter context via @-mention (separate feature), not the catalog.
	// Workflows are excluded too (user-triggered, not intent-matched).
	//
	// sources = LLM 从 chat 可调用的能力:function / handler / skill / mcp。
	// 文档故意排除 —— 走 @ 引用进上下文(独立功能),不进 catalog。
	catalogService.RegisterSource(functionService.AsCatalogSource())
	catalogService.RegisterSource(handlerService.AsCatalogSource())
	catalogService.RegisterSource(skillService.AsCatalogSource())
	catalogService.RegisterSource(mcpService.AsCatalogSource())
	chatService.SetSystemPromptProvider(catalogService)
```

- 删关停行(原 L652):`catalogService.Stop()`(其上方 §13.4 注释保留 —— skill/mcp 仍有 Stop)。
- `CatalogService: catalogService`(deps,原 L590)保留。
- `documentService.AsCatalogSource()` 不再被调用 —— **不要删除 `document` 包里的 `AsCatalogSource` 方法**(留作 @-mention 功能复用;若 staticcheck 报 U1000 unused,在 Step 1.14 处理:加 `//lint:ignore U1000 reserved for @-mention feature` 或确认其它消费方)。

> `defaultUserHome` 变量其它 service(mcp/skill/settings)仍在用,**不要删**。原 L405 用到的 `filepath.Join(defaultUserHome, ".catalog.json")` 随构造块替换消失。`MigrateLegacy` 里的 `.catalog.json` 项保留(无害的向后兼容迁移)。

- [ ] **Step 1.11: 重写单测 `internal/app/catalog/catalog_test.go`**

全文替换为(删掉所有 poll/fingerprint/disk/generator/version 相关用例):

```go
package catalog

import (
	"context"
	"strings"
	"sync"
	"testing"

	"go.uber.org/zap/zaptest"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

func ctxWithUser() context.Context {
	return reqctxpkg.SetUserID(context.Background(), "test-user")
}

type fakeSource struct {
	name    string
	gran    catalogdomain.Granularity
	items   []catalogdomain.Item
	listErr error
}

func (f *fakeSource) Name() string                           { return f.name }
func (f *fakeSource) Granularity() catalogdomain.Granularity { return f.gran }
func (f *fakeSource) ListItems(_ context.Context) ([]catalogdomain.Item, error) {
	if f.listErr != nil {
		return nil, f.listErr
	}
	return f.items, nil
}

func newServiceForTest(t *testing.T) *Service {
	t.Helper()
	return New(zaptest.NewLogger(t))
}

func TestGetForSystemPrompt_NoSources_Empty(t *testing.T) {
	s := newServiceForTest(t)
	if got := s.GetForSystemPrompt(ctxWithUser()); got != "" {
		t.Errorf("GetForSystemPrompt with no sources = %q, want empty", got)
	}
}

func TestGetForSystemPrompt_MissingUserID_Empty(t *testing.T) {
	s := newServiceForTest(t)
	s.RegisterSource(&fakeSource{name: "function", gran: catalogdomain.PerItem, items: []catalogdomain.Item{
		{Source: "function", ID: "f_a", Name: "csv-clean", Description: "Strip BOMs"},
	}})
	if got := s.GetForSystemPrompt(context.Background()); got != "" {
		t.Errorf("GetForSystemPrompt without userID = %q, want empty", got)
	}
}

func TestGet_MissingUserID_Errors(t *testing.T) {
	s := newServiceForTest(t)
	if _, err := s.Get(context.Background()); err == nil {
		t.Fatal("Get without userID should error")
	}
}

func TestBuild_MechanicalListsAllSources(t *testing.T) {
	s := newServiceForTest(t)
	s.RegisterSource(&fakeSource{name: "function", gran: catalogdomain.PerItem, items: []catalogdomain.Item{
		{Source: "function", ID: "f_a", Name: "csv-clean", Description: "Strip BOMs"},
	}})
	s.RegisterSource(&fakeSource{name: "skill", gran: catalogdomain.PerItem, items: []catalogdomain.Item{
		{Source: "skill", ID: "deploy", Name: "deploy", Description: "Deploy via CI"},
	}})
	cat, err := s.Get(ctxWithUser())
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if cat.GeneratedBy != "mechanical" {
		t.Errorf("GeneratedBy = %q, want mechanical", cat.GeneratedBy)
	}
	if !strings.Contains(cat.Summary, "## Available capabilities") {
		t.Errorf("Summary missing header: %q", cat.Summary)
	}
	if !strings.Contains(cat.Summary, "csv-clean") || !strings.Contains(cat.Summary, "deploy") {
		t.Errorf("Summary missing an item name: %q", cat.Summary)
	}
	if !contains(cat.Coverage["function"], "f_a") {
		t.Errorf("Coverage[function] = %v, missing f_a", cat.Coverage["function"])
	}
	if cat.GeneratedAt.IsZero() {
		t.Error("GeneratedAt should be set")
	}
}

func TestBuild_EmptyLibrary_SkipsSection(t *testing.T) {
	s := newServiceForTest(t)
	s.RegisterSource(&fakeSource{name: "function", gran: catalogdomain.PerItem, items: nil})
	cat, err := s.Get(ctxWithUser())
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if strings.Contains(cat.Summary, "## Available capabilities") {
		t.Errorf("empty library should skip the section; got %q", cat.Summary)
	}
}

func TestBuild_AllSourcesFail_Errors(t *testing.T) {
	s := newServiceForTest(t)
	s.RegisterSource(&fakeSource{name: "function", gran: catalogdomain.PerItem, listErr: errBoom})
	if _, err := s.Get(ctxWithUser()); err == nil {
		t.Fatal("all-sources-failed Get should error")
	}
}

func TestBuild_PartialFailure_UsesSucceeded(t *testing.T) {
	s := newServiceForTest(t)
	s.RegisterSource(&fakeSource{name: "bad", gran: catalogdomain.PerItem, listErr: errBoom})
	s.RegisterSource(&fakeSource{name: "good", gran: catalogdomain.PerItem, items: []catalogdomain.Item{
		{Source: "good", ID: "g_1", Name: "good-item", Description: "still here"},
	}})
	cat, err := s.Get(ctxWithUser())
	if err != nil {
		t.Fatalf("partial-failure Get should not error; got %v", err)
	}
	if !strings.Contains(cat.Summary, "good-item") {
		t.Errorf("good source dropped: %q", cat.Summary)
	}
}

func TestRegisterSource_Concurrent(t *testing.T) {
	s := newServiceForTest(t)
	var wg sync.WaitGroup
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			s.RegisterSource(&fakeSource{name: "src", gran: catalogdomain.PerItem})
		}()
	}
	wg.Wait()
	if got := len(s.snapshotSources()); got != 10 {
		t.Errorf("registered = %d, want 10", got)
	}
}

var errBoom = boomErr("kaboom")

type boomErr string

func (e boomErr) Error() string { return string(e) }

func contains(xs []string, want string) bool {
	for _, x := range xs {
		if x == want {
			return true
		}
	}
	return false
}
```

- [ ] **Step 1.12: 改 `test/harness/harness.go`**

- 删 import(原 L96):`cataloghistorystore "..."`
- 删 AutoMigrate(原 L243):`&catalogdomain.HistoryEntry{},`
- 把 catalog 构造块(原 L460-472)替换为:

```go
	catalogService := catalogapp.New(log)
	catalogService.RegisterSource(functionService.AsCatalogSource())
	catalogService.RegisterSource(handlerService.AsCatalogSource())
	catalogService.RegisterSource(skillService.AsCatalogSource())
	catalogService.RegisterSource(mcpService.AsCatalogSource())
	chatService.SetSystemPromptProvider(catalogService)
```

- `CatalogService: catalogService`(原 L594)、`Catalog: catalogService`(原 L630)保留。
- 若 `catalogdomain` import 在 harness 里删 HistoryEntry 后无其它用处,删该 import(否则保留)。

- [ ] **Step 1.13: 重写 pipeline 测试**

**`backend/test/catalog/catalog_test.go`** —— 把三个用例改为按需 + 删 version/fingerprint;`Refresh(ctx);Get()` → `Get(h.LocalCtx())`:

- `TestCatalog_AllSourcesCovered_E2E`:
  - 删 `if err := h.Catalog.Refresh(...)`,改 `cat, err := h.Catalog.Get(h.LocalCtx())` + err 检查。
  - `cat.GeneratedBy` 断言改为 `== "mechanical"`。
  - 保留 Coverage[function]/Coverage[skill]/Summary 含 csv_clean/deploy 的断言。
  - 末尾 `GetForSystemPrompt()` → `GetForSystemPrompt(h.LocalCtx())`,断言 `== cat.Summary`(两次 build 内容相同;若担心 GeneratedAt 抖动导致 *Catalog 不同,只比 Summary 字段 —— 本就只比 Summary,OK)。
- `TestCatalog_FunctionDescriptionChange_TriggersRegen` → 改名 `TestCatalog_FunctionDescriptionChange_ReflectedOnRebuild`:
  - 删 `versionFirst`/`fpFirst`/Version/Fingerprint 全部断言。
  - 流程:`Get(h.LocalCtx())` 拿 first;`UpdateMeta` 改描述;再 `Get(h.LocalCtx())` 拿 second;断言 `strings.Contains(second.Summary, "VERSION-TWO")`(按需构建天然反映新描述)。
- `TestCatalog_NoLLMKey_FallsBackToMechanical` → 改名 `TestCatalog_AlwaysMechanical`:
  - 删 Fingerprint/Version/短路断言。
  - `Get(h.LocalCtx())` → 断言 `GeneratedBy == "mechanical"` + `Summary` 含 `alpha`。

**`backend/test/catalog/trinity_catalog_test.go`** —— 同样把 `Refresh(ctx);Get()`(原 L46-49、L78-81)改为 `Get(h.LocalCtx())`,删任何 `.Version`/`.Fingerprint` 断言,GeneratedBy 断言改 `"mechanical"`。其余 function/handler/skill coverage 断言保留。

**`backend/test/catalog/document_catalog_test.go`** —— **反转**为"document 不进 catalog"。全文替换为:

```go
//go:build pipeline

package catalog

import (
	"strings"
	"testing"

	documentapp "github.com/sunweilin/forgify/backend/internal/app/document"
	th "github.com/sunweilin/forgify/backend/test/harness"
)

// TestCatalog_DocumentsExcluded_E2E — documents must NOT appear in the catalog;
// they enter context via @-mention (separate feature), not auto-injection.
//
// TestCatalog_DocumentsExcluded_E2E —— 文档不进 catalog;走 @ 引用进上下文。
func TestCatalog_DocumentsExcluded_E2E(t *testing.T) {
	h := th.New(t)
	ctx := h.LocalCtx()

	if _, err := h.Document.Create(ctx, documentapp.CreateInput{
		Name: "Projects", Description: "Top-level project folder",
	}); err != nil {
		t.Fatalf("seed Projects: %v", err)
	}
	if _, err := h.Document.Create(ctx, documentapp.CreateInput{
		Name: "scratchpad", Description: "Loose ideas",
	}); err != nil {
		t.Fatalf("seed scratchpad: %v", err)
	}

	cat, err := h.Catalog.Get(h.LocalCtx())
	if err != nil {
		t.Fatalf("Catalog.Get: %v", err)
	}
	if ids := cat.Coverage["document"]; len(ids) != 0 {
		t.Errorf("Coverage[document] = %v, want empty (documents excluded)", ids)
	}
	if strings.Contains(cat.Summary, "Projects") || strings.Contains(cat.Summary, "scratchpad") {
		t.Errorf("Summary should not contain document names: %q", cat.Summary)
	}
}
```

**`backend/test/integration/d9_test.go`** —— 保留"`## Available capabilities` 进 LLM prompt"断言(原 L49);删除 fsnotify→catalog-regen-chain 那段(原含 L115 `dropped-skill after fsnotify → catalog regen`)。若该断言所在用例整体是测 regen-chain,删整个用例;若只是用例尾部一段,删那段 + 相关 setup。改任何 `Refresh`/`Get()` 调用为 `Get(h.LocalCtx())`。

- [ ] **Step 1.14: 编译 + 全测 + 静态检查**

```bash
cd backend && go build ./... && make test-unit && staticcheck ./...
```

Expected: build 通过;test-unit 全绿(catalog 单测用新用例);staticcheck 无新告警。
- 若 staticcheck 报 `document.AsCatalogSource` U1000 unused:确认是否还有消费方;无则在该方法上加 `//lint:ignore U1000 reserved for @-mention feature(see catalog spec)` 或与用户确认删除。
- 若 `catalogdomain` 在某文件 import 后未使用 → 删 import。

```bash
make test-pipeline
```

Expected: pipeline 全绿(catalog pipeline 用新断言;document 反转用例通过)。

- [ ] **Step 1.15: Commit + push**

```bash
git add -A
git commit -m "refactor(backend): catalog 改为懒生成+mechanical,移除轮询/LLM/history/磁盘,文档移出 catalog"
git push
```

---

## Task 2: testend(Vue)对齐单端点 API

**Files:** `testend/src/{stores/catalog.ts, api/resources.ts, api/misc.ts, types/domain.ts, views/observe/Catalog.vue, components/layout/TopBar.vue}`

- [ ] **Step 2.1: `types/domain.ts` — Catalog 瘦身**

把 `export interface Catalog { ... }`(原 531 起)替换为:

```ts
export interface Catalog {
  summary: string;
  coverage: Record<string, string[]>;
  generatedBy: 'mechanical';
  generatedAt: string;
}
```

(删 `fingerprint` / `version` / `sourcesAt`。)

- [ ] **Step 2.2: `api/resources.ts` — catalogAPI 去 refresh**

把(原 143-146):

```ts
export const catalogAPI = {
  get: () => getJSON<Catalog | null>('/api/v1/catalog'),
  refresh: () => postJSON<Catalog>('/api/v1/catalog:refresh'),
};
```

改为:

```ts
export const catalogAPI = {
  get: () => getJSON<Catalog | null>('/api/v1/catalog'),
};
```

- [ ] **Step 2.3: `api/misc.ts` — 删 catalog history**

删掉整段(原 82-106):`CatalogHistoryEntry` 接口、`CatalogDiff` 接口、`catalogHistoryAPI`。grep 确认无其它引用:`grep -rn "catalogHistoryAPI\|CatalogHistoryEntry\|CatalogDiff" testend/src`(应只剩被删处)。

- [ ] **Step 2.4: `stores/catalog.ts` — 去 forceRebuild**

删 `forceRebuild` action 及其在 return 里的导出。`refresh()`(调 `catalogAPI.get()`)保留。最终 return:`{ current, loading, error, refresh }`。

- [ ] **Step 2.5: `views/observe/Catalog.vue` — 去 force/version/fingerprint/sourcesAt**

- 删 `force()` 函数、`refreshing` ref、模板里的 "force rebuild" 按钮。
- `ViewHeader` 的 `:subtitle` 改为只用 generatedAt:`cat.current ? \`generated ${timestamp(cat.current.generatedAt)}\` : 'no catalog yet'`。
- 删 `.meta-row` 里 `v{{ cat.current.version }}` 与 `fingerprint ...` 两处;保留 raw 按钮。
- 删 "source timestamps" 段(`cat.current.sourcesAt`)。
- 保留 "summary" + "coverage" 两段。
- `script` 顶部注释改为不再提"bg poll"。

- [ ] **Step 2.6: `components/layout/TopBar.vue` — 去 fingerprint pill**

- 删 `catalogFp` computed(原 42,用 `fingerprint`)。
- 模板里 `cat:{{ catalogFp }}` 改为展示 generatedBy 或直接移除该 meta-item。最简:把该 `<span class="meta-item mono">` 块整体删除(catalog 快照在 TopBar 的价值随指纹消失);保留其余 build/port meta。
- `catalogBy` computed 若 TopBar 不再用则删;`.catalog-fallback` 样式块若不再引用则删。

- [ ] **Step 2.7: 构建 + commit**

```bash
cd testend && npm run build
```

Expected: tsc + vite build 通过(无 `fingerprint`/`version`/`refresh`/`forceRebuild` 残引用)。

```bash
git add -A && git commit -m "refactor(testend): catalog 视图对齐单端点 API(去 refresh/history/diff/version/fingerprint)" && git push
```

---

## Task 3: 文档同步(§S14,最高优先级)

**Files:** `documents/version-1.2/` 下 7 份。每处用 1-2 句改完即可,不堆砌。

- [ ] **Step 3.1:** `service-design-documents/catalog.md` —— 整体改写:触发(开聊懒构建)/ 生成(mechanical,Generator 留缝)/ sources(function/handler/skill/mcp,document 排除→@-mention TODO)/ HTTP(只 `GET /catalog`)/ Catalog struct 瘦身;**删 §4.7 history/diff 整段**;实现清单勾选状态更新。

- [ ] **Step 3.2:** `service-contract-documents/api-design.md` —— catalog 端点从 4 改 1(只留 `GET /api/v1/catalog`,200 返 `{summary,coverage,generatedAt,generatedBy}`;全源失败 503 `CATALOG_ALL_SOURCES_FAILED`)。删 `:refresh` / `/history` / `/diff` 行。

- [ ] **Step 3.3:** `service-contract-documents/error-codes.md` —— 删 `CATALOG_HISTORY_UNAVAILABLE` / `CATALOG_VERSION_NOT_FOUND`;保留 `CATALOG_ALL_SOURCES_FAILED`。

- [ ] **Step 3.4:** `service-contract-documents/events-design.md` —— notifications 词表里 `catalog` 类型标注为"已停发"(懒构建无变更事件);或移除该词条(开放词表,移除安全)。

- [ ] **Step 3.5:** `service-contract-documents/database-design.md` —— 移除 `catalog_history` 表定义/说明。

- [ ] **Step 3.6:** `testend-design.md`(及 `desktop-packaging-notes.md` 若提及)—— catalog 巡检视图简化为只读当前清单;注明 `.catalog.json` 不再生成。

- [ ] **Step 3.7:** `progress-record.md` —— 加 dev log(1-2 句):做了什么(catalog 懒生成+mechanical,document 移出)、测试数(单测 + pipeline)、决策(LLM generator 删除,Generator 接口留缝;@ 文档作为后续独立 spec)。

- [ ] **Step 3.8: Commit + push**

```bash
git add -A && git commit -m "docs: 同步 catalog 懒生成重构(design/contract/progress §S14)" && git push
```

---

## Self-Review(写完后自查)

**Spec coverage:**
- §3.1 懒生成 → Task 1.3 build/Get/GetForSystemPrompt + 1.10 删 Start ✓
- §3.2 mechanical only + Generator 缝 → 1.3(保留接口)+ 1.4 + 1.5(删 LLMGenerator)✓
- §3.3 sources 去 document → 1.10 / 1.12(不注册 document)+ 1.13(反转测试)✓
- §3.4 消费接口 +ctx → 1.1 + 1.7 ✓
- §3.5 struct 瘦身 → 1.1 + 2.1 ✓
- §3.6 HTTP 4→1 → 1.8 + 2.2/2.3 ✓
- §4 删除清单 → 1.2/1.5/1.6/1.9/1.10 ✓
- §7 错误处理 → 1.3(build 全失败 err / GetForSystemPrompt 吞错返 "")+ 1.8(503)✓
- §8 测试 → 1.11(单测)+ 1.13(pipeline)+ 1.14 ✓
- §9 文档 → Task 3 ✓
- §10 @ 文档 TODO → 不实现,1.10 注明 document.AsCatalogSource 保留 ✓

**Type consistency:** `GeneratedBy "mechanical"` 贯穿 1.4/1.11/1.13/2.1/2.6 ✓;`Get(ctx)`/`GetForSystemPrompt(ctx)` 在 1.3 定义、1.7/1.8/1.13 调用一致 ✓;Catalog 瘦身字段在 1.1(Go)与 2.1(TS)一致 ✓。

**Placeholder scan:** 无 TBD;测试改写给了改名 + 具体断言;文档步骤是 prose 改动(非代码步骤,允许描述)。

**Scope:** 单子系统(catalog)+ 其 API 消费方(testend)+ 文档。Task 1 因 Go 编译耦合为原子单元(故步骤多但同 commit)。
