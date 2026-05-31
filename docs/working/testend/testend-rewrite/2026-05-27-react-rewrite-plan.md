---
id: WRK-003-03
type: working
status: archived
owner: @weilin
created: 2026-05-25
reviewed: 2026-05-27
review-due: never
audience: [human, ai]
landed-into: docs/references/
---
# Testend V3 React Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite testend as React 19 / TanStack v5 / Zustand v5 / Vite 6, sharing entity TS types with frontend via vite path alias to root-cause-fix the recurring 2-week drift cycle; ride along with companion backend dev infra cleanup.

**Architecture:** testend is a flat view-driven dev tool (NOT FSD). 44 views across 6 sections. Shares only entity types + motion tokens + (newly extracted) errorCodes constants with frontend via path alias—deep `import type` to leaf `types.ts` files, never via barrel `index.ts`. testend has its own httpClient pattern, sse subscriber, zustand stores, queryKeys, ui kit. Backend gains `router.Recorder` (wrapper around `*http.ServeMux` that records registrations) so `/dev/routes` is reflection-based and stops drifting.

**Tech Stack:** React 18.3 (match frontend) + TanStack Query 5.62 + Zustand 5.0 + Vite 6.0 + react-router-dom 6 (hash mode) + lucide-react + monaco-editor + reactflow (DAG, cytoscape fallback) + TypeScript 6.0 strict.

**Spec source of truth:** [`2026-05-27-react-rewrite-design.md`](./2026-05-27-react-rewrite-design.md) (same dir). All ambiguity resolved there.

**Worktree note:** This plan executes in `../Forgify-testend` worktree on branch `testend-v3-react` (separate from parallel `e2e-overhaul` branch in `../Forgify-e2e`). Both branches FF-merge into `main` independently.

**Forbidden zones** (e2e session's territory): `backend/test/**`, `backend/cmd/coverage-matrix/`. Touch nothing inside.

**Shared file race plan**: Both branches push to their own ref; main moves only at FF-merge. No mid-flight race.

**Commit / push discipline:**
- Every task ends in 1 commit
- Push immediately after each commit (`git push origin testend-v3-react`)
- Commit messages: no `Co-Authored-By: Claude` trailer (per project memory)
- Each task self-contained (no half-states left between tasks)

**Verification gates (every task):**
- For TS files: `cd testend && npm run typecheck` (only viable after P1 done; before that, skip)
- For Go files: `cd backend && go build ./... && staticcheck ./...`
- For full backend: `make test-backend` (P0 only; after that mostly testend-only)

---

## Phase 0 — Backend Cleanup + Recorder + ErrorCodes (10 tasks, 0.5-0.75 d)

Backend changes must land first so testend builds against the cleaned-up surface. Each backend mutation is self-contained, compiles+staticcheck-clean+tests-pass before moving on.

---

### Task 0.1: Create `router.Recorder` wrapping `*http.ServeMux`

**Files:**
- Create: `backend/internal/transport/httpapi/router/recorder.go`
- Test: `backend/internal/transport/httpapi/router/recorder_test.go`

**Context:** stdlib `*http.ServeMux` has no Walk API. We need a wrapper that intercepts `HandleFunc(pattern, handler)` calls and records `(method, path)` pairs for `/dev/routes`. Pattern parses as `"<METHOD> <PATH>"` (Go 1.22+ ServeMux syntax) or pure `<PATH>` (matches all methods).

- [ ] **Step 1: Write the failing test**

```go
// backend/internal/transport/httpapi/router/recorder_test.go
package router

import (
	"net/http"
	"testing"
)

func TestRecorder_RecordsHandleFunc(t *testing.T) {
	mux := http.NewServeMux()
	rec := NewRecorder(mux)
	rec.HandleFunc("GET /api/v1/health", func(w http.ResponseWriter, r *http.Request) {})
	rec.HandleFunc("POST /api/v1/conversations", func(w http.ResponseWriter, r *http.Request) {})
	rec.HandleFunc("/api/v1/forge", func(w http.ResponseWriter, r *http.Request) {}) // no method = ANY

	routes := rec.List()
	if len(routes) != 3 {
		t.Fatalf("want 3 routes, got %d", len(routes))
	}
	if routes[0].Method != "GET" || routes[0].Path != "/api/v1/health" {
		t.Errorf("route 0: want GET /api/v1/health, got %s %s", routes[0].Method, routes[0].Path)
	}
	if routes[2].Method != "ANY" || routes[2].Path != "/api/v1/forge" {
		t.Errorf("route 2: want ANY /api/v1/forge, got %s %s", routes[2].Method, routes[2].Path)
	}
}

func TestRecorder_PassthroughToMux(t *testing.T) {
	mux := http.NewServeMux()
	rec := NewRecorder(mux)
	called := false
	rec.HandleFunc("GET /ping", func(w http.ResponseWriter, r *http.Request) {
		called = true
	})

	req, _ := http.NewRequest("GET", "/ping", nil)
	mux.ServeHTTP(&noopResponseWriter{}, req)
	if !called {
		t.Error("handler not called through underlying mux")
	}
}

type noopResponseWriter struct{ h http.Header }

func (n *noopResponseWriter) Header() http.Header {
	if n.h == nil {
		n.h = http.Header{}
	}
	return n.h
}
func (n *noopResponseWriter) Write(b []byte) (int, error) { return len(b), nil }
func (n *noopResponseWriter) WriteHeader(int)             {}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd backend && go test ./internal/transport/httpapi/router/... -run TestRecorder -v
```
Expected: FAIL with `undefined: NewRecorder` / `undefined: Recorder.HandleFunc`

- [ ] **Step 3: Implement `recorder.go`**

```go
// Package router — Recorder wraps *http.ServeMux to record (method, path) pairs.
// Lets /dev/routes return real registered routes via reflection-free record.
//
// Recorder 包装 *http.ServeMux,在 HandleFunc 时记录 method+path,
// /dev/routes 反向取列表,根本上消除手维护清单 drift。
package router

import (
	"net/http"
	"strings"
	"sync"
)

// Route is one recorded registration.
//
// Route 是一次注册记录。
type Route struct {
	Method string // "GET" / "POST" / ... / "ANY" (no-method pattern)
	Path   string // "/api/v1/health"
}

// Recorder wraps a mux and intercepts HandleFunc to record entries.
//
// Recorder 包装 mux,截获 HandleFunc 记录条目。
type Recorder struct {
	mux    *http.ServeMux
	mu     sync.RWMutex
	routes []Route
}

func NewRecorder(mux *http.ServeMux) *Recorder {
	return &Recorder{mux: mux, routes: make([]Route, 0, 64)}
}

// HandleFunc records (method, path) then forwards to underlying mux.
//
// Go 1.22+ ServeMux syntax: "GET /path" or pure "/path" (any method).
func (r *Recorder) HandleFunc(pattern string, h func(http.ResponseWriter, *http.Request)) {
	method, path := parsePattern(pattern)
	r.mu.Lock()
	r.routes = append(r.routes, Route{Method: method, Path: path})
	r.mu.Unlock()
	r.mux.HandleFunc(pattern, h)
}

// Handle records (method, path) then forwards.
//
// Handle 同 HandleFunc,接 http.Handler。
func (r *Recorder) Handle(pattern string, h http.Handler) {
	method, path := parsePattern(pattern)
	r.mu.Lock()
	r.routes = append(r.routes, Route{Method: method, Path: path})
	r.mu.Unlock()
	r.mux.Handle(pattern, h)
}

// List returns a snapshot of recorded routes.
//
// List 返回记录的路由快照。
func (r *Recorder) List() []Route {
	r.mu.RLock()
	defer r.mu.RUnlock()
	out := make([]Route, len(r.routes))
	copy(out, r.routes)
	return out
}

func parsePattern(p string) (method, path string) {
	p = strings.TrimSpace(p)
	if i := strings.IndexByte(p, ' '); i > 0 {
		return p[:i], strings.TrimSpace(p[i+1:])
	}
	return "ANY", p
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd backend && go test ./internal/transport/httpapi/router/... -run TestRecorder -v
```
Expected: PASS (2 tests)

- [ ] **Step 5: Verify build + staticcheck**

```bash
cd backend && go build ./... && staticcheck ./internal/transport/httpapi/router/...
```
Expected: 0 errors

- [ ] **Step 6: Commit**

```bash
git add backend/internal/transport/httpapi/router/recorder.go backend/internal/transport/httpapi/router/recorder_test.go
git commit -m "feat(router): add Recorder wrapping *http.ServeMux

Records (method, path) on each HandleFunc/Handle call so /dev/routes
can return real registered routes. stdlib *http.ServeMux has no Walk
API; Recorder fills the gap. Foundation for reflection-based dev_routes
(replacing hand-maintained list that drifted twice)."
git push origin testend-v3-react
```

---

### Task 0.2: Migrate `router.New` to use `Recorder`, expose `Routes()` on Handler

**Files:**
- Modify: `backend/internal/transport/httpapi/router/router.go`
- Modify: `backend/internal/transport/httpapi/router/deps.go` (add `Recorder *Recorder` field, optional)

**Context:** Currently `router.New` does `mux.HandleFunc(...)` directly via each handler's `Register(mux)`. We want every handler to register through the Recorder instead. Each handler's `Register` accepts an interface—`Registrar`—which both `*http.ServeMux` and `*Recorder` satisfy.

- [ ] **Step 1: Add `Registrar` interface in `recorder.go`**

Edit `backend/internal/transport/httpapi/router/recorder.go`, append:

```go
// Registrar is the minimal contract for route registration; satisfied by
// *http.ServeMux and *Recorder.
//
// 路由注册的最小契约;*http.ServeMux 和 *Recorder 都实现。
type Registrar interface {
	HandleFunc(pattern string, h func(http.ResponseWriter, *http.Request))
	Handle(pattern string, h http.Handler)
}
```

- [ ] **Step 2: Read each handler's `Register` signature**

```bash
grep -rn "func .*Register(mux " backend/internal/transport/httpapi/handlers/*.go | head -20
```

Confirm pattern is `Register(mux *http.ServeMux)`. Each handler file gets its signature widened to `Register(mux Registrar)` (Registrar from router pkg).

- [ ] **Step 3: Widen handler `Register` signatures (mass edit)**

For each `handlers/*.go` file with a `Register(mux *http.ServeMux)` method, change the parameter type to accept the broader interface. Use this sed-free approach (per project memory: no sed on imports):

```bash
grep -l "Register(mux \*http.ServeMux)" backend/internal/transport/httpapi/handlers/*.go
```

Then use the Edit tool, file by file, to change `Register(mux *http.ServeMux)` to `Register(mux interface{ HandleFunc(string, func(http.ResponseWriter, *http.Request)); Handle(string, http.Handler) })`.

**Simpler alternative**: define a sentinel interface alias in `handlers/registrar.go`:

```go
// backend/internal/transport/httpapi/handlers/registrar.go
package handlers

import "net/http"

// Registrar is the minimal mux-like surface handlers register against.
//
// Registrar 是 handler 注册需要的最小 mux 接口。
type Registrar interface {
	HandleFunc(pattern string, h func(http.ResponseWriter, *http.Request))
	Handle(pattern string, h http.Handler)
}
```

Then change every handler's `Register(mux *http.ServeMux)` → `Register(mux Registrar)`. About 25-30 files.

- [ ] **Step 4: Update `router.New` to use Recorder**

Edit `backend/internal/transport/httpapi/router/router.go`, in `New(deps Deps)`:

```go
func New(deps Deps) http.Handler {
	mux := deps.Mux
	if mux == nil {
		mux = http.NewServeMux()
	}
	rec := NewRecorder(mux)
	deps.Recorder = rec // expose to dev handler

	handlershttpapi.NewHealthHandler().Register(rec)
	handlershttpapi.NewProvidersHandler().Register(rec)
	// ... change every .Register(mux) to .Register(rec) below ...
```

(Read existing router.go, replace every `.Register(mux)` with `.Register(rec)` after the rec is created.)

Also add to `deps.go`:

```go
// Deps struct, add field:
Recorder *Recorder // wired by router.New; available to dev handler
```

- [ ] **Step 5: Verify build**

```bash
cd backend && go build ./...
```
Expected: 0 errors. If any handler's `Register` still expects `*http.ServeMux`, this step catches it—go back and widen the signature.

- [ ] **Step 6: Run backend tests**

```bash
make test-backend
```
Expected: 174 packages green (no regression—Recorder is additive).

- [ ] **Step 7: Commit**

```bash
git add backend/internal/transport/httpapi/router/router.go backend/internal/transport/httpapi/router/deps.go backend/internal/transport/httpapi/handlers/registrar.go backend/internal/transport/httpapi/handlers/*.go
git commit -m "refactor(router): handlers register via Registrar interface, plumbed via Recorder

router.New now wraps mux with *Recorder before passing to handler.Register.
Every handler's Register signature widened from *http.ServeMux to
the minimal Registrar interface (HandleFunc + Handle). Deps.Recorder
exposed so dev handler can read recorded routes for /dev/routes."
git push origin testend-v3-react
```

---

### Task 0.3: Rewrite `/dev/routes` handler to read `Recorder.List()`

**Files:**
- Delete: `backend/internal/transport/httpapi/handlers/dev_routes.go` (hand-maintained list)
- Modify: `backend/internal/transport/httpapi/handlers/dev.go` (where `/dev/routes` handler lives or add it there)

**Context:** Old `dev_routes.go` had a hand-maintained `[]Route{...}` slice that drifted twice. Now read from `Deps.Recorder.List()`.

- [ ] **Step 1: Read current dev_routes.go**

```bash
cat backend/internal/transport/httpapi/handlers/dev_routes.go | head -40
```

Note the exposed function name (probably `devRoutes()` or `routesHandler()`).

- [ ] **Step 2: Delete dev_routes.go**

```bash
rm backend/internal/transport/httpapi/handlers/dev_routes.go
```

- [ ] **Step 3: Add reflection-based handler in dev.go**

In `backend/internal/transport/httpapi/handlers/dev.go`, find where the dev handler registers paths (`Register(mux Registrar)` method on `DevHandler`). Add:

```go
// /dev/routes returns the live list of registered routes from Recorder.
//
// /dev/routes 从 Recorder 取实时注册路由,消除手维护 drift。
mux.HandleFunc("GET /dev/routes", h.handleRoutes)
```

And add the method (anywhere in dev.go):

```go
func (h *DevHandler) handleRoutes(w http.ResponseWriter, r *http.Request) {
	if h.recorder == nil {
		writeDevJSON(w, http.StatusInternalServerError, map[string]string{"error": "recorder unwired"})
		return
	}
	routes := h.recorder.List()
	// Stable sort: method, then path
	sort.Slice(routes, func(i, j int) bool {
		if routes[i].Method != routes[j].Method {
			return routes[i].Method < routes[j].Method
		}
		return routes[i].Path < routes[j].Path
	})
	writeDevJSON(w, http.StatusOK, routes)
}
```

Add `recorder *routerhttpapi.Recorder` field to `DevHandler` struct, wire in `NewDevHandler` and in `router.New` (after Task 0.2 added Recorder to deps):

```go
type DevHandler struct {
	// ... existing fields ...
	recorder *router.Recorder // wired by router.New
}

func NewDevHandler(deps DevDeps) *DevHandler {
	return &DevHandler{
		// ... existing ...
		recorder: deps.Recorder, // new
	}
}
```

(Field name `routerhttpapi` follows §S13 alias convention; the actual alias depends on how dev.go imports the router package—match the existing convention.)

- [ ] **Step 4: Add import for `sort` to dev.go if absent**

Verify `import "sort"` present; if not, add.

- [ ] **Step 5: Verify build**

```bash
cd backend && go build ./...
```
Expected: 0 errors

- [ ] **Step 6: Manual smoke test**

```bash
make testend &
sleep 3
curl -s http://localhost:8742/dev/routes | head -100
```
Expected: JSON array of `{method, path}` entries reflecting all registered routes (should be ~150+ entries).

```bash
make stop
```

- [ ] **Step 7: Commit**

```bash
git add backend/internal/transport/httpapi/handlers/dev.go
git rm backend/internal/transport/httpapi/handlers/dev_routes.go
git commit -m "refactor(dev): /dev/routes reads from router.Recorder.List()

Replaces hand-maintained dev_routes.go (drifted twice in 2 months).
Recorder is the live source of truth—every backend.Register goes
through it, so /dev/routes can never drift again."
git push origin testend-v3-react
```

---

### Task 0.4: Delete `/dev/collections` handler + `--collections-dir` flag + `Deps.CollectionsDir`

**Files:**
- Modify: `backend/internal/transport/httpapi/handlers/dev.go` (delete handler + field)
- Modify: `backend/internal/transport/httpapi/router/deps.go` (delete `CollectionsDir` from `DevDeps`)
- Modify: `backend/cmd/server/main.go` (delete `--collections-dir` flag, delete `gopkg.in/yaml.v3` import if unused)
- Delete: `testend/collections/` directory (empty already)

**Context:** YAML test collections were v1-era. testend V2 didn't really use them; folder is empty. Cleanup completes the deprecation.

- [ ] **Step 1: Identify the collections handler in dev.go**

```bash
grep -n "collections" backend/internal/transport/httpapi/handlers/dev.go
```

Locate the registration line (`mux.HandleFunc("...collections..."...`) and the handler method.

- [ ] **Step 2: Delete handler registration + method + field from dev.go**

Edit `backend/internal/transport/httpapi/handlers/dev.go`:
- Delete the `mux.HandleFunc("GET /dev/collections", h.handleCollections)` line (or similar)
- Delete the `handleCollections` method body
- Delete `collectionsDir string` field from `DevHandler` struct
- Delete `collectionsDir: deps.CollectionsDir,` line in `NewDevHandler`
- Delete any `yaml.v3` imports if no other handler uses YAML

- [ ] **Step 3: Delete `CollectionsDir` from deps.go**

Edit `backend/internal/transport/httpapi/router/deps.go`:
- Delete `CollectionsDir string` field

- [ ] **Step 4: Delete `--collections-dir` flag from main.go**

```bash
grep -n "collections-dir\|CollectionsDir\|collectionsDir" backend/cmd/server/main.go
```

Edit `backend/cmd/server/main.go`:
- Delete the `flag.StringVar(&collectionsDir, "collections-dir", ...)` line
- Delete the `var collectionsDir string` declaration
- Delete `deps.CollectionsDir = collectionsDir` wiring

- [ ] **Step 5: Delete testend/collections directory**

```bash
rm -rf testend/collections
```

- [ ] **Step 6: Verify build + tests**

```bash
cd backend && go build ./... && staticcheck ./...
make test-backend
```
Expected: 0 errors, 174 packages green.

- [ ] **Step 7: Commit**

```bash
git add backend/internal/transport/httpapi/handlers/dev.go backend/internal/transport/httpapi/router/deps.go backend/cmd/server/main.go
git rm -r testend/collections
git commit -m "refactor(dev): delete /dev/collections + --collections-dir flag

YAML test collections were a v1-era feature; testend V2 didn't
consume them and the testend/collections/ dir was empty. Drop the
handler, the flag, the dep field, and the dir. Yaml.v3 import goes
with it if no other handler used it."
git push origin testend-v3-react
```

---

### Task 0.5: Delete `/dev/tools` + `/dev/invoke` handlers + `Deps.Tools` field

**Files:**
- Modify: `backend/internal/transport/httpapi/handlers/dev.go`
- Modify: `backend/internal/transport/httpapi/router/deps.go`
- Modify: `backend/cmd/server/main.go` (delete `tools` wiring)

**Context:** `/dev/invoke` let v1 tester directly call a system tool, bypassing LLM. testend V3 doesn't use it; capability disclosure visualization happens in ToolCalls view via real tool registry, not via `/dev/invoke`.

- [ ] **Step 1: Find tool handler + field**

```bash
grep -n "handleTools\|handleInvoke\|/dev/tools\|/dev/invoke\|deps.Tools\|tools \[\]toolapp.Tool" backend/internal/transport/httpapi/handlers/dev.go backend/internal/transport/httpapi/router/deps.go backend/cmd/server/main.go
```

- [ ] **Step 2: Delete from dev.go**

- Delete `mux.HandleFunc("GET /dev/tools", h.handleTools)` and `mux.HandleFunc("POST /dev/invoke", h.handleInvoke)`
- Delete `handleTools` and `handleInvoke` method bodies
- Delete `tools []toolapp.Tool` field from `DevHandler` struct
- Delete `tools: deps.Tools,` in `NewDevHandler`
- Delete `toolapp` import if unused elsewhere in dev.go

- [ ] **Step 3: Delete from deps.go**

- Delete `Tools []toolapp.Tool` field
- Delete `toolapp` import if unused

- [ ] **Step 4: Delete from main.go**

- Delete `deps.Tools = ...` wiring line

- [ ] **Step 5: Verify build + tests**

```bash
cd backend && go build ./... && staticcheck ./...
make test-backend
```
Expected: 0 errors, 174 packages green.

- [ ] **Step 6: Commit**

```bash
git add backend/internal/transport/httpapi/handlers/dev.go backend/internal/transport/httpapi/router/deps.go backend/cmd/server/main.go
git commit -m "refactor(dev): delete /dev/tools + /dev/invoke + Deps.Tools

v1-era 'invoke a tool bypassing LLM' feature; testend V3 doesn't
use it. Capability disclosure (resident + lazy toolset) is now
visualized in ToolCalls view via the real tool registry."
git push origin testend-v3-react
```

---

### Task 0.6: Delete `tester.html` fallback in `dev.go::ServeIndex`

**Files:**
- Modify: `backend/internal/transport/httpapi/handlers/dev.go`

**Context:** v1 single-file `tester.html` is long-gone (deleted at V2 rewrite). `ServeIndex` still has dual-fallback `["index.html", "tester.html"]` from issue #1; just simplify to index.html-only.

- [ ] **Step 1: Find ServeIndex**

```bash
grep -n "ServeIndex\|tester.html" backend/internal/transport/httpapi/handlers/dev.go
```

- [ ] **Step 2: Edit ServeIndex**

Change the for-loop over `["index.html", "tester.html"]` to a single `index.html` read. Update the error message to drop tester.html reference.

Example before:

```go
for _, name := range []string{"index.html", "tester.html"} {
	p := filepath.Join(h.integrationDir, name)
	if data, err := os.ReadFile(p); err == nil {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Write(data)
		return
	}
}
http.Error(w, "index.html or tester.html not found; run `make build-testend`", 404)
```

After:

```go
p := filepath.Join(h.integrationDir, "index.html")
data, err := os.ReadFile(p)
if err != nil {
	http.Error(w, "testend/dist/index.html not found; run `make build-testend`", 404)
	return
}
w.Header().Set("Content-Type", "text/html; charset=utf-8")
w.Write(data)
```

- [ ] **Step 3: Verify build + tests**

```bash
cd backend && go build ./... && staticcheck ./...
make test-backend
```
Expected: 0 errors, 174 packages green.

- [ ] **Step 4: Commit**

```bash
git add backend/internal/transport/httpapi/handlers/dev.go
git commit -m "refactor(dev): ServeIndex reads only index.html (drop tester.html fallback)

v1 tester.html was deleted at V2 rewrite; the dual-fallback existed
for transition. Now testend V3 always ships Vite SPA with index.html.
Simplify to single read + clearer 404 message."
git push origin testend-v3-react
```

---

### Task 0.7: Rename `--integration-dir` flag → `--testend-dir`

**Files:**
- Modify: `backend/cmd/server/main.go`
- Modify: `backend/internal/transport/httpapi/router/deps.go` (rename `IntegrationDir` → `TestendDir`)
- Modify: `backend/internal/transport/httpapi/handlers/dev.go` (field `integrationDir` → `testendDir`)
- Modify: `Makefile` (testend target only — the user said "改 testend target 只动那一行段"—must respect)
- Modify: Any documentation referencing `--integration-dir`

**Context:** `integration-dir` was a v1-era name (testend served from `--integration-dir`). Now testend is a first-class subproject; `--testend-dir` is self-documenting.

- [ ] **Step 1: Find all references**

```bash
grep -rn "integration-dir\|IntegrationDir\|integrationDir" backend/ Makefile documents/ 2>/dev/null | grep -v -E "\.git|node_modules|legacy/"
```

- [ ] **Step 2: Rename in main.go**

Edit `backend/cmd/server/main.go`:
- `flag.StringVar(&integrationDir, "integration-dir", ...)` → `flag.StringVar(&testendDir, "testend-dir", ...)`
- `var integrationDir string` → `var testendDir string`
- `deps.IntegrationDir = integrationDir` → `deps.TestendDir = testendDir`

- [ ] **Step 3: Rename in deps.go + dev.go**

`IntegrationDir` field → `TestendDir`; `integrationDir` private field → `testendDir`; all usages.

- [ ] **Step 4: Rename in Makefile (testend target ONLY)**

```bash
grep -n "integration-dir" Makefile
```

Locate the line inside the `testend:` target. Change:
```makefile
--integration-dir $(shell pwd)/testend
```
to:
```makefile
--testend-dir $(shell pwd)/testend
```

**Do not touch any other Makefile line** (user constraint: "改 testend target 只动那一行段"). Verify diff is one line only:

```bash
git diff Makefile
```

- [ ] **Step 5: Update docs**

```bash
grep -rn "integration-dir\|integrationDir" documents/version-1.2/ 2>/dev/null
```

Edit any matching `.md` files to use the new name. Likely candidates:
- `documents/version-1.2/working/testend/testend-design.md` (V2 doc — but we're rewriting that in P4 anyway, leave for then)
- `documents/version-1.2/references/backend/api.md`
- `documents/version-1.2/desktop-packaging-notes.md` (if mentioned)

Update only the references; do not rewrite the docs in this task (P4 owns testend-design.md rewrite).

- [ ] **Step 6: Verify build + tests + manual smoke**

```bash
cd backend && go build ./... && staticcheck ./...
make test-backend
make testend & sleep 3 && curl -sf http://localhost:8742/api/v1/health && make stop
```
Expected: 0 errors, 174 packages green, health returns 200.

- [ ] **Step 7: Commit**

```bash
git add backend/cmd/server/main.go backend/internal/transport/httpapi/router/deps.go backend/internal/transport/httpapi/handlers/dev.go Makefile documents/
git commit -m "refactor(server): rename --integration-dir → --testend-dir

'integration-dir' was a v1-era name; testend is a first-class
subproject now, the flag should match. Renames flag, Deps.TestendDir,
DevHandler.testendDir, and the Makefile testend target's single
line that passes the flag. Doc references updated."
git push origin testend-v3-react
```

---

### Task 0.8: Extract `errorCodes.ts` from frontend's `errorMap.ts`

**Files:**
- Create: `frontend/src/shared/api/errorCodes.ts`
- Modify: `frontend/src/shared/api/errorMap.ts` (import from errorCodes)

**Context:** testend will display raw error codes, not i18n'd strings. We need a code-list source-of-truth that both frontend (for errorMap) and testend (for raw display) can import. Extract codes from errorMap.ts as a constants record.

- [ ] **Step 1: Read current errorMap.ts**

```bash
cat frontend/src/shared/api/errorMap.ts
```

- [ ] **Step 2: Create errorCodes.ts**

```typescript
// frontend/src/shared/api/errorCodes.ts
// Source-of-truth for backend error codes. Used by errorMap.ts (frontend
// i18n mapping) and shared cross-app (testend reads raw codes).
//
// 错误码事实源。frontend 经 errorMap 翻 i18n;testend 直接读 code 展示。

export const ERROR_CODES = {
  // Auth
  UNAUTH_NO_USER: "UNAUTH_NO_USER",

  // Conversations
  CONVERSATION_NOT_FOUND: "CONVERSATION_NOT_FOUND",

  // Chat / LLM
  STREAM_IN_PROGRESS: "STREAM_IN_PROGRESS",
  LLM_PROVIDER_ERROR: "LLM_PROVIDER_ERROR",
  LLM_AUTH_FAILED: "LLM_AUTH_FAILED",
  LLM_RATE_LIMITED: "LLM_RATE_LIMITED",
  LLM_BAD_REQUEST: "LLM_BAD_REQUEST",
  LLM_MODEL_NOT_FOUND: "LLM_MODEL_NOT_FOUND",

  // Model / API key
  MODEL_NOT_CONFIGURED: "MODEL_NOT_CONFIGURED",
  API_KEY_NOT_FOUND: "API_KEY_NOT_FOUND",
  API_KEY_PROVIDER_NOT_FOUND: "API_KEY_PROVIDER_NOT_FOUND",

  // Function / Handler / Workflow
  FUNCTION_NOT_FOUND: "FUNCTION_NOT_FOUND",
  FUNCTION_RUN_FAILED: "FUNCTION_RUN_FAILED",
  HANDLER_NOT_FOUND: "HANDLER_NOT_FOUND",
  WORKFLOW_NOT_FOUND: "WORKFLOW_NOT_FOUND",

  // Internal
  INTERNAL_ERROR: "INTERNAL_ERROR",

  // Network / HTTP (client-side synth)
  NETWORK: "NETWORK",
} as const;

export type ErrorCode = keyof typeof ERROR_CODES;
```

- [ ] **Step 3: Refactor errorMap.ts to use ERROR_CODES**

```typescript
// frontend/src/shared/api/errorMap.ts
import { ERROR_CODES, type ErrorCode } from "./errorCodes";

const CODE_TO_KEY: Record<ErrorCode, string> = {
  UNAUTH_NO_USER: "errors:UNAUTH_NO_USER",
  CONVERSATION_NOT_FOUND: "errors:CONVERSATION_NOT_FOUND",
  STREAM_IN_PROGRESS: "errors:STREAM_IN_PROGRESS",
  LLM_PROVIDER_ERROR: "errors:LLM_PROVIDER_ERROR",
  LLM_AUTH_FAILED: "errors:LLM_AUTH_FAILED",
  LLM_RATE_LIMITED: "errors:LLM_RATE_LIMITED",
  LLM_BAD_REQUEST: "errors:LLM_BAD_REQUEST",
  LLM_MODEL_NOT_FOUND: "errors:LLM_MODEL_NOT_FOUND",
  MODEL_NOT_CONFIGURED: "errors:MODEL_NOT_CONFIGURED",
  API_KEY_NOT_FOUND: "errors:API_KEY_NOT_FOUND",
  API_KEY_PROVIDER_NOT_FOUND: "errors:API_KEY_PROVIDER_NOT_FOUND",
  FUNCTION_NOT_FOUND: "errors:FUNCTION_NOT_FOUND",
  FUNCTION_RUN_FAILED: "errors:FUNCTION_RUN_FAILED",
  HANDLER_NOT_FOUND: "errors:HANDLER_NOT_FOUND",
  WORKFLOW_NOT_FOUND: "errors:WORKFLOW_NOT_FOUND",
  INTERNAL_ERROR: "errors:INTERNAL_ERROR",
  NETWORK: "errors:NETWORK",
};

const FALLBACK_KEY = "errors:fallback";

export function errorKey(code: string): string {
  return CODE_TO_KEY[code as ErrorCode] ?? FALLBACK_KEY;
}

export function kindForCode(code: string): "error" | "warn" {
  if (code === ERROR_CODES.CONVERSATION_NOT_FOUND) return "warn";
  return "error";
}

// Re-export for backward compat
export { ERROR_CODES, type ErrorCode };
```

- [ ] **Step 4: Verify frontend typecheck**

```bash
cd frontend && npm run typecheck
```
Expected: 0 errors. If anywhere imports `ERROR_CODES` from errorMap.ts (unlikely but possible), the re-export handles it.

- [ ] **Step 5: Verify frontend tests + build**

```bash
cd frontend && npm test -- --run && npm run build
```
Expected: vitest green, build clean.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/shared/api/errorCodes.ts frontend/src/shared/api/errorMap.ts
git commit -m "feat(frontend/shared): extract errorCodes.ts as source of truth

Both frontend (errorMap → i18n) and testend (raw display) need the
backend error code list. Extract as ERROR_CODES const + ErrorCode
type union; errorMap.ts now consumes it instead of duplicating
string literals. testend will import via vite path alias next."
git push origin testend-v3-react
```

---

### Task 0.9: P0 final verification

**Files:** (none modified — verify only)

- [ ] **Step 1: Full backend regression**

```bash
cd backend && go build ./... && staticcheck ./... && cd ..
make test-backend
```
Expected: 0 errors, 174 packages green.

- [ ] **Step 2: Full frontend regression**

```bash
cd frontend && npm run typecheck && npm test -- --run && npm run build
```
Expected: 0 errors, vitest green, build clean.

- [ ] **Step 3: Smoke test backend boots clean**

```bash
make stop  # in case anything stale
make testend & sleep 4
curl -sf http://localhost:8742/api/v1/health | head -3
curl -sf http://localhost:8742/dev/routes | head -3
curl -sf http://localhost:8742/dev/info | head -3
make stop
```
Expected: health 200, /dev/routes returns reflection-based list, /dev/info works.

- [ ] **Step 4: Confirm deletions stuck**

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8742/dev/collections  # via re-start backend if needed
# Or grep:
grep -r "handleCollections\|handleTools\|handleInvoke\|CollectionsDir\|deps.Tools" backend/internal/ | head -5
```
Expected: 0 matches.

- [ ] **Step 5: No commit (verify-only task)**

(P0 is sealed; next task starts P1.)

---

## Phase 0 done. P0 commits land on `testend-v3-react`. Push trail visible on GitHub. e2e session unaffected (forbidden zones not touched).

---

## Phase 1 — Testend Scaffold (7 tasks, 0.5 d)

Tear down V2 Vue testend, scaffold React/Vite/TS frame with all 44 routes as placeholders. After P1, `npm run typecheck && npm run build` is clean; nothing renders real data yet.

---

### Task 1.1: Tear down V2 Vue testend

**Files:** (delete)
- `testend/src/` (entire dir)
- `testend/collections/` (already deleted in P0)
- `testend/package.json`
- `testend/package-lock.json`
- `testend/vite.config.ts`
- `testend/tsconfig.json`
- `testend/tsconfig.node.json`
- `testend/index.html`
- `testend/eslint.config.js` (if exists)

**Files:** (preserve)
- `testend/.gitignore` (if exists)

**Context:** Greenfield — no Vue residue. V2 reference available via `git show HEAD~N:testend/src/views/...` during P3 if a specific view's V2 implementation is useful.

- [ ] **Step 1: Confirm what's there**

```bash
ls -la testend/
```

- [ ] **Step 2: Remove**

```bash
git rm -rf testend/src testend/package.json testend/package-lock.json testend/vite.config.ts testend/tsconfig.json testend/tsconfig.node.json testend/index.html
[ -f testend/eslint.config.js ] && git rm testend/eslint.config.js
git status
```
Expected: `D` rows for each removed file/dir; `testend/.gitignore` (if present) untouched.

- [ ] **Step 3: Commit (intermediate, kept atomic to ease review)**

```bash
git commit -m "chore(testend): tear down V2 Vue scaffold

Greenfield prep for V3 React rewrite. V2 view code remains accessible
via git history (\`git show HEAD~N:testend/src/views/<name>.vue\`)."
git push origin testend-v3-react
```

---

### Task 1.2: Write `testend/package.json`

**Files:**
- Create: `testend/package.json`

**Context:** Version-pin to frontend's exact dep versions for React/TanStack/Zustand to avoid "Multiple React instances" runtime errors. Read frontend/package.json first.

- [ ] **Step 1: Read frontend/package.json for version reference**

```bash
cat frontend/package.json
```
Note: React 18.3.1, TanStack 5.62, Zustand 5.0, Vite 6, TypeScript 6.0, lucide-react 0.468, framer-motion 11.13, vite-tsconfig-paths 6.1.

- [ ] **Step 2: Write testend/package.json**

```json
{
  "name": "forgify-testend",
  "version": "3.0.0",
  "private": true,
  "type": "module",
  "description": "Forgify dev control panel V3 — React rewrite sharing entity types with frontend",
  "scripts": {
    "dev": "vite",
    "build": "tsc --noEmit && vite build",
    "build:nocheck": "vite build",
    "preview": "vite preview",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@monaco-editor/react": "^4.6.0",
    "@tanstack/react-query": "^5.62.0",
    "lucide-react": "^0.468.0",
    "monaco-editor": "^0.52.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.28.0",
    "reactflow": "^11.11.0",
    "zustand": "^5.0.2"
  },
  "devDependencies": {
    "@types/react": "^18.3.29",
    "@types/react-dom": "^18.3.7",
    "@vitejs/plugin-react": "^4.3.4",
    "typescript": "^6.0.3",
    "vite": "^6.0.5",
    "vite-tsconfig-paths": "^6.1.1"
  }
}
```

- [ ] **Step 3: Install deps**

```bash
cd testend && npm install
```
Expected: succeeds; `testend/node_modules` populated; `testend/package-lock.json` created.

- [ ] **Step 4: Sanity check React version match**

```bash
cd testend && npm ls react
cd ../frontend && npm ls react
```
Expected: both show `react@18.3.1`. (If mismatch, fix testend/package.json to match frontend.)

- [ ] **Step 5: Commit**

```bash
cd /Users/SP14921/Documents/Personal/PersonalCodeBase/Forgify-testend
git add testend/package.json testend/package-lock.json
git commit -m "feat(testend): scaffold V3 package.json (React + TanStack + Zustand + Vite)

Versions pinned to match frontend exactly: React 18.3.1, TanStack 5.62,
Zustand 5.0.2, Vite 6.0.5, TS 6.0.3. Adds react-router-dom (hash),
monaco-editor + reactflow for dev tooling, vite-tsconfig-paths for
alias resolution. node_modules separate from frontend; shared via
path alias in next task."
git push origin testend-v3-react
```

---

### Task 1.3: Write `testend/vite.config.ts` with frontend path alias

**Files:**
- Create: `testend/vite.config.ts`

**Context:** Vite's `resolve.alias` maps `@frontend/*` to `../frontend/src/*`. Combined with `vite-tsconfig-paths`, this lets testend `import type { Conversation } from "@frontend/entities/conversation/model/types"`.

- [ ] **Step 1: Write vite.config.ts**

```typescript
// testend/vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tsconfigPaths from "vite-tsconfig-paths";
import path from "node:path";

// V3 testend — shares entity types with frontend via path alias.
// type-only deep imports: @frontend/entities/<x>/model/types.
//
// V3 testend 通过 vite alias 共享 frontend entity 类型;只深引 type 文件。
export default defineConfig({
  base: "/dev/",
  plugins: [react(), tsconfigPaths()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "src"),
      "@frontend": path.resolve(__dirname, "../frontend/src"),
    },
  },
  build: {
    outDir: "dist",
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          monaco: ["monaco-editor", "@monaco-editor/react"],
          reactflow: ["reactflow"],
        },
      },
    },
  },
  server: {
    port: 5174,
    proxy: {
      "/api": "http://localhost:8742",
      "/dev/logs": { target: "http://localhost:8742", changeOrigin: true, ws: false },
      "/dev/info": "http://localhost:8742",
      "/dev/runtime": "http://localhost:8742",
      "/dev/sql": "http://localhost:8742",
      "/dev/routes": "http://localhost:8742",
      "/dev/forgify-home": "http://localhost:8742",
      "/dev/bash-processes": "http://localhost:8742",
      "/dev/mock-llm": "http://localhost:8742",
      "/dev/llm": "http://localhost:8742",
    },
  },
});
```

- [ ] **Step 2: Commit**

```bash
git add testend/vite.config.ts
git commit -m "feat(testend): vite.config.ts — alias @frontend, manual chunks for monaco/reactflow

base /dev/ matches backend serve path. @frontend alias resolves to
../frontend/src so testend can deep-import entity TS types via
@frontend/entities/<x>/model/types. Manual chunks isolate monaco
and reactflow so the main bundle stays lean."
git push origin testend-v3-react
```

---

### Task 1.4: Write `testend/tsconfig.json` + `tsconfig.node.json` with matching paths

**Files:**
- Create: `testend/tsconfig.json`
- Create: `testend/tsconfig.node.json`

- [ ] **Step 1: Write tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2023", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "noUncheckedIndexedAccess": false,
    "exactOptionalPropertyTypes": false,
    "noEmit": true,
    "allowImportingTsExtensions": false,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "verbatimModuleSyntax": false,
    "useDefineForClassFields": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"],
      "@frontend/*": ["../frontend/src/*"]
    }
  },
  "include": ["src", "vite.config.ts"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

- [ ] **Step 2: Write tsconfig.node.json**

```json
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true,
    "strict": true
  },
  "include": ["vite.config.ts"]
}
```

- [ ] **Step 3: Run typecheck (will fail — no source yet)**

```bash
cd testend && npm run typecheck
```
Expected: ERROR `No inputs were found in config file`. That's OK — no src files yet. Next task adds the first src.

- [ ] **Step 4: Commit**

```bash
git add testend/tsconfig.json testend/tsconfig.node.json
git commit -m "feat(testend): tsconfig with @ + @frontend path aliases

strict: true. paths sync with vite.config.ts alias so IDE and
typecheck agree. tsconfig.node.json for vite.config.ts."
git push origin testend-v3-react
```

---

### Task 1.5: Write `testend/index.html` + `src/main.tsx`

**Files:**
- Create: `testend/index.html`
- Create: `testend/src/main.tsx`

- [ ] **Step 1: Write index.html**

```html
<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Forgify Dev Console (V3)</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

- [ ] **Step 2: Write main.tsx**

```tsx
// testend/src/main.tsx
import React from "react";
import ReactDOM from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider } from "react-router-dom";
import { router } from "./router";
import "./style.css";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      refetchOnWindowFocus: false,
      retry: 1,
    },
  },
});

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  </React.StrictMode>,
);
```

- [ ] **Step 3: Commit (typecheck still fails — router/style.css not yet there; fine)**

```bash
git add testend/index.html testend/src/main.tsx
git commit -m "feat(testend): index.html + main.tsx entry

QueryClient (30s staleTime, 1 retry, no refocus refetch).
RouterProvider wires the hash router (added next task)."
git push origin testend-v3-react
```

---

### Task 1.6: Write `testend/src/style.css` (tokens from frontend)

**Files:**
- Create: `testend/src/style.css`

**Context:** Copy frontend's CSS token system (light/dark, density, accent, motion) so testend visual language matches. Add testend-specific: 4-column layout, dense table styles, raw json viewer.

- [ ] **Step 1: Read frontend tokens**

```bash
ls frontend/src/styles/
cat frontend/src/styles/tokens.css | head -80
```

- [ ] **Step 2: Write style.css**

```css
/* testend/src/style.css — V3 visual tokens (mirrors frontend) + 4-col layout */

@import url("https://rsms.me/inter/inter.css");

:root {
  --t-fast: 120ms cubic-bezier(.2,.8,.2,1);
  --t-med: 220ms cubic-bezier(.2,.8,.2,1);
  --t-slow: 360ms cubic-bezier(.2,.8,.2,1);

  --bg-window: #fdfcf9;
  --bg-sidebar: #f5f3ee;
  --bg-paper: #ffffff;
  --bg-elev: #f5f3ee;
  --bg-elev-2: #ebe7df;

  --fg-strong: #1a1816;
  --fg-body: #3c3a36;
  --fg-muted: #6b6862;
  --fg-faint: #9b988f;

  --border: #e0dcd2;
  --border-strong: #cac4b5;
  --border-soft: #ede9df;

  --accent: #d97757;
  --accent-soft: #fde8dd;
  --accent-fg: #ffffff;
  --accent-ring: rgba(217, 119, 87, 0.3);

  --status-streaming: #d97757;
  --status-success: #4a8c4a;
  --status-error: #c43d3d;
  --status-warn: #d4a017;
  --status-info: #4a7cc4;

  --row-h: 28px;
  --col-conv: 200px;
  --col-chat: 420px;
  --col-nav: 220px;

  --mono: "JetBrains Mono", "SF Mono", Menlo, ui-monospace, monospace;
  --sans: "Inter", system-ui, -apple-system, "PingFang SC", "Microsoft YaHei", sans-serif;
}

:root[data-theme="dark"] {
  --bg-window: #1a1816;
  --bg-sidebar: #211f1c;
  --bg-paper: #25221e;
  --bg-elev: #2c2925;
  --bg-elev-2: #35312c;

  --fg-strong: #f5f3ee;
  --fg-body: #d4d0c5;
  --fg-muted: #8a867d;
  --fg-faint: #5d5a52;

  --border: #35312c;
  --border-strong: #4a463f;
  --border-soft: #2c2925;
}

* {
  box-sizing: border-box;
}

html, body, #root {
  height: 100%;
  margin: 0;
}

body {
  font-family: var(--sans);
  background: var(--bg-window);
  color: var(--fg-body);
  font-size: 13px;
  line-height: 1.45;
}

/* 4-column layout */
.app-root {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
}

.layout {
  flex: 1;
  display: flex;
  min-height: 0;
}

.tab-content {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  background: var(--bg-paper);
  overflow: hidden;
}

/* dense tables for dev views */
.dt {
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
}
.dt th, .dt td {
  padding: 4px 8px;
  border-bottom: 1px solid var(--border-soft);
  text-align: left;
  vertical-align: top;
}
.dt th {
  background: var(--bg-elev);
  font-weight: 500;
  color: var(--fg-muted);
}
.dt tr:hover td {
  background: var(--bg-elev);
}

/* raw json viewer */
.raw-json {
  font-family: var(--mono);
  font-size: 12px;
  white-space: pre-wrap;
  word-break: break-word;
  background: var(--bg-elev);
  padding: 8px 12px;
  border-radius: 4px;
  color: var(--fg-body);
}

/* status pills */
.pill {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 500;
  background: var(--bg-elev);
  color: var(--fg-muted);
}
.pill.success { background: rgba(74, 140, 74, 0.15); color: var(--status-success); }
.pill.error { background: rgba(196, 61, 61, 0.15); color: var(--status-error); }
.pill.warn { background: rgba(212, 160, 23, 0.15); color: var(--status-warn); }
.pill.streaming { background: var(--accent-soft); color: var(--accent); }

/* utility */
.muted { color: var(--fg-muted); }
.mono { font-family: var(--mono); }
.center { display: flex; align-items: center; justify-content: center; height: 100%; }
.empty {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: var(--fg-faint);
  font-size: 13px;
}
```

- [ ] **Step 3: Commit**

```bash
git add testend/src/style.css
git commit -m "feat(testend): style.css — tokens + 4-col layout primitives

Light/dark theme via [data-theme]; dense table (.dt), raw-json,
status pills, layout shell. JetBrains Mono for raw views; Inter
for UI. Tokens align with frontend's palette so visual language
matches."
git push origin testend-v3-react
```

---

### Task 1.7: Write `testend/src/App.tsx` + `src/router.tsx` (44 placeholder routes)

**Files:**
- Create: `testend/src/App.tsx`
- Create: `testend/src/router.tsx`

**Context:** App.tsx is the 4-column shell skeleton (will get real layout components in P2). router.tsx maps all 44 routes to placeholder views.

- [ ] **Step 1: Write App.tsx (minimal shell)**

```tsx
// testend/src/App.tsx
import { Outlet } from "react-router-dom";

// 4-column shell. Real TopBar / ConvSidebar / ChatPanel / TabNav land in P2.
//
// 4 列骨架;真正的 TopBar / ConvSidebar / ChatPanel / TabNav 在 P2 实装。
export function App() {
  return (
    <div className="app-root">
      <div style={{ height: 36, borderBottom: "1px solid var(--border)", padding: "0 12px", display: "flex", alignItems: "center", fontSize: 12, color: "var(--fg-muted)" }}>
        Forgify Dev Console V3 — scaffold (P1)
      </div>
      <div className="layout">
        <aside style={{ width: 200, borderRight: "1px solid var(--border)", background: "var(--bg-sidebar)" }}>
          <div className="empty">col1 (P2)</div>
        </aside>
        <section style={{ width: 420, borderRight: "1px solid var(--border)" }}>
          <div className="empty">col2 chat (P2)</div>
        </section>
        <aside style={{ width: 220, borderRight: "1px solid var(--border)", background: "var(--bg-sidebar)" }}>
          <div className="empty">col3 nav (P2)</div>
        </aside>
        <main className="tab-content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Write router.tsx (44 placeholder routes)**

```tsx
// testend/src/router.tsx
import { createHashRouter, Navigate } from "react-router-dom";
import { App } from "./App";

// Placeholder until P3 ships the real view.
// 占位;P3 实装真 view。
function Placeholder({ name }: { name: string }) {
  return <div className="empty">TODO: {name}</div>;
}

export const router = createHashRouter([
  {
    path: "/",
    element: <App />,
    children: [
      { index: true, element: <Navigate to="/forge/functions" replace /> },

      // current/ (9)
      { path: "current/wire",          element: <Placeholder name="current/WireTrace" /> },
      { path: "current/eventlog",      element: <Placeholder name="current/EventlogRaw" /> },
      { path: "current/notifications", element: <Placeholder name="current/Notifications" /> },
      { path: "current/subagents",     element: <Placeholder name="current/SubAgents" /> },
      { path: "current/tools",         element: <Placeholder name="current/ToolCalls" /> },
      { path: "current/todos",         element: <Placeholder name="current/Todos" /> },
      { path: "current/asks",          element: <Placeholder name="current/AsksPending" /> },
      { path: "current/attachments",   element: <Placeholder name="current/Attachments" /> },
      { path: "current/compaction",    element: <Placeholder name="current/Compaction" /> },

      // forge/ (7 — TestCollections deleted)
      { path: "forge/functions",       element: <Placeholder name="forge/Functions" /> },
      { path: "forge/functions/:id",   element: <Placeholder name="forge/FunctionDetail" /> },
      { path: "forge/handlers",        element: <Placeholder name="forge/Handlers" /> },
      { path: "forge/handlers/:id",    element: <Placeholder name="forge/HandlerDetail" /> },
      { path: "forge/workflows",       element: <Placeholder name="forge/Workflows" /> },
      { path: "forge/workflows/:id",   element: <Placeholder name="forge/WorkflowDetail" /> },
      { path: "forge/tools",           element: <Placeholder name="forge/ToolsRegistry" /> },

      // execute/ (5)
      { path: "execute/triggers",      element: <Placeholder name="execute/Triggers" /> },
      { path: "execute/flowruns",      element: <Placeholder name="execute/FlowRuns" /> },
      { path: "execute/flowruns/:id",  element: <Placeholder name="execute/FlowRunDetail" /> },
      { path: "execute/approvals",     element: <Placeholder name="execute/ApprovalsQueue" /> },
      { path: "execute/executions",    element: <Placeholder name="execute/Executions" /> },

      // observe/ (5)
      { path: "observe/live",          element: <Placeholder name="observe/LiveSSE" /> },
      { path: "observe/notifications", element: <Placeholder name="observe/NotificationHistory" /> },
      { path: "observe/catalog",       element: <Placeholder name="observe/Catalog" /> },
      { path: "observe/usage",         element: <Placeholder name="observe/Usage" /> },
      { path: "observe/mock-llm",      element: <Placeholder name="observe/MockLLM" /> },

      // config/ (10)
      { path: "config/apikeys",        element: <Placeholder name="config/ApiKeys" /> },
      { path: "config/models",         element: <Placeholder name="config/ModelConfigs" /> },
      { path: "config/skills",         element: <Placeholder name="config/Skills" /> },
      { path: "config/mcp",            element: <Placeholder name="config/MCPServers" /> },
      { path: "config/sandbox",        element: <Placeholder name="config/Sandbox" /> },
      { path: "config/memory",         element: <Placeholder name="config/Memory" /> },
      { path: "config/documents",      element: <Placeholder name="config/Documents" /> },
      { path: "config/permissions",    element: <Placeholder name="config/Permissions" /> },
      { path: "config/llm-health",     element: <Placeholder name="config/LLMHealth" /> },
      { path: "config/profile",        element: <Placeholder name="config/Profile" /> },

      // dev/ (8)
      { path: "dev/sql",               element: <Placeholder name="dev/SQL" /> },
      { path: "dev/info",              element: <Placeholder name="dev/Info" /> },
      { path: "dev/routes",            element: <Placeholder name="dev/Routes" /> },
      { path: "dev/logs",              element: <Placeholder name="dev/BackendLogs" /> },
      { path: "dev/processes",         element: <Placeholder name="dev/Processes" /> },
      { path: "dev/metrics",           element: <Placeholder name="dev/Metrics" /> },
      { path: "dev/errors",            element: <Placeholder name="dev/Errors" /> },
      { path: "dev/prompts",           element: <Placeholder name="dev/Prompts" /> },

      // catch-all → /forge/functions
      { path: "*", element: <Navigate to="/forge/functions" replace /> },
    ],
  },
]);
```

- [ ] **Step 3: Typecheck + build**

```bash
cd testend && npm run typecheck && npm run build
```
Expected: 0 errors, build produces `dist/` with `index.html` + chunked JS.

- [ ] **Step 4: Manual smoke**

```bash
make testend & sleep 4
open http://localhost:8742/dev/
```
Expected: browser shows 4-column shell with "scaffold (P1)" topbar, navigating between `/dev/#/forge/functions`, `/dev/#/current/wire`, etc. all render the `TODO: <name>` placeholder.

```bash
make stop
```

- [ ] **Step 5: Commit**

```bash
git add testend/src/App.tsx testend/src/router.tsx
git commit -m "feat(testend): App.tsx 4-col shell + router.tsx with 44 routes

Hash router. All 44 placeholder routes wired; clicking any URL shows
'TODO: section/View'. Real layout + views land in P2 & P3.
Build clean: dist/ ~150KB scaffold + monaco/reactflow chunked lazy."
git push origin testend-v3-react
```

---

## Phase 1 done. 44 routes navigable as placeholders. Typecheck + build green. Next: P2 wires real data infra.

---

## Phase 2 — Infrastructure (15 tasks, 1 d)

API client, SSE, stores, hooks, layout components, ui kit. After P2: 4-column shell shows real conv list / chat panel / nav. Each placeholder route still placeholder but infra ready.

---

### Task 2.1: Write `src/api/devClient.ts` (HTTP client + envelope unwrap + ApiError)

**Files:**
- Create: `testend/src/api/devClient.ts`

**Context:** Wraps `fetch`, unwraps `{data, error}` envelope. Reads active userID from `usersStore` (P2.4). Re-throws `ApiError{code, message, status}` on failure. Used by all api/*.ts files.

- [ ] **Step 1: Write devClient.ts**

```typescript
// testend/src/api/devClient.ts
// HTTP client — wraps fetch, unwraps {data, error} envelope, attaches
// X-Forgify-User-ID header from usersStore active selection.
//
// HTTP 客户端;解 envelope,注 X-Forgify-User-ID。
import { useUsersStore } from "@/stores/users";

export interface ApiErrorShape {
  code: string;
  message: string;
  details?: unknown;
}

export class ApiError extends Error {
  code: string;
  status: number;
  details?: unknown;
  constructor(payload: ApiErrorShape, status: number) {
    super(payload.message);
    this.code = payload.code;
    this.status = status;
    this.details = payload.details;
  }
}

export interface PageResponse<T> {
  data: T[];
  nextCursor?: string;
  hasMore?: boolean;
}

function activeUserHeader(): HeadersInit {
  const uid = useUsersStore.getState().activeId;
  return uid ? { "X-Forgify-User-ID": uid } : {};
}

async function request<T>(
  method: string,
  path: string,
  body?: unknown,
  extraHeaders?: HeadersInit,
): Promise<T> {
  const res = await fetch(path, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...activeUserHeader(),
      ...extraHeaders,
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
  if (res.status === 204) return undefined as T;
  // dev/* endpoints return raw JSON (no envelope) — content-type sniff
  const ct = res.headers.get("content-type") || "";
  if (!ct.includes("application/json")) {
    if (!res.ok) throw new ApiError({ code: "NETWORK", message: res.statusText }, res.status);
    return (await res.text()) as unknown as T;
  }
  const json = await res.json();
  if (!res.ok) {
    const err = (json?.error ?? { code: "NETWORK", message: res.statusText }) as ApiErrorShape;
    throw new ApiError(err, res.status);
  }
  // Either {data: T} envelope (api/v1/*) or raw T (dev/*).
  if (Object.prototype.hasOwnProperty.call(json, "data")) return json.data as T;
  return json as T;
}

export const getJSON  = <T>(path: string) => request<T>("GET", path);
export const postJSON = <T>(path: string, body?: unknown) => request<T>("POST", path, body);
export const patchJSON = <T>(path: string, body?: unknown) => request<T>("PATCH", path, body);
export const putJSON  = <T>(path: string, body?: unknown) => request<T>("PUT", path, body);
export const delJSON  = <T>(path: string) => request<T>("DELETE", path);

// Paged GET — returns {data: T[], nextCursor, hasMore} envelope unwrapped.
export async function getPage<T>(
  path: string,
  query?: Record<string, string | number | undefined>,
): Promise<PageResponse<T>> {
  const qs = query
    ? "?" + Object.entries(query)
        .filter(([, v]) => v !== undefined && v !== "")
        .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`)
        .join("&")
    : "";
  const res = await fetch(path + qs, { headers: activeUserHeader() });
  const json = await res.json();
  if (!res.ok) throw new ApiError(json?.error ?? { code: "NETWORK", message: res.statusText }, res.status);
  return { data: json.data ?? [], nextCursor: json.nextCursor, hasMore: json.hasMore ?? false };
}
```

- [ ] **Step 2: Commit (typecheck still fails — usersStore not yet there; merge with 2.4)**

Skip typecheck for now; commit and move on. Will pass after 2.4.

```bash
git add testend/src/api/devClient.ts
git commit -m "feat(testend/api): devClient with envelope unwrap + ApiError + X-Forgify-User-ID"
git push origin testend-v3-react
```

---

### Task 2.2: Write `src/stores/users.ts` (Zustand, multi-profile)

**Files:**
- Create: `testend/src/stores/users.ts`

**Context:** Lightweight Zustand store with persisted `activeId`. Fetches `/api/v1/users` to populate `list`. devClient depends on `activeId` for header.

- [ ] **Step 1: Write stores/users.ts**

```typescript
// testend/src/stores/users.ts
// Multi-profile user store. activeId persisted to localStorage; list
// fetched fresh on bootstrap from /api/v1/users.
//
// Multi-profile;activeId 持久化,list 启动时 fetch。
import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { User } from "@frontend/entities/user/model/types";

interface State {
  list: User[];
  activeId: string | null;
  refresh: () => Promise<void>;
  setActive: (id: string) => void;
}

export const useUsersStore = create<State>()(
  persist(
    (set, get) => ({
      list: [],
      activeId: null,
      refresh: async () => {
        const res = await fetch("/api/v1/users");
        const json = await res.json();
        const list: User[] = json.data ?? [];
        set({ list });
        // Auto-pick if single profile and no active.
        if (list.length === 1 && !get().activeId) {
          set({ activeId: list[0]!.id });
        }
        // Clear stale activeId (user deleted out-of-band).
        if (get().activeId && !list.some((u) => u.id === get().activeId)) {
          set({ activeId: null });
        }
      },
      setActive: (id) => set({ activeId: id }),
    }),
    { name: "testend-active-user", partialize: (s) => ({ activeId: s.activeId }) },
  ),
);
```

- [ ] **Step 2: Typecheck**

```bash
cd testend && npm run typecheck
```
Expected: PASS (devClient + usersStore now compile together).

- [ ] **Step 3: Commit**

```bash
git add testend/src/stores/users.ts
git commit -m "feat(testend/stores): users store (Zustand + persist activeId)

Imports User type from @frontend/entities/user/model/types via path
alias — proves type sharing works end-to-end. Auto-picks single
profile; clears stale activeId if user deleted out-of-band."
git push origin testend-v3-react
```

---

### Task 2.3: Write `src/api/sse.ts` (3-stream shared subscriber)

**Files:**
- Create: `testend/src/api/sse.ts`

**Context:** Fan-out subscribe pattern (same as V2): single `EventSource` per stream, multiple listeners share it. Streams: `eventlog` / `notifications` / `forge`. EventSource auto-reconnects on transient errors via `Last-Event-ID`; on 410 (SEQ_TOO_OLD) we reset to 0 + manually reopen.

- [ ] **Step 1: Write sse.ts** (mostly mirrors V2 but in TS module style)

```typescript
// testend/src/api/sse.ts
// Three per-user backend streams, single EventSource each, fan-out
// to multiple view listeners (saves the browser's 6 connection budget).
//
// 三流 fan-out;每流单 EventSource;按 user_id key,无 query 参。
import { useUsersStore } from "@/stores/users";

export type StreamID = "eventlog" | "notifications" | "forge";

export interface StreamEvent<T = unknown> {
  event: string;
  id: number;
  data: T;
  receivedAt: number;
}

type Listener = (e: StreamEvent) => void;

interface Channel {
  url: string;
  es: EventSource | null;
  lastEventId: number;
  listeners: Set<Listener>;
  connected: boolean;
  connectedAt?: number;
  lastError?: string;
}

const URLS: Record<StreamID, string> = {
  eventlog: "/api/v1/eventlog",
  notifications: "/api/v1/notifications",
  forge: "/api/v1/forge",
};

const EVENT_NAMES: Record<StreamID, string[]> = {
  eventlog: ["message_start", "message_stop", "block_start", "block_delta", "block_stop"],
  notifications: ["notification"],
  forge: ["forge_started", "forge_op_applied", "forge_env_attempt", "forge_completed"],
};

const channels: Record<StreamID, Channel> = {
  eventlog: blank("eventlog"),
  notifications: blank("notifications"),
  forge: blank("forge"),
};

function blank(s: StreamID): Channel {
  return { url: URLS[s], es: null, lastEventId: 0, listeners: new Set(), connected: false };
}

function connect(stream: StreamID) {
  const ch = channels[stream];
  if (ch.es) return;
  const uid = useUsersStore.getState().activeId;
  const url = uid ? `${ch.url}?userID=${encodeURIComponent(uid)}` : ch.url;
  const es = new EventSource(url, { withCredentials: false });
  ch.es = es;
  ch.connected = false;

  es.onopen = () => {
    ch.connected = true;
    ch.connectedAt = Date.now();
    ch.lastError = undefined;
  };

  es.onerror = () => {
    ch.connected = false;
    ch.lastError = "connection error / 410 SEQ_TOO_OLD likely; reconnecting…";
    if (ch.es) {
      ch.es.close();
      ch.es = null;
    }
    setTimeout(() => {
      if (ch.listeners.size > 0) {
        ch.lastEventId = 0;
        connect(stream);
      }
    }, 1000);
  };

  es.onmessage = (ev) => fanOut(stream, "message", ev);
  for (const name of EVENT_NAMES[stream]) {
    es.addEventListener(name, (ev) => fanOut(stream, name, ev as MessageEvent));
  }
}

function fanOut(stream: StreamID, eventName: string, ev: MessageEvent) {
  const ch = channels[stream];
  let parsed: unknown = ev.data;
  try {
    parsed = JSON.parse(ev.data as string);
  } catch {
    /* keep raw */
  }
  const id = ev.lastEventId ? Number(ev.lastEventId) : 0;
  if (id > ch.lastEventId) ch.lastEventId = id;
  const wrapped: StreamEvent = { event: eventName, id, data: parsed, receivedAt: Date.now() };
  for (const fn of ch.listeners) {
    try { fn(wrapped); } catch (e) { console.error(`[sse:${stream}]`, e); }
  }
}

export function subscribe(stream: StreamID, fn: Listener): () => void {
  const ch = channels[stream];
  ch.listeners.add(fn);
  if (!ch.es) connect(stream);
  return () => {
    ch.listeners.delete(fn);
    if (ch.listeners.size === 0 && ch.es) {
      ch.es.close();
      ch.es = null;
      ch.connected = false;
    }
  };
}

export function status(stream: StreamID) {
  const ch = channels[stream];
  return {
    connected: ch.connected,
    connectedAt: ch.connectedAt,
    listenerCount: ch.listeners.size,
    lastEventId: ch.lastEventId,
    lastError: ch.lastError,
  };
}

export function reconnect(stream: StreamID) {
  const ch = channels[stream];
  if (ch.es) {
    ch.es.close();
    ch.es = null;
  }
  ch.lastEventId = 0;
  if (ch.listeners.size > 0) connect(stream);
}
```

- [ ] **Step 2: Typecheck + commit**

```bash
cd testend && npm run typecheck
```
Expected: PASS.

```bash
git add testend/src/api/sse.ts
git commit -m "feat(testend/api): 3-stream SSE subscriber (fan-out, auto-reconnect)

eventlog (5 events) + notifications (1 event) + forge (4 events).
EventSource per stream, listeners share. 410 → reset to 0 + reopen."
git push origin testend-v3-react
```

---

### Task 2.4: Write remaining `src/api/*.ts` (logs / sql / mockllm / trace / info / routes)

**Files:**
- Create: `testend/src/api/logs.ts`
- Create: `testend/src/api/sql.ts`
- Create: `testend/src/api/mockllm.ts`
- Create: `testend/src/api/trace.ts`
- Create: `testend/src/api/info.ts`
- Create: `testend/src/api/routes.ts`

**Context:** Each file = thin wrapper over `devClient` for `/dev/*` endpoints. Type signatures inline (don't share with frontend — these are testend-only).

- [ ] **Step 1: Write logs.ts**

```typescript
// testend/src/api/logs.ts — /dev/logs SSE endpoint helpers.
export interface LogEntry {
  time: string;
  level: "debug" | "info" | "warn" | "error";
  msg: string;
  fields?: Record<string, unknown>;
}

export function subscribeLogs(onEntry: (e: LogEntry) => void): () => void {
  const es = new EventSource("/dev/logs");
  es.onmessage = (ev) => {
    try { onEntry(JSON.parse(ev.data)); } catch { /* skip */ }
  };
  return () => es.close();
}
```

- [ ] **Step 2: Write sql.ts**

```typescript
// testend/src/api/sql.ts — /dev/sql read-only query.
import { postJSON } from "./devClient";

export interface SqlResult {
  columns: string[];
  rows: unknown[][];
}

export const sqlAPI = {
  run: (sql: string) => postJSON<SqlResult>("/dev/sql", { sql }),
};
```

- [ ] **Step 3: Write mockllm.ts**

```typescript
// testend/src/api/mockllm.ts — /dev/mock-llm/* controls.
import { delJSON, getJSON, postJSON } from "./devClient";

export const mockLLMAPI = {
  push: (scripts: unknown[]) => postJSON<{ pushed: number }>("/dev/mock-llm/scripts", { scripts }),
  queue: () => getJSON<{ scripts: unknown[]; count: number }>("/dev/mock-llm/queue"),
  clear: () => delJSON<void>("/dev/mock-llm/scripts"),
  lastPrompt: () => getJSON<{ messages: unknown[]; tools?: unknown[]; capturedAt?: string }>("/dev/mock-llm/last-prompt"),
};
```

- [ ] **Step 4: Write trace.ts**

```typescript
// testend/src/api/trace.ts — /dev/llm/trace.
import { getJSON } from "./devClient";

export interface LLMTraceEntry {
  startedAt: string;
  endedAt?: string;
  provider: string;
  model: string;
  scenario?: string;
  inputTokens?: number;
  outputTokens?: number;
  status: "ok" | "error" | "cancelled";
  errorCode?: string;
  errorMessage?: string;
}

export const traceAPI = {
  list: () => getJSON<LLMTraceEntry[]>("/dev/llm/trace"),
};
```

- [ ] **Step 5: Write info.ts**

```typescript
// testend/src/api/info.ts — /dev/info + /dev/runtime + /dev/forgify-home + /dev/bash-processes.
import { getJSON } from "./devClient";

export const infoAPI = {
  info: () => getJSON<{
    port: number;
    home: string;
    forgifyHome: string;
    testendDir: string;
    mcpConfigPath: string;
    skillsDir: string;
    catalogCachePath: string;
    buildID?: string;
    goVersion?: string;
    startedAt?: string;
    tableCounts?: Record<string, number>;
  }>("/dev/info"),
  runtime: () => getJSON<{
    uptimeSec: number;
    numGoroutine: number;
    memAllocBytes: number;
    memSysBytes: number;
    numGC: number;
    dbSizeBytes?: number;
  }>("/dev/runtime"),
  forgifyHome: () => getJSON<{
    path: string;
    mcpJson?: string;
    skillsDir?: string;
    catalogJson?: string;
    tree?: Array<{ name: string; size: number; isDir: boolean; modified: string }>;
  }>("/dev/forgify-home"),
  bashProcesses: () => getJSON<{
    processes: Array<{
      id: string;
      command: string;
      cwd: string;
      startedAt: string;
      status: string;
      exitCode?: number;
    }>;
  }>("/dev/bash-processes"),
};
```

- [ ] **Step 6: Write routes.ts**

```typescript
// testend/src/api/routes.ts — /dev/routes (reflection-based after P0).
import { getJSON } from "./devClient";

export interface Route {
  method: string;
  path: string;
}

export const routesAPI = {
  list: () => getJSON<Route[]>("/dev/routes"),
};
```

- [ ] **Step 7: Typecheck + commit**

```bash
cd testend && npm run typecheck
git add testend/src/api/logs.ts testend/src/api/sql.ts testend/src/api/mockllm.ts testend/src/api/trace.ts testend/src/api/info.ts testend/src/api/routes.ts
git commit -m "feat(testend/api): dev endpoint clients (logs/sql/mockllm/trace/info/routes)"
git push origin testend-v3-react
```

---

### Task 2.5: Write `src/hooks/queryKeys.ts` + `src/hooks/useNormalizedBlock.ts`

**Files:**
- Create: `testend/src/hooks/queryKeys.ts`
- Create: `testend/src/hooks/useNormalizedBlock.ts`

**Context:** queryKeys centralizes TanStack keys (testend version, not frontend's). useNormalizedBlock is the issue #4 workaround — parses `block.attrs` if it arrives as JSON string from REST (vs object from SSE).

- [ ] **Step 1: Write queryKeys.ts**

```typescript
// testend/src/hooks/queryKeys.ts
// TanStack Query key factory for testend (testend-own, not frontend's qk).
export const qk = {
  // Conversations
  conversations: (filter?: { archived?: boolean }) => ["conversations", filter] as const,
  conversation: (id: string) => ["conversation", id] as const,
  messages: (convId: string) => ["messages", convId] as const,

  // Users
  users: () => ["users"] as const,

  // API keys / model
  apikeys: () => ["api-keys"] as const,
  providers: () => ["providers"] as const,
  scenarios: () => ["scenarios"] as const,
  modelConfigs: () => ["model-configs"] as const,

  // Forge trinity
  functions: () => ["functions"] as const,
  function: (id: string) => ["function", id] as const,
  functionVersions: (id: string) => ["function-versions", id] as const,
  functionExecutions: (id: string) => ["function-executions", id] as const,
  handlers: () => ["handlers"] as const,
  handler: (id: string) => ["handler", id] as const,
  handlerVersions: (id: string) => ["handler-versions", id] as const,
  handlerCalls: (id: string) => ["handler-calls", id] as const,
  handlerConfig: (id: string) => ["handler-config", id] as const,
  workflows: () => ["workflows"] as const,
  workflow: (id: string) => ["workflow", id] as const,
  workflowVersions: (id: string) => ["workflow-versions", id] as const,

  // Execute
  flowruns: (filter?: Record<string, unknown>) => ["flowruns", filter] as const,
  flowrun: (id: string) => ["flowrun", id] as const,
  flowrunNodes: (id: string) => ["flowrun-nodes", id] as const,
  triggers: () => ["triggers"] as const,

  // Observe
  catalog: () => ["catalog"] as const,
  notificationsSnap: () => ["notifications-snapshot"] as const,

  // Config
  skills: () => ["skills"] as const,
  skill: (name: string) => ["skill", name] as const,
  mcpServers: () => ["mcp-servers"] as const,
  memories: (type?: string) => ["memories", type ?? "all"] as const,
  documents: () => ["documents"] as const,
  documentsTree: () => ["documents-tree"] as const,
  document: (id: string) => ["document", id] as const,
  sandboxRuntimes: () => ["sandbox-runtimes"] as const,
  sandboxEnvs: () => ["sandbox-envs"] as const,
  permissions: () => ["permissions"] as const,
  llmHealth: () => ["llm-health"] as const,

  // Dev
  devInfo: () => ["dev-info"] as const,
  devRuntime: () => ["dev-runtime"] as const,
  devRoutes: () => ["dev-routes"] as const,
  devForgifyHome: () => ["dev-forgify-home"] as const,
  devBashProcesses: () => ["dev-bash-processes"] as const,
  llmTrace: () => ["llm-trace"] as const,
} as const;
```

- [ ] **Step 2: Write useNormalizedBlock.ts**

```typescript
// testend/src/hooks/useNormalizedBlock.ts
// Issue #4 workaround: chat.Block.Attrs arrives as JSON string from REST
// and as object from SSE. Normalize to object before render.
//
// Issue #4 兜底:REST 拿到 attrs 是字符串,SSE 是对象;此处统一成对象。
import type { Block } from "@frontend/entities/conversation/model/types";

export function useNormalizedBlock(block: Block): Block {
  if (block.attrs && typeof block.attrs === "string") {
    try {
      return { ...block, attrs: JSON.parse(block.attrs) };
    } catch {
      return { ...block, attrs: {} };
    }
  }
  return block;
}

export function normalizeBlocks(blocks: Block[] | undefined): Block[] {
  if (!blocks) return [];
  return blocks.map((b) => {
    const nb = useNormalizedBlock(b);
    if (nb.children) nb.children = normalizeBlocks(nb.children);
    return nb;
  });
}
```

- [ ] **Step 3: Typecheck + commit**

```bash
cd testend && npm run typecheck
git add testend/src/hooks/queryKeys.ts testend/src/hooks/useNormalizedBlock.ts
git commit -m "feat(testend/hooks): queryKeys + useNormalizedBlock (issue #4 workaround)"
git push origin testend-v3-react
```

---

### Task 2.6: Write `src/stores/ui.ts` (col widths, palette, raw json modal, toast queue)

**Files:**
- Create: `testend/src/stores/ui.ts`

- [ ] **Step 1: Write ui.ts**

```typescript
// testend/src/stores/ui.ts — col widths, palette, raw json modal, toast queue.
import { create } from "zustand";
import { persist } from "zustand/middleware";

interface Toast {
  id: string;
  kind?: "success" | "error" | "warn" | "info";
  title?: string;
  desc?: string;
  duration?: number;
}

interface RawJsonModalState {
  open: boolean;
  title?: string;
  payload?: unknown;
}

interface State {
  colConv: number;
  colChat: number;
  colNav: number;
  expanded: boolean;
  palette: boolean;
  rawJson: RawJsonModalState;
  toasts: Toast[];
  setColConv: (w: number) => void;
  setColChat: (w: number) => void;
  setColNav: (w: number) => void;
  setExpanded: (e: boolean) => void;
  openPalette: () => void;
  closePalette: () => void;
  showRaw: (title: string, payload: unknown) => void;
  closeRaw: () => void;
  toast: (t: Omit<Toast, "id">) => string;
  dismissToast: (id: string) => void;
}

export const useUIStore = create<State>()(
  persist(
    (set, get) => ({
      colConv: 200,
      colChat: 420,
      colNav: 220,
      expanded: false,
      palette: false,
      rawJson: { open: false },
      toasts: [],
      setColConv: (w) => set({ colConv: w }),
      setColChat: (w) => set({ colChat: w }),
      setColNav: (w) => set({ colNav: w }),
      setExpanded: (expanded) => set({ expanded }),
      openPalette: () => set({ palette: true }),
      closePalette: () => set({ palette: false }),
      showRaw: (title, payload) => set({ rawJson: { open: true, title, payload } }),
      closeRaw: () => set({ rawJson: { open: false } }),
      toast: (t) => {
        const id = crypto.randomUUID();
        const toast: Toast = { id, ...t };
        set({ toasts: [...get().toasts, toast] });
        const duration = t.duration ?? 5000;
        if (duration > 0) setTimeout(() => get().dismissToast(id), duration);
        return id;
      },
      dismissToast: (id) => set({ toasts: get().toasts.filter((x) => x.id !== id) }),
    }),
    {
      name: "testend-ui",
      partialize: (s) => ({
        colConv: s.colConv,
        colChat: s.colChat,
        colNav: s.colNav,
        expanded: s.expanded,
      }),
    },
  ),
);
```

- [ ] **Step 2: Commit**

```bash
git add testend/src/stores/ui.ts
git commit -m "feat(testend/stores): ui store (col widths + palette + raw json modal + toast queue)"
git push origin testend-v3-react
```

---

### Task 2.7: Write `src/stores/conv.ts` + `src/stores/chat.ts`

**Files:**
- Create: `testend/src/stores/conv.ts`
- Create: `testend/src/stores/chat.ts`

**Context:** conv = current selection + list cache (TanStack handles list; this just tracks "active" + filter). chat = raw block tree, fed by SSE eventlog subscription.

- [ ] **Step 1: Write conv.ts**

```typescript
// testend/src/stores/conv.ts — current conversation selection + filter.
import { create } from "zustand";

interface State {
  activeId: string | null;
  filter: string;
  showArchived: boolean;
  setActive: (id: string | null) => void;
  setFilter: (q: string) => void;
  setShowArchived: (b: boolean) => void;
}

export const useConvStore = create<State>((set) => ({
  activeId: null,
  filter: "",
  showArchived: false,
  setActive: (id) => set({ activeId: id }),
  setFilter: (q) => set({ filter: q }),
  setShowArchived: (b) => set({ showArchived: b }),
}));
```

- [ ] **Step 2: Write chat.ts**

```typescript
// testend/src/stores/chat.ts — raw block tree, fed by eventlog SSE.
// Indexed by conversationId; each entry holds messages + blocks tree.
//
// 按 conversationId 索引;每条对话挂消息 + block tree。
import { create } from "zustand";
import type { Block, Message } from "@frontend/entities/conversation/model/types";

interface ConvState {
  messages: Message[]; // ordered by createdAt; blocks nested
}

interface State {
  byConv: Record<string, ConvState>;
  ensureConv: (convId: string) => void;
  setMessages: (convId: string, messages: Message[]) => void;
  onMessageStart: (convId: string, msg: Partial<Message>) => void;
  onMessageStop: (convId: string, msgId: string, patch: Partial<Message>) => void;
  onBlockStart: (convId: string, blk: Partial<Block> & { id: string; messageId: string; parentId?: string }) => void;
  onBlockDelta: (convId: string, blkId: string, delta: string) => void;
  onBlockStop: (convId: string, blkId: string, patch: Partial<Block>) => void;
  reset: (convId: string) => void;
}

export const useChatStore = create<State>((set, get) => ({
  byConv: {},
  ensureConv: (convId) => {
    if (!get().byConv[convId]) {
      set((s) => ({ byConv: { ...s.byConv, [convId]: { messages: [] } } }));
    }
  },
  setMessages: (convId, messages) =>
    set((s) => ({ byConv: { ...s.byConv, [convId]: { messages } } })),
  onMessageStart: (convId, msg) =>
    set((s) => {
      const cur = s.byConv[convId] ?? { messages: [] };
      const next: Message = {
        id: msg.id!,
        conversationId: convId,
        role: msg.role ?? "assistant",
        status: "streaming",
        blocks: [],
        ...(msg as Partial<Message>),
      } as Message;
      return { byConv: { ...s.byConv, [convId]: { messages: [...cur.messages, next] } } };
    }),
  onMessageStop: (convId, msgId, patch) =>
    set((s) => {
      const cur = s.byConv[convId];
      if (!cur) return s;
      return {
        byConv: {
          ...s.byConv,
          [convId]: {
            messages: cur.messages.map((m) => (m.id === msgId ? { ...m, ...patch } : m)),
          },
        },
      };
    }),
  onBlockStart: (convId, blk) =>
    set((s) => {
      const cur = s.byConv[convId];
      if (!cur) return s;
      const next: Block = {
        id: blk.id,
        messageId: blk.messageId,
        type: (blk as Block).type ?? "text",
        status: "streaming",
        content: "",
        seq: 0,
        createdAt: new Date().toISOString(),
        ...(blk as Partial<Block>),
      } as Block;
      // Insert into parent: if parentId matches a block ID, nest; else attach to message.
      const messages = cur.messages.map((m) => {
        if (m.id !== blk.messageId) return m;
        if (!blk.parentId || blk.parentId === m.id) {
          return { ...m, blocks: [...(m.blocks ?? []), next] };
        }
        // nested inside another block
        return { ...m, blocks: nestBlock(m.blocks ?? [], blk.parentId, next) };
      });
      return { byConv: { ...s.byConv, [convId]: { messages } } };
    }),
  onBlockDelta: (convId, blkId, delta) =>
    set((s) => {
      const cur = s.byConv[convId];
      if (!cur) return s;
      return {
        byConv: {
          ...s.byConv,
          [convId]: {
            messages: cur.messages.map((m) => ({
              ...m,
              blocks: m.blocks ? appendDelta(m.blocks, blkId, delta) : m.blocks,
            })),
          },
        },
      };
    }),
  onBlockStop: (convId, blkId, patch) =>
    set((s) => {
      const cur = s.byConv[convId];
      if (!cur) return s;
      return {
        byConv: {
          ...s.byConv,
          [convId]: {
            messages: cur.messages.map((m) => ({
              ...m,
              blocks: m.blocks ? patchBlock(m.blocks, blkId, patch) : m.blocks,
            })),
          },
        },
      };
    }),
  reset: (convId) =>
    set((s) => {
      const { [convId]: _, ...rest } = s.byConv;
      return { byConv: rest };
    }),
}));

function nestBlock(blocks: Block[], parentId: string, child: Block): Block[] {
  return blocks.map((b) => {
    if (b.id === parentId) return { ...b, children: [...(b.children ?? []), child] };
    if (b.children) return { ...b, children: nestBlock(b.children, parentId, child) };
    return b;
  });
}

function appendDelta(blocks: Block[], id: string, delta: string): Block[] {
  return blocks.map((b) => {
    if (b.id === id) return { ...b, content: b.content + delta };
    if (b.children) return { ...b, children: appendDelta(b.children, id, delta) };
    return b;
  });
}

function patchBlock(blocks: Block[], id: string, patch: Partial<Block>): Block[] {
  return blocks.map((b) => {
    if (b.id === id) return { ...b, ...patch };
    if (b.children) return { ...b, children: patchBlock(b.children, id, patch) };
    return b;
  });
}
```

- [ ] **Step 3: Typecheck + commit**

```bash
cd testend && npm run typecheck
git add testend/src/stores/conv.ts testend/src/stores/chat.ts
git commit -m "feat(testend/stores): conv selection + chat raw block tree

chat store ingests SSE eventlog events (message_start/stop, block_start/delta/stop).
Recursively nests blocks via parentId. Type from @frontend/entities/conversation."
git push origin testend-v3-react
```

---

### Task 2.8: Write `src/stores/notifications.ts` + `src/stores/forge.ts` + `src/stores/catalog.ts`

**Files:**
- Create: `testend/src/stores/notifications.ts`
- Create: `testend/src/stores/forge.ts`
- Create: `testend/src/stores/catalog.ts`

**Context:** Each is a thin SSE-fed accumulator + start/stop lifecycle. notifications keeps last N events (default 200), forge groups by `scope.kind:id`, catalog holds the latest `GET /api/v1/catalog` snapshot.

- [ ] **Step 1: Write notifications.ts**

```typescript
// testend/src/stores/notifications.ts
import { create } from "zustand";
import { subscribe } from "@/api/sse";

export interface NotifEvent {
  type: string;
  id: string;
  data?: Record<string, unknown>;
  conversationId?: string;
  action?: string;
  receivedAt: number;
}

interface State {
  list: NotifEvent[];
  cap: number;
  unsub: (() => void) | null;
  start: () => void;
  stop: () => void;
  clear: () => void;
}

export const useNotificationsStore = create<State>((set, get) => ({
  list: [],
  cap: 200,
  unsub: null,
  start: () => {
    if (get().unsub) return;
    const u = subscribe("notifications", (e) => {
      const data = e.data as Record<string, unknown>;
      set((s) => ({
        list: [
          ...s.list.slice(Math.max(0, s.list.length - s.cap + 1)),
          { ...(data as NotifEvent), receivedAt: e.receivedAt },
        ],
      }));
    });
    set({ unsub: u });
  },
  stop: () => {
    get().unsub?.();
    set({ unsub: null });
  },
  clear: () => set({ list: [] }),
}));
```

- [ ] **Step 2: Write forge.ts**

```typescript
// testend/src/stores/forge.ts
import { create } from "zustand";
import { subscribe } from "@/api/sse";

export interface ForgeEvent {
  event: "forge_started" | "forge_op_applied" | "forge_env_attempt" | "forge_completed" | string;
  scope: { kind: "function" | "handler" | "workflow"; id: string };
  conversationId?: string;
  toolCallId?: string;
  index?: number;
  op?: unknown;
  attempt?: number;
  status?: string;
  stage?: string;
  detail?: string;
  error?: string;
  versionId?: string;
  envStatus?: string;
  attemptsUsed?: number;
  receivedAt: number;
}

interface State {
  events: ForgeEvent[];
  cap: number;
  unsub: (() => void) | null;
  start: () => void;
  stop: () => void;
  clear: () => void;
}

export const useForgeStore = create<State>((set, get) => ({
  events: [],
  cap: 200,
  unsub: null,
  start: () => {
    if (get().unsub) return;
    const u = subscribe("forge", (e) => {
      const data = e.data as Record<string, unknown>;
      const fe: ForgeEvent = { event: e.event, ...(data as object), receivedAt: e.receivedAt } as ForgeEvent;
      set((s) => ({
        events: [...s.events.slice(Math.max(0, s.events.length - s.cap + 1)), fe],
      }));
    });
    set({ unsub: u });
  },
  stop: () => {
    get().unsub?.();
    set({ unsub: null });
  },
  clear: () => set({ events: [] }),
}));
```

- [ ] **Step 3: Write catalog.ts**

```typescript
// testend/src/stores/catalog.ts
import { create } from "zustand";
import { getJSON } from "@/api/devClient";

export interface Catalog {
  generatedAt: string;
  fingerprint: string;
  items: Array<{
    source: "function" | "handler" | "workflow" | "skill" | "mcp";
    name: string;
    description: string;
    granularity: "PerItem" | "PerServer" | "PerCollection";
  }>;
}

interface State {
  current: Catalog | null;
  loading: boolean;
  refresh: () => Promise<void>;
}

export const useCatalogStore = create<State>((set) => ({
  current: null,
  loading: false,
  refresh: async () => {
    set({ loading: true });
    try {
      const c = await getJSON<Catalog | null>("/api/v1/catalog");
      set({ current: c, loading: false });
    } catch {
      set({ loading: false });
    }
  },
}));
```

- [ ] **Step 4: Typecheck + commit**

```bash
cd testend && npm run typecheck
git add testend/src/stores/notifications.ts testend/src/stores/forge.ts testend/src/stores/catalog.ts
git commit -m "feat(testend/stores): notifications + forge + catalog (SSE-fed + 200-cap)"
git push origin testend-v3-react
```

---

### Task 2.9: Write `src/ui/` primitives (RawJsonModal, ToastTray, EmptyView, RelTime, KindChip, StatusBadge, Pill, Kbd)

**Files:**
- Create: `testend/src/ui/RawJsonModal.tsx`
- Create: `testend/src/ui/ToastTray.tsx`
- Create: `testend/src/ui/EmptyView.tsx`
- Create: `testend/src/ui/RelTime.tsx`
- Create: `testend/src/ui/KindChip.tsx`
- Create: `testend/src/ui/StatusBadge.tsx`
- Create: `testend/src/ui/Pill.tsx`
- Create: `testend/src/ui/Kbd.tsx`
- Create: `testend/src/ui/index.ts`

**Context:** Small, focused; minimal styling via existing CSS classes from style.css. Each file ≤30 LOC except RawJsonModal.

- [ ] **Step 1: Write each file**

`RawJsonModal.tsx`:

```tsx
import { useEffect } from "react";
import { useUIStore } from "@/stores/ui";

export function RawJsonModal() {
  const { rawJson, closeRaw } = useUIStore();
  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === "Escape") closeRaw(); };
    if (rawJson.open) window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, [rawJson.open, closeRaw]);
  if (!rawJson.open) return null;
  return (
    <div onClick={closeRaw} style={{
      position: "fixed", inset: 0, background: "rgba(0,0,0,0.4)",
      display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100,
    }}>
      <div onClick={(e) => e.stopPropagation()} style={{
        background: "var(--bg-paper)", border: "1px solid var(--border)",
        borderRadius: 8, padding: 16, maxWidth: "80vw", maxHeight: "80vh",
        overflow: "auto", minWidth: 480,
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 12 }}>
          <strong>{rawJson.title ?? "Raw JSON"}</strong>
          <button onClick={closeRaw} style={{ background: "none", border: "none", cursor: "pointer", color: "var(--fg-muted)" }}>✕</button>
        </div>
        <pre className="raw-json">{JSON.stringify(rawJson.payload, null, 2)}</pre>
      </div>
    </div>
  );
}
```

`ToastTray.tsx`:

```tsx
import { useUIStore } from "@/stores/ui";
export function ToastTray() {
  const { toasts, dismissToast } = useUIStore();
  return (
    <div style={{ position: "fixed", bottom: 16, right: 16, display: "flex", flexDirection: "column", gap: 8, zIndex: 200 }}>
      {toasts.map((t) => (
        <div key={t.id} className={`pill ${t.kind ?? "info"}`} style={{ padding: "8px 14px", minWidth: 240, cursor: "pointer" }} onClick={() => dismissToast(t.id)}>
          {t.title && <strong style={{ marginRight: 6 }}>{t.title}</strong>}
          <span>{t.desc}</span>
        </div>
      ))}
    </div>
  );
}
```

`EmptyView.tsx`:

```tsx
export function EmptyView({ children }: { children?: React.ReactNode }) {
  return <div className="empty">{children ?? "no data"}</div>;
}
```

`RelTime.tsx`:

```tsx
import { useEffect, useState } from "react";
export function RelTime({ ts }: { ts: string | number | undefined }) {
  const [tick, setTick] = useState(0);
  useEffect(() => {
    const i = setInterval(() => setTick((x) => x + 1), 30_000);
    return () => clearInterval(i);
  }, []);
  if (!ts) return <span className="muted">—</span>;
  const d = typeof ts === "string" ? new Date(ts).getTime() : ts;
  if (!Number.isFinite(d)) return <span className="muted">—</span>;
  const diff = (Date.now() - d) / 1000;
  let s = "刚刚";
  if (diff > 60 && diff < 3600) s = `${Math.floor(diff / 60)} 分钟前`;
  else if (diff < 86400) s = `${Math.floor(diff / 3600)} 小时前`;
  else if (diff < 86400 * 30) s = `${Math.floor(diff / 86400)} 天前`;
  else s = new Date(d).toLocaleDateString();
  return <span title={new Date(d).toLocaleString()}>{s}</span>;
  void tick;
}
```

`KindChip.tsx`:

```tsx
const COLORS: Record<string, string> = {
  function: "#4a7cc4", handler: "#4a8c4a", workflow: "#d4a017",
  skill: "#8b5cf6", mcp: "#d97757", document: "#6b6862",
};
export function KindChip({ kind }: { kind: string }) {
  return <span className="pill" style={{ background: `${COLORS[kind] ?? "#9b988f"}22`, color: COLORS[kind] ?? "#9b988f" }}>{kind}</span>;
}
```

`StatusBadge.tsx`:

```tsx
const KIND: Record<string, "success" | "error" | "warn" | "info" | "streaming"> = {
  ready: "success", ok: "success", completed: "success", accepted: "success",
  pending: "info", streaming: "streaming", running: "streaming", connecting: "warn",
  degraded: "warn", paused: "warn",
  failed: "error", error: "error", cancelled: "error", rejected: "error",
  disconnected: "error", evicted: "error",
};
export function StatusBadge({ status }: { status: string }) {
  return <span className={`pill ${KIND[status] ?? ""}`}>{status}</span>;
}
```

`Pill.tsx`:

```tsx
export function Pill({ children, kind }: { children: React.ReactNode; kind?: "success" | "error" | "warn" | "info" | "streaming" }) {
  return <span className={`pill ${kind ?? ""}`}>{children}</span>;
}
```

`Kbd.tsx`:

```tsx
export function Kbd({ children }: { children: React.ReactNode }) {
  return <kbd style={{ fontFamily: "var(--mono)", fontSize: 11, padding: "1px 5px", border: "1px solid var(--border)", borderRadius: 3, background: "var(--bg-elev)" }}>{children}</kbd>;
}
```

`index.ts`:

```typescript
export { RawJsonModal } from "./RawJsonModal";
export { ToastTray } from "./ToastTray";
export { EmptyView } from "./EmptyView";
export { RelTime } from "./RelTime";
export { KindChip } from "./KindChip";
export { StatusBadge } from "./StatusBadge";
export { Pill } from "./Pill";
export { Kbd } from "./Kbd";
```

- [ ] **Step 2: Typecheck + commit**

```bash
cd testend && npm run typecheck
git add testend/src/ui/*.tsx testend/src/ui/index.ts
git commit -m "feat(testend/ui): primitives (RawJsonModal, ToastTray, EmptyView, RelTime, KindChip, StatusBadge, Pill, Kbd)"
git push origin testend-v3-react
```

---

### Task 2.10: Write `src/ui/BlockView.tsx` (recursive raw block viewer)

**Files:**
- Create: `testend/src/ui/BlockView.tsx`

**Context:** Renders a Block (and its children) as a collapsible tree with type-aware display: text shows content, tool_call shows tool name + args + nested tool_result, reasoning collapsed by default, compaction shows summary, progress streams stages. Uses `useNormalizedBlock` to handle issue #4.

- [ ] **Step 1: Write BlockView.tsx**

```tsx
// testend/src/ui/BlockView.tsx
import { useState } from "react";
import type { Block } from "@frontend/entities/conversation/model/types";
import { useNormalizedBlock } from "@/hooks/useNormalizedBlock";
import { StatusBadge } from "./StatusBadge";

export function BlockView({ block, depth = 0 }: { block: Block; depth?: number }) {
  const b = useNormalizedBlock(block);
  const [open, setOpen] = useState(b.type !== "reasoning");
  const indent = depth * 12;
  const headerBg = depth === 0 ? "var(--bg-paper)" : "var(--bg-elev)";

  const summary = headerSummary(b);
  return (
    <div style={{ marginLeft: indent, borderLeft: depth > 0 ? "1px solid var(--border-soft)" : undefined, paddingLeft: depth > 0 ? 8 : 0 }}>
      <div onClick={() => setOpen(!open)} style={{
        cursor: "pointer", padding: "4px 8px", background: headerBg,
        display: "flex", gap: 8, alignItems: "center", fontSize: 12,
      }}>
        <span style={{ width: 12 }}>{open ? "▾" : "▸"}</span>
        <code style={{ fontSize: 11, color: "var(--fg-muted)" }}>{b.type}</code>
        <StatusBadge status={b.status} />
        <span style={{ color: "var(--fg-muted)", flex: 1, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{summary}</span>
        {b.durationMs != null && <span className="muted" style={{ fontSize: 11 }}>{b.durationMs}ms</span>}
      </div>
      {open && (
        <div style={{ padding: "6px 8px" }}>
          {b.type === "text" && <div style={{ whiteSpace: "pre-wrap" }}>{b.content}</div>}
          {b.type === "reasoning" && <div style={{ whiteSpace: "pre-wrap", color: "var(--fg-muted)", fontStyle: "italic" }}>{b.content}</div>}
          {b.type === "tool_call" && (
            <pre className="raw-json">{prettyArgs((b as Block & { attrs?: { toolName?: string } }).attrs?.toolName, b.content)}</pre>
          )}
          {b.type === "tool_result" && <pre className="raw-json">{b.content}</pre>}
          {b.type === "progress" && <div className="muted">{b.content}</div>}
          {b.type === "compaction" && <pre className="raw-json">{b.content}</pre>}
          {b.type === "message" && <div className="muted">→ nested message</div>}
          {b.children?.map((c) => <BlockView key={c.id} block={c} depth={depth + 1} />)}
        </div>
      )}
    </div>
  );
}

function headerSummary(b: Block): string {
  const a = (b.attrs ?? {}) as Record<string, unknown>;
  if (b.type === "tool_call") return `${a.toolName ?? "?"}${a.summary ? ` — ${a.summary}` : ""}`;
  if (b.type === "compaction") return `covers seq ${a.coversFromSeq}–${a.coversToSeq}`;
  if (b.type === "progress") return String(a.stage ?? "");
  return (b.content || "").slice(0, 80);
}

function prettyArgs(toolName: string | undefined, raw: string): string {
  let args: unknown = raw;
  try { args = JSON.parse(raw); } catch { /* keep raw */ }
  return `${toolName ?? "tool"}(${typeof args === "string" ? args : JSON.stringify(args, null, 2)})`;
}
```

- [ ] **Step 2: Typecheck + commit**

```bash
cd testend && npm run typecheck
git add testend/src/ui/BlockView.tsx
git commit -m "feat(testend/ui): BlockView — recursive 7-type-aware block tree viewer

text/reasoning/tool_call/tool_result/progress/message/compaction.
reasoning collapsed default; tool_call shows toolName + JSON args
+ nested children (tool_result, progress, message). normalized
via useNormalizedBlock to handle issue #4."
git push origin testend-v3-react
```

---

### Task 2.11: Write `src/ui/MonacoEditor.tsx` (lazy)

**Files:**
- Create: `testend/src/ui/MonacoEditor.tsx`

**Context:** Thin wrapper around `@monaco-editor/react`. Lazy-loaded by the build via `manualChunks` already configured.

- [ ] **Step 1: Write MonacoEditor.tsx**

```tsx
// testend/src/ui/MonacoEditor.tsx — thin Monaco wrapper.
import Editor, { type OnMount } from "@monaco-editor/react";
import { useCallback } from "react";

export interface MonacoProps {
  value: string;
  onChange?: (v: string) => void;
  language?: "sql" | "json" | "typescript" | "python" | "markdown" | "plaintext";
  height?: number | string;
  readOnly?: boolean;
  onMount?: OnMount;
}

export function MonacoEditor({ value, onChange, language = "plaintext", height = 240, readOnly = false, onMount }: MonacoProps) {
  const handleChange = useCallback((v: string | undefined) => onChange?.(v ?? ""), [onChange]);
  return (
    <Editor
      height={height}
      language={language}
      value={value}
      onChange={handleChange}
      onMount={onMount}
      options={{
        readOnly,
        minimap: { enabled: false },
        fontSize: 13,
        fontFamily: "var(--mono)",
        scrollBeyondLastLine: false,
        wordWrap: "on",
        renderLineHighlight: "none",
        lineNumbers: "on",
        folding: false,
        glyphMargin: false,
      }}
      theme="vs-dark"
    />
  );
}
```

- [ ] **Step 2: Typecheck + commit**

```bash
cd testend && npm run typecheck
git add testend/src/ui/MonacoEditor.tsx
git commit -m "feat(testend/ui): MonacoEditor wrapper (lazy chunk via vite manualChunks)"
git push origin testend-v3-react
```

---

### Task 2.12: Write `src/ui/CommandPalette.tsx`

**Files:**
- Create: `testend/src/ui/CommandPalette.tsx`

**Context:** ⌘K palette. Lists all 44 routes + jumps via react-router navigate. Filter by typing. Esc closes. Open via `useUIStore.openPalette()`.

- [ ] **Step 1: Write CommandPalette.tsx**

```tsx
// testend/src/ui/CommandPalette.tsx
import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useUIStore } from "@/stores/ui";

const ROUTES: Array<{ path: string; label: string; section: string }> = [
  { section: "current", path: "/current/wire", label: "Wire Trace" },
  { section: "current", path: "/current/eventlog", label: "Eventlog Raw" },
  { section: "current", path: "/current/notifications", label: "Notifications (scoped)" },
  { section: "current", path: "/current/subagents", label: "SubAgents" },
  { section: "current", path: "/current/tools", label: "Tool Calls" },
  { section: "current", path: "/current/todos", label: "Todos" },
  { section: "current", path: "/current/asks", label: "Asks Pending" },
  { section: "current", path: "/current/attachments", label: "Attachments" },
  { section: "current", path: "/current/compaction", label: "Compaction" },
  { section: "forge", path: "/forge/functions", label: "Functions" },
  { section: "forge", path: "/forge/handlers", label: "Handlers" },
  { section: "forge", path: "/forge/workflows", label: "Workflows" },
  { section: "forge", path: "/forge/tools", label: "Tools Registry" },
  { section: "execute", path: "/execute/triggers", label: "Triggers" },
  { section: "execute", path: "/execute/flowruns", label: "FlowRuns" },
  { section: "execute", path: "/execute/approvals", label: "Approvals Queue" },
  { section: "execute", path: "/execute/executions", label: "Executions" },
  { section: "observe", path: "/observe/live", label: "Live SSE" },
  { section: "observe", path: "/observe/notifications", label: "Notification History" },
  { section: "observe", path: "/observe/catalog", label: "Catalog" },
  { section: "observe", path: "/observe/usage", label: "Usage" },
  { section: "observe", path: "/observe/mock-llm", label: "Mock LLM" },
  { section: "config", path: "/config/apikeys", label: "API Keys" },
  { section: "config", path: "/config/models", label: "Model Configs" },
  { section: "config", path: "/config/skills", label: "Skills" },
  { section: "config", path: "/config/mcp", label: "MCP Servers" },
  { section: "config", path: "/config/sandbox", label: "Sandbox" },
  { section: "config", path: "/config/memory", label: "Memory" },
  { section: "config", path: "/config/documents", label: "Documents" },
  { section: "config", path: "/config/permissions", label: "Permissions" },
  { section: "config", path: "/config/llm-health", label: "LLM Health" },
  { section: "config", path: "/config/profile", label: "Profile" },
  { section: "dev", path: "/dev/sql", label: "SQL Console" },
  { section: "dev", path: "/dev/info", label: "Info" },
  { section: "dev", path: "/dev/routes", label: "Routes" },
  { section: "dev", path: "/dev/logs", label: "Backend Logs" },
  { section: "dev", path: "/dev/processes", label: "Bash Processes" },
  { section: "dev", path: "/dev/metrics", label: "Metrics" },
  { section: "dev", path: "/dev/errors", label: "Errors" },
  { section: "dev", path: "/dev/prompts", label: "Prompts" },
];

export function CommandPalette() {
  const { palette, closePalette } = useUIStore();
  const [q, setQ] = useState("");
  const [idx, setIdx] = useState(0);
  const navigate = useNavigate();

  const filtered = useMemo(() => {
    const ql = q.toLowerCase();
    return ROUTES.filter((r) => r.label.toLowerCase().includes(ql) || r.path.toLowerCase().includes(ql)).slice(0, 12);
  }, [q]);

  useEffect(() => { setIdx(0); }, [q]);

  useEffect(() => {
    if (!palette) return;
    const h = (e: KeyboardEvent) => {
      if (e.key === "Escape") closePalette();
      else if (e.key === "ArrowDown") { e.preventDefault(); setIdx((i) => Math.min(i + 1, filtered.length - 1)); }
      else if (e.key === "ArrowUp") { e.preventDefault(); setIdx((i) => Math.max(i - 1, 0)); }
      else if (e.key === "Enter") {
        const r = filtered[idx];
        if (r) { navigate(`/${r.path.slice(1)}`); closePalette(); }
      }
    };
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, [palette, filtered, idx, navigate, closePalette]);

  if (!palette) return null;
  return (
    <div onClick={closePalette} style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.4)", zIndex: 150, display: "flex", alignItems: "flex-start", justifyContent: "center", paddingTop: 120 }}>
      <div onClick={(e) => e.stopPropagation()} style={{ background: "var(--bg-paper)", border: "1px solid var(--border)", borderRadius: 8, width: 480, padding: 8 }}>
        <input autoFocus value={q} onChange={(e) => setQ(e.target.value)} placeholder="跳转…"
          style={{ width: "100%", padding: "8px 10px", border: "1px solid var(--border)", borderRadius: 4, background: "var(--bg-window)", color: "var(--fg-body)", fontSize: 14 }} />
        <div style={{ marginTop: 8, maxHeight: 360, overflowY: "auto" }}>
          {filtered.map((r, i) => (
            <div key={r.path} onClick={() => { navigate(`/${r.path.slice(1)}`); closePalette(); }}
              style={{ padding: "6px 10px", cursor: "pointer", background: i === idx ? "var(--bg-elev)" : "transparent", borderRadius: 4, display: "flex", justifyContent: "space-between" }}>
              <span><span className="muted" style={{ marginRight: 6 }}>{r.section}</span>{r.label}</span>
              <span className="muted mono" style={{ fontSize: 11 }}>{r.path}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Typecheck + commit**

```bash
cd testend && npm run typecheck
git add testend/src/ui/CommandPalette.tsx
git commit -m "feat(testend/ui): CommandPalette (⌘K → 44 route quick-nav)"
git push origin testend-v3-react
```

---

### Task 2.13: Write `src/layout/ResizableSplit.tsx`

**Files:**
- Create: `testend/src/layout/ResizableSplit.tsx`

**Context:** 2-pane horizontal splitter with drag-resize handle. Used inside App.tsx to make col1/col2/col3/col4 resizable.

- [ ] **Step 1: Write ResizableSplit.tsx**

```tsx
// testend/src/layout/ResizableSplit.tsx — drag-resize 2-pane split.
import { useEffect, useRef, useState, type ReactNode } from "react";

export function ResizableSplit({
  leftWidth, minLeft = 100, maxLeft = 1000, onResize,
  left, right,
}: {
  leftWidth: number;
  minLeft?: number;
  maxLeft?: number;
  onResize: (w: number) => void;
  left: ReactNode;
  right: ReactNode;
}) {
  const [dragging, setDragging] = useState(false);
  const dragStartX = useRef(0);
  const dragStartWidth = useRef(leftWidth);

  useEffect(() => {
    if (!dragging) return;
    const onMove = (e: MouseEvent) => {
      const dx = e.clientX - dragStartX.current;
      const w = Math.max(minLeft, Math.min(maxLeft, dragStartWidth.current + dx));
      onResize(w);
    };
    const onUp = () => setDragging(false);
    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onUp);
    return () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseup", onUp);
    };
  }, [dragging, minLeft, maxLeft, onResize]);

  return (
    <div style={{ display: "flex", flex: 1, minWidth: 0, height: "100%" }}>
      <div style={{ width: leftWidth, flexShrink: 0, overflow: "hidden" }}>{left}</div>
      <div
        onMouseDown={(e) => { dragStartX.current = e.clientX; dragStartWidth.current = leftWidth; setDragging(true); }}
        style={{ width: 4, cursor: "col-resize", background: dragging ? "var(--accent)" : "var(--border)", flexShrink: 0 }}
      />
      <div style={{ flex: 1, minWidth: 0, overflow: "hidden" }}>{right}</div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
cd testend && npm run typecheck
git add testend/src/layout/ResizableSplit.tsx
git commit -m "feat(testend/layout): ResizableSplit (drag-resize 2-pane)"
git push origin testend-v3-react
```

---

### Task 2.14: Write `src/layout/TopBar.tsx` + `src/layout/UserPicker.tsx`

**Files:**
- Create: `testend/src/layout/TopBar.tsx`
- Create: `testend/src/layout/UserPicker.tsx`

**Context:** TopBar: build info + 3 SSE status pills + ⌘K hint + expand toggle. UserPicker: modal when 2+ profiles and no active selection.

- [ ] **Step 1: Write TopBar.tsx**

```tsx
// testend/src/layout/TopBar.tsx
import { useEffect, useState } from "react";
import { useUIStore } from "@/stores/ui";
import { useUsersStore } from "@/stores/users";
import { status as sseStatus } from "@/api/sse";
import { Kbd, Pill } from "@/ui";

function useSSEStatuses() {
  const [, setTick] = useState(0);
  useEffect(() => { const i = setInterval(() => setTick((x) => x + 1), 1000); return () => clearInterval(i); }, []);
  return {
    el: sseStatus("eventlog"),
    nf: sseStatus("notifications"),
    fg: sseStatus("forge"),
  };
}

export function TopBar() {
  const { expanded, setExpanded, openPalette } = useUIStore();
  const { list, activeId, setActive } = useUsersStore();
  const sse = useSSEStatuses();
  const active = list.find((u) => u.id === activeId);

  return (
    <div style={{ height: 36, borderBottom: "1px solid var(--border)", padding: "0 12px", display: "flex", alignItems: "center", gap: 12, fontSize: 12 }}>
      <strong>Forgify Dev Console V3</strong>
      <span className="muted">/dev/</span>
      <span style={{ flex: 1 }} />
      <Pill kind={sse.el.connected ? "success" : "error"}>EL</Pill>
      <Pill kind={sse.nf.connected ? "success" : "error"}>NF</Pill>
      <Pill kind={sse.fg.connected ? "success" : "error"}>FG</Pill>
      <select value={activeId ?? ""} onChange={(e) => setActive(e.target.value)}
        style={{ background: "var(--bg-elev)", color: "var(--fg-body)", border: "1px solid var(--border)", borderRadius: 4, padding: "2px 6px", fontSize: 12 }}>
        {!active && <option value="">(no user)</option>}
        {list.map((u) => <option key={u.id} value={u.id}>{u.displayName || u.username}</option>)}
      </select>
      <button onClick={openPalette} className="muted" style={{ background: "none", border: "none", cursor: "pointer", fontSize: 12 }}>
        <Kbd>⌘K</Kbd>
      </button>
      <button onClick={() => setExpanded(!expanded)} className="muted" style={{ background: "none", border: "1px solid var(--border)", borderRadius: 4, cursor: "pointer", padding: "2px 8px", fontSize: 12 }}>
        {expanded ? "← shrink" : "expand →"}
      </button>
    </div>
  );
}
```

- [ ] **Step 2: Write UserPicker.tsx**

```tsx
// testend/src/layout/UserPicker.tsx
import { useUsersStore } from "@/stores/users";

export function UserPicker() {
  const { list, setActive } = useUsersStore();
  if (list.length === 0) return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.4)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 90 }}>
      <div style={{ background: "var(--bg-paper)", padding: 20, borderRadius: 8, border: "1px solid var(--border)", maxWidth: 400 }}>
        <h3 style={{ margin: "0 0 8px" }}>No user yet</h3>
        <p className="muted" style={{ margin: 0 }}>Backend has no users; create one via the main frontend's onboarding flow, then refresh testend.</p>
      </div>
    </div>
  );
  return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.4)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 90 }}>
      <div style={{ background: "var(--bg-paper)", padding: 20, borderRadius: 8, border: "1px solid var(--border)", minWidth: 320 }}>
        <h3 style={{ margin: "0 0 12px" }}>Pick a profile</h3>
        <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
          {list.map((u) => (
            <button key={u.id} onClick={() => setActive(u.id)} style={{ padding: "8px 12px", background: "var(--bg-elev)", border: "1px solid var(--border)", borderRadius: 4, cursor: "pointer", textAlign: "left" }}>
              <strong>{u.displayName || u.username}</strong>
              <span className="muted mono" style={{ marginLeft: 8, fontSize: 11 }}>{u.id}</span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Commit**

```bash
cd testend && npm run typecheck
git add testend/src/layout/TopBar.tsx testend/src/layout/UserPicker.tsx
git commit -m "feat(testend/layout): TopBar (3 SSE pills + user picker + ⌘K) + UserPicker modal"
git push origin testend-v3-react
```

---

### Task 2.15: Write `src/layout/ConvSidebar.tsx` + `src/layout/ChatPanel.tsx` + `src/layout/TabNav.tsx` + wire `App.tsx`

**Files:**
- Create: `testend/src/layout/ConvSidebar.tsx`
- Create: `testend/src/layout/ChatPanel.tsx`
- Create: `testend/src/layout/TabNav.tsx`
- Modify: `testend/src/App.tsx` (replace skeleton with real layout)

**Context:** Three remaining 4-col layout components. App.tsx now composes everything via ResizableSplit nesting, mounts global SSE subs, bootstraps users, and starts catalog refresh on init.

- [ ] **Step 1: Write ConvSidebar.tsx**

```tsx
// testend/src/layout/ConvSidebar.tsx — col1: conv list + filter + new btn.
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { getJSON, postJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { useConvStore } from "@/stores/conv";
import { useUIStore } from "@/stores/ui";
import { RelTime, EmptyView } from "@/ui";
import type { Conversation } from "@frontend/entities/conversation/model/types";

export function ConvSidebar() {
  const { activeId, filter, setActive, setFilter, showArchived, setShowArchived } = useConvStore();
  const ui = useUIStore();
  const qc = useQueryClient();
  const { data: convs = [], isError } = useQuery({
    queryKey: qk.conversations({ archived: showArchived }),
    queryFn: () => getJSON<Conversation[]>(`/api/v1/conversations${showArchived ? "?archived=true" : ""}`),
  });
  const create = useMutation({
    mutationFn: () => postJSON<Conversation>("/api/v1/conversations", { title: "(new)" }),
    onSuccess: (c) => { qc.invalidateQueries({ queryKey: qk.conversations() }); setActive(c.id); },
  });

  const filtered = convs.filter((c) => !filter || c.title.toLowerCase().includes(filter.toLowerCase()));

  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%", background: "var(--bg-sidebar)" }}>
      <div style={{ padding: 8, display: "flex", gap: 6 }}>
        <input value={filter} onChange={(e) => setFilter(e.target.value)} placeholder="filter…"
          style={{ flex: 1, padding: "4px 8px", border: "1px solid var(--border)", borderRadius: 3, background: "var(--bg-paper)", color: "var(--fg-body)", fontSize: 12 }} />
        <button onClick={() => create.mutate()} style={{ padding: "4px 8px", background: "var(--accent)", color: "var(--accent-fg)", border: "none", borderRadius: 3, cursor: "pointer", fontSize: 12 }}>+</button>
      </div>
      <label style={{ display: "flex", alignItems: "center", gap: 4, padding: "0 8px 6px", fontSize: 11, color: "var(--fg-muted)" }}>
        <input type="checkbox" checked={showArchived} onChange={(e) => setShowArchived(e.target.checked)} /> archived
      </label>
      <div style={{ flex: 1, overflowY: "auto" }}>
        {isError && <div className="empty">load error</div>}
        {!isError && filtered.length === 0 && <EmptyView>no conversations</EmptyView>}
        {filtered.map((c) => (
          <div key={c.id} onClick={() => setActive(c.id)}
            onContextMenu={(e) => { e.preventDefault(); ui.showRaw(c.title, c); }}
            style={{ padding: "6px 10px", cursor: "pointer", borderLeft: "2px solid transparent",
              borderLeftColor: activeId === c.id ? "var(--accent)" : "transparent",
              background: activeId === c.id ? "var(--bg-elev)" : undefined,
              fontSize: 12 }}>
            <div style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{c.title || "(untitled)"}</div>
            <div className="muted" style={{ fontSize: 10 }}><RelTime ts={c.updatedAt} /></div>
          </div>
        ))}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Write ChatPanel.tsx**

```tsx
// testend/src/layout/ChatPanel.tsx — col2: messages tree + composer (debug-flavored).
import { useEffect, useRef, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { getJSON, postJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { useConvStore } from "@/stores/conv";
import { useChatStore } from "@/stores/chat";
import { subscribe } from "@/api/sse";
import { BlockView, EmptyView, StatusBadge } from "@/ui";
import type { Message } from "@frontend/entities/conversation/model/types";

export function ChatPanel() {
  const { activeId } = useConvStore();
  const chat = useChatStore();
  const qc = useQueryClient();
  const [draft, setDraft] = useState("");
  const scrollRef = useRef<HTMLDivElement>(null);

  // Load existing messages
  useQuery({
    queryKey: qk.messages(activeId ?? ""),
    queryFn: async () => {
      if (!activeId) return [];
      const m = await getJSON<Message[]>(`/api/v1/conversations/${activeId}/messages`);
      chat.setMessages(activeId, m);
      return m;
    },
    enabled: !!activeId,
  });

  // SSE → chat store
  useEffect(() => {
    return subscribe("eventlog", (e) => {
      const d = e.data as Record<string, unknown>;
      const convId = d.conversationId as string | undefined;
      if (!convId) return;
      chat.ensureConv(convId);
      if (e.event === "message_start") chat.onMessageStart(convId, d as Partial<Message>);
      else if (e.event === "message_stop") chat.onMessageStop(convId, d.id as string, d as Partial<Message>);
      else if (e.event === "block_start") chat.onBlockStart(convId, d as { id: string; messageId: string; parentId?: string });
      else if (e.event === "block_delta") chat.onBlockDelta(convId, d.id as string, d.delta as string);
      else if (e.event === "block_stop") chat.onBlockStop(convId, d.id as string, d as Partial<import("@frontend/entities/conversation/model/types").Block>);
    });
  }, [chat]);

  const send = useMutation({
    mutationFn: ({ content }: { content: string }) =>
      postJSON(`/api/v1/conversations/${activeId}/messages:send`, { content }),
    onSuccess: () => { setDraft(""); qc.invalidateQueries({ queryKey: qk.conversations() }); },
  });

  const messages = activeId ? chat.byConv[activeId]?.messages ?? [] : [];

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [messages.length]);

  if (!activeId) return <EmptyView>pick a conversation</EmptyView>;
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div ref={scrollRef} style={{ flex: 1, overflowY: "auto", padding: 8 }}>
        {messages.map((m) => (
          <div key={m.id} style={{ marginBottom: 8 }}>
            <div style={{ display: "flex", gap: 6, fontSize: 11, color: "var(--fg-muted)", padding: "4px 8px" }}>
              <strong>{m.role}</strong> <StatusBadge status={m.status} />
              {m.inputTokens != null && <span>in {m.inputTokens}</span>}
              {m.outputTokens != null && <span>out {m.outputTokens}</span>}
            </div>
            {m.blocks?.map((b) => <BlockView key={b.id} block={b} />)}
          </div>
        ))}
      </div>
      <div style={{ borderTop: "1px solid var(--border)", padding: 8 }}>
        <textarea value={draft} onChange={(e) => setDraft(e.target.value)}
          placeholder="发消息…(⌘+Enter)"
          onKeyDown={(e) => { if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) { send.mutate({ content: draft }); } }}
          style={{ width: "100%", minHeight: 48, padding: 6, border: "1px solid var(--border)", borderRadius: 4, background: "var(--bg-paper)", color: "var(--fg-body)", fontFamily: "var(--mono)", fontSize: 12, resize: "vertical" }} />
        <div style={{ display: "flex", justifyContent: "flex-end", marginTop: 4 }}>
          <button onClick={() => send.mutate({ content: draft })} disabled={!draft.trim() || send.isPending}
            style={{ padding: "4px 12px", background: "var(--accent)", color: "var(--accent-fg)", border: "none", borderRadius: 4, cursor: "pointer", fontSize: 12 }}>send</button>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Write TabNav.tsx**

```tsx
// testend/src/layout/TabNav.tsx — col3: 6 collapsible sections × routes.
import { useState } from "react";
import { Link, useLocation } from "react-router-dom";

const SECTIONS: Array<{ label: string; routes: Array<[string, string]> }> = [
  { label: "current", routes: [
    ["/current/wire", "Wire Trace"], ["/current/eventlog", "Eventlog"], ["/current/notifications", "Notifications"],
    ["/current/subagents", "SubAgents"], ["/current/tools", "Tool Calls"], ["/current/todos", "Todos"],
    ["/current/asks", "Asks"], ["/current/attachments", "Attachments"], ["/current/compaction", "Compaction"],
  ]},
  { label: "forge", routes: [
    ["/forge/functions", "Functions"], ["/forge/handlers", "Handlers"], ["/forge/workflows", "Workflows"],
    ["/forge/tools", "Tools Registry"],
  ]},
  { label: "execute", routes: [
    ["/execute/triggers", "Triggers"], ["/execute/flowruns", "FlowRuns"],
    ["/execute/approvals", "Approvals"], ["/execute/executions", "Executions"],
  ]},
  { label: "observe", routes: [
    ["/observe/live", "Live SSE"], ["/observe/notifications", "Notif History"],
    ["/observe/catalog", "Catalog"], ["/observe/usage", "Usage"], ["/observe/mock-llm", "Mock LLM"],
  ]},
  { label: "config", routes: [
    ["/config/apikeys", "API Keys"], ["/config/models", "Models"], ["/config/skills", "Skills"],
    ["/config/mcp", "MCP Servers"], ["/config/sandbox", "Sandbox"], ["/config/memory", "Memory"],
    ["/config/documents", "Documents"], ["/config/permissions", "Permissions"],
    ["/config/llm-health", "LLM Health"], ["/config/profile", "Profile"],
  ]},
  { label: "dev", routes: [
    ["/dev/sql", "SQL"], ["/dev/info", "Info"], ["/dev/routes", "Routes"],
    ["/dev/logs", "Backend Logs"], ["/dev/processes", "Processes"], ["/dev/metrics", "Metrics"],
    ["/dev/errors", "Errors"], ["/dev/prompts", "Prompts"],
  ]},
];

export function TabNav() {
  const loc = useLocation();
  const [collapsed, setCollapsed] = useState<Record<string, boolean>>({});
  return (
    <div style={{ height: "100%", overflowY: "auto", background: "var(--bg-sidebar)", padding: "6px 0" }}>
      {SECTIONS.map((s) => (
        <div key={s.label}>
          <div onClick={() => setCollapsed((c) => ({ ...c, [s.label]: !c[s.label] }))}
            style={{ padding: "4px 12px", cursor: "pointer", fontSize: 11, color: "var(--fg-muted)", textTransform: "uppercase", letterSpacing: 0.5 }}>
            {collapsed[s.label] ? "▸" : "▾"} {s.label}
          </div>
          {!collapsed[s.label] && s.routes.map(([p, l]) => {
            const active = loc.pathname === p;
            return (
              <Link key={p} to={p}
                style={{
                  display: "block", padding: "3px 24px", fontSize: 12, textDecoration: "none",
                  color: active ? "var(--accent)" : "var(--fg-body)",
                  background: active ? "var(--bg-elev)" : "transparent",
                  borderLeft: "2px solid transparent",
                  borderLeftColor: active ? "var(--accent)" : "transparent",
                }}>{l}</Link>
            );
          })}
        </div>
      ))}
    </div>
  );
}
```

- [ ] **Step 4: Rewrite App.tsx with full layout**

```tsx
// testend/src/App.tsx
import { useEffect } from "react";
import { Outlet } from "react-router-dom";
import { useUIStore } from "@/stores/ui";
import { useUsersStore } from "@/stores/users";
import { useNotificationsStore } from "@/stores/notifications";
import { useForgeStore } from "@/stores/forge";
import { useCatalogStore } from "@/stores/catalog";
import { TopBar } from "@/layout/TopBar";
import { ConvSidebar } from "@/layout/ConvSidebar";
import { ChatPanel } from "@/layout/ChatPanel";
import { TabNav } from "@/layout/TabNav";
import { UserPicker } from "@/layout/UserPicker";
import { ResizableSplit } from "@/layout/ResizableSplit";
import { RawJsonModal, ToastTray, CommandPalette } from "@/ui";

export function App() {
  const ui = useUIStore();
  const users = useUsersStore();
  const notifs = useNotificationsStore();
  const forge = useForgeStore();
  const catalog = useCatalogStore();

  useEffect(() => {
    (async () => {
      await users.refresh();
      notifs.start();
      forge.start();
      catalog.refresh();
    })();
    return () => { notifs.stop(); forge.stop(); };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    const h = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") { e.preventDefault(); ui.openPalette(); }
    };
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, [ui]);

  const showPicker = users.list.length >= 2 && !users.list.find((u) => u.id === users.activeId);

  return (
    <div className="app-root">
      <TopBar />
      <div className="layout">
        {ui.expanded ? (
          <>
            <aside style={{ width: 40, background: "var(--bg-sidebar)", borderRight: "1px solid var(--border)" }} />
            <aside style={{ width: 40, background: "var(--bg-sidebar)", borderRight: "1px solid var(--border)" }}><TabNav /></aside>
            <main className="tab-content"><Outlet /></main>
          </>
        ) : (
          <ResizableSplit
            leftWidth={ui.colConv} minLeft={140} maxLeft={380} onResize={ui.setColConv}
            left={<ConvSidebar />}
            right={
              <ResizableSplit
                leftWidth={ui.colChat} minLeft={320} maxLeft={900} onResize={ui.setColChat}
                left={<ChatPanel />}
                right={
                  <ResizableSplit
                    leftWidth={ui.colNav} minLeft={180} maxLeft={320} onResize={ui.setColNav}
                    left={<TabNav />}
                    right={<main className="tab-content"><Outlet /></main>}
                  />
                }
              />
            }
          />
        )}
      </div>
      {showPicker && <UserPicker />}
      <CommandPalette />
      <RawJsonModal />
      <ToastTray />
    </div>
  );
}
```

- [ ] **Step 5: Verify typecheck + build + smoke**

```bash
cd testend && npm run typecheck && npm run build
cd .. && make testend & sleep 4
open http://localhost:8742/dev/
```
Expected: typecheck 0, build clean (dist with chunks for monaco + reactflow). Browser shows full 4-col layout: conv list left, chat panel center, tab nav, placeholder views right. ⌘K palette opens. Click a placeholder view; clicking nav links navigates.

```bash
make stop
```

- [ ] **Step 6: Commit**

```bash
cd /Users/SP14921/Documents/Personal/PersonalCodeBase/Forgify-testend
git add testend/src/layout/*.tsx testend/src/App.tsx
git commit -m "feat(testend/layout): ConvSidebar + ChatPanel + TabNav + App composition

App wires bootstrap (users.refresh → start notifs/forge SSE + catalog).
ConvSidebar pulls /conversations via TanStack; ChatPanel subscribes to
eventlog SSE and renders messages with BlockView; TabNav lists 6 collapsible
sections × routes; ResizableSplit provides drag-resize for 3 dividers."
git push origin testend-v3-react
```

---

## Phase 2 done. 4-col shell live with real chat, conv list, SSE pills, ⌘K palette. All 44 routes still placeholder views. Next: P3 implements each view.

---

## Phase 3 — 44 Views (44 tasks, 2-3 d)

Each view task replaces the `<Placeholder name="..." />` with a real implementation. Common pattern across most views:

1. **Data**: `useQuery({ queryKey: qk.<entity>(), queryFn: () => getJSON(...) })`
2. **Mutation** (if interactive): `useMutation` with `onSuccess: qc.invalidateQueries({ queryKey: qk.<entity>() })`
3. **Render**: dense table (`.dt`) for lists, `<dl>` or `<pre className="raw-json">` for details
4. **Actions**: row click → right-click raw JSON via `ui.showRaw(title, payload)`; mutation buttons trigger via `<button>` + handler
5. **Verification**: `make testend`, visit route in browser, smoke check no console error
6. **Commit**: one per view (or 2-3 grouped views per commit if small)

**Section order:** dev → current → config → forge → execute → observe. This sequence puts least entity-dependent first (dev), then chat (drives BlockView polish), then config (many small simple views), then complex trinity, then execution plane.

**Entity types** all come from `@frontend/entities/<x>/model/types.ts` deep imports.

**Per-view task template:**
- Replace `Placeholder` in `router.tsx` with the real component import
- Write the view component file
- Manual smoke: navigate to route, see real data
- Commit

To save plan length, view tasks below show only the **delta vs template**: imports, data hooks, key JSX, specific actions. The boilerplate (file header, default export, basic error handling via `isError` check) is identical across views.

**Boilerplate every view follows:**

```tsx
import { useQuery } from "@tanstack/react-query";
import { getJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { EmptyView } from "@/ui";

export function MyView() {
  const { data, isLoading, isError, error } = useQuery({ /* per-view */ });
  if (isLoading) return <EmptyView>loading…</EmptyView>;
  if (isError) return <EmptyView>error: {(error as Error).message}</EmptyView>;
  if (!data) return <EmptyView />;
  return ( /* per-view JSX */ );
}
```

---

### Phase 3.A — dev/ (8 views)

#### Task 3.A.1: `views/dev/SQL.tsx` — Monaco SQL console

**File:** `testend/src/views/dev/SQL.tsx`
**Endpoints:** `POST /dev/sql` (via `sqlAPI.run`)
**Components:** MonacoEditor (lazy), dense table for results
**Quick table buttons:** conversations, messages, message_blocks, api_keys, model_configs, functions, function_versions, handlers, handler_versions, workflows, workflow_versions, flowruns, flowrun_nodes, documents, memories, mcp_health_history, sandbox_runtimes, sandbox_envs

- [ ] **Step 1: Write SQL.tsx**

```tsx
import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { sqlAPI, type SqlResult } from "@/api/sql";
import { MonacoEditor } from "@/ui/MonacoEditor";

const QUICK = ["conversations", "messages", "message_blocks", "api_keys", "model_configs",
  "functions", "function_versions", "handlers", "handler_versions",
  "workflows", "workflow_versions", "flowruns", "flowrun_nodes",
  "documents", "memories", "mcp_health_history", "sandbox_runtimes", "sandbox_envs"];

export function SQL() {
  const [sql, setSql] = useState("SELECT id, title FROM conversations ORDER BY created_at DESC LIMIT 50;");
  const run = useMutation<SqlResult, Error, string>({ mutationFn: (q) => sqlAPI.run(q) });
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 8, display: "flex", gap: 4, flexWrap: "wrap", borderBottom: "1px solid var(--border)" }}>
        {QUICK.map((t) => (
          <button key={t} onClick={() => setSql(`SELECT * FROM ${t} ORDER BY rowid DESC LIMIT 50;`)}
            style={{ padding: "2px 8px", fontSize: 11, background: "var(--bg-elev)", border: "1px solid var(--border)", borderRadius: 3, cursor: "pointer" }}>{t}</button>
        ))}
      </div>
      <div style={{ height: 240, borderBottom: "1px solid var(--border)" }}>
        <MonacoEditor value={sql} onChange={setSql} language="sql" height={240} />
      </div>
      <div style={{ padding: 8 }}>
        <button onClick={() => run.mutate(sql)} disabled={run.isPending}
          style={{ padding: "4px 12px", background: "var(--accent)", color: "var(--accent-fg)", border: "none", borderRadius: 4, cursor: "pointer", fontSize: 12 }}>
          {run.isPending ? "running…" : "Run"}
        </button>
        {run.isError && <span style={{ marginLeft: 12, color: "var(--status-error)" }}>{(run.error as Error).message}</span>}
      </div>
      <div style={{ flex: 1, overflow: "auto", padding: 8 }}>
        {run.data && (
          <table className="dt">
            <thead><tr>{run.data.columns.map((c) => <th key={c}>{c}</th>)}</tr></thead>
            <tbody>
              {run.data.rows.map((row, i) => (
                <tr key={i}>{row.map((v, j) => <td key={j}><code style={{ fontSize: 11 }}>{String(v)}</code></td>)}</tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Wire into router.tsx**

Edit `testend/src/router.tsx`: change `{ path: "dev/sql", element: <Placeholder name="dev/SQL" /> }` to `{ path: "dev/sql", element: <SQL /> }`. Add `import { SQL } from "@/views/dev/SQL";` at top.

- [ ] **Step 3: Smoke + commit**

```bash
cd testend && npm run typecheck
cd .. && make testend & sleep 4
# Browse to http://localhost:8742/dev/#/dev/sql
# Click "conversations" quick button → Run → expect table.
make stop
git add testend/src/views/dev/SQL.tsx testend/src/router.tsx
git commit -m "feat(testend/dev): SQL console (Monaco + quick table buttons + results table)"
git push origin testend-v3-react
```

---

#### Task 3.A.2: `views/dev/Info.tsx`

**Endpoint:** `infoAPI.info()` + `infoAPI.forgifyHome()`
**JSX:** `<dl>` showing port / home / forgifyHome / testendDir / mcpConfigPath / skillsDir / catalogCachePath / buildID / goVersion / startedAt / tableCounts table.
**Component sketch:**

```tsx
import { useQuery } from "@tanstack/react-query";
import { infoAPI } from "@/api/info";
import { qk } from "@/hooks/queryKeys";
import { useUIStore } from "@/stores/ui";
import { EmptyView } from "@/ui";

export function Info() {
  const ui = useUIStore();
  const { data: info } = useQuery({ queryKey: qk.devInfo(), queryFn: () => infoAPI.info() });
  const { data: home } = useQuery({ queryKey: qk.devForgifyHome(), queryFn: () => infoAPI.forgifyHome() });
  if (!info) return <EmptyView>loading…</EmptyView>;
  return (
    <div style={{ padding: 12, overflow: "auto", height: "100%" }}>
      <h3>Server</h3>
      <dl className="mono" style={{ fontSize: 12 }}>
        <dt>port</dt><dd>{info.port}</dd>
        <dt>home</dt><dd>{info.home}</dd>
        <dt>forgifyHome</dt><dd>{info.forgifyHome}</dd>
        <dt>testendDir</dt><dd>{info.testendDir}</dd>
        <dt>mcpConfigPath</dt><dd>{info.mcpConfigPath}</dd>
        <dt>skillsDir</dt><dd>{info.skillsDir}</dd>
        <dt>catalogCachePath</dt><dd>{info.catalogCachePath}</dd>
        <dt>build</dt><dd>{info.buildID} / {info.goVersion}</dd>
        <dt>startedAt</dt><dd>{info.startedAt}</dd>
      </dl>
      {info.tableCounts && (
        <>
          <h3>Table Counts</h3>
          <table className="dt"><thead><tr><th>table</th><th>rows</th></tr></thead><tbody>
            {Object.entries(info.tableCounts).sort().map(([t, n]) => <tr key={t}><td>{t}</td><td>{n}</td></tr>)}
          </tbody></table>
        </>
      )}
      {home?.tree && (
        <>
          <h3>~/.forgify tree (at startup)</h3>
          <button onClick={() => ui.showRaw("~/.forgify tree", home.tree)} className="muted" style={{ fontSize: 11 }}>show raw</button>
        </>
      )}
    </div>
  );
}
```

- [ ] Write file, wire router, smoke (`/dev/info`), commit: `feat(testend/dev): Info view (server + table counts + ~/.forgify tree)`

---

#### Task 3.A.3: `views/dev/Routes.tsx`

**Endpoint:** `routesAPI.list()` (reflection-based after P0)
**JSX:** filter input + sortable table of `(method, path)`.

```tsx
import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { routesAPI } from "@/api/routes";
import { qk } from "@/hooks/queryKeys";

export function Routes() {
  const [filter, setFilter] = useState("");
  const { data: routes = [] } = useQuery({ queryKey: qk.devRoutes(), queryFn: () => routesAPI.list() });
  const filtered = routes.filter((r) => !filter || r.path.includes(filter) || r.method.includes(filter.toUpperCase()));
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 8, borderBottom: "1px solid var(--border)" }}>
        <input value={filter} onChange={(e) => setFilter(e.target.value)} placeholder="filter… (method or path)"
          style={{ width: "100%", padding: "4px 8px", border: "1px solid var(--border)", borderRadius: 3, fontSize: 12 }} />
        <span className="muted" style={{ marginLeft: 8, fontSize: 11 }}>{filtered.length} / {routes.length}</span>
      </div>
      <div style={{ flex: 1, overflow: "auto" }}>
        <table className="dt">
          <thead><tr><th style={{ width: 80 }}>method</th><th>path</th></tr></thead>
          <tbody>{filtered.map((r, i) => (
            <tr key={i}><td><code>{r.method}</code></td><td className="mono">{r.path}</td></tr>
          ))}</tbody>
        </table>
      </div>
    </div>
  );
}
```

- [ ] Write file, wire router, smoke (should see ~150+ routes, all auto-reflected), commit: `feat(testend/dev): Routes view (reflection-based, filterable)`

---

#### Task 3.A.4: `views/dev/BackendLogs.tsx`

**Endpoint:** `subscribeLogs` (SSE from `/dev/logs`)
**JSX:** virtualized-ish list with level color, filter input, auto-scroll toggle, clear button.

```tsx
import { useEffect, useRef, useState } from "react";
import { subscribeLogs, type LogEntry } from "@/api/logs";

const LEVEL_COLOR: Record<string, string> = {
  info: "var(--status-success)", warn: "var(--status-warn)",
  error: "var(--status-error)", debug: "var(--fg-muted)",
};

export function BackendLogs() {
  const [entries, setEntries] = useState<LogEntry[]>([]);
  const [filter, setFilter] = useState("");
  const [auto, setAuto] = useState(true);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    return subscribeLogs((e) => setEntries((cur) => [...cur.slice(-2000), e]));
  }, []);
  useEffect(() => { if (auto && ref.current) ref.current.scrollTop = ref.current.scrollHeight; }, [entries.length, auto]);

  const filtered = entries.filter((e) => !filter || e.msg.includes(filter) || (e.fields && JSON.stringify(e.fields).includes(filter)));
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 8, display: "flex", gap: 8, alignItems: "center", borderBottom: "1px solid var(--border)" }}>
        <input value={filter} onChange={(e) => setFilter(e.target.value)} placeholder="filter…"
          style={{ flex: 1, padding: "4px 8px", border: "1px solid var(--border)", borderRadius: 3, fontSize: 12 }} />
        <label style={{ fontSize: 11 }}><input type="checkbox" checked={auto} onChange={(e) => setAuto(e.target.checked)} /> auto-scroll</label>
        <button onClick={() => setEntries([])} style={{ padding: "2px 8px", fontSize: 11 }}>clear</button>
      </div>
      <div ref={ref} style={{ flex: 1, overflow: "auto", fontFamily: "var(--mono)", fontSize: 11, padding: 4 }}>
        {filtered.map((e, i) => (
          <div key={i} style={{ display: "flex", gap: 8, padding: "1px 4px" }}>
            <span className="muted" style={{ width: 80 }}>{new Date(e.time).toLocaleTimeString()}</span>
            <span style={{ color: LEVEL_COLOR[e.level], width: 50 }}>{e.level.toUpperCase()}</span>
            <span style={{ flex: 1 }}>{e.msg}</span>
            {e.fields && <span className="muted">{JSON.stringify(e.fields)}</span>}
          </div>
        ))}
      </div>
    </div>
  );
}
```

- [ ] Write, wire, smoke (logs stream in real-time), commit: `feat(testend/dev): BackendLogs (SSE stream + filter + auto-scroll)`

---

#### Task 3.A.5: `views/dev/Processes.tsx`

**Endpoint:** `infoAPI.bashProcesses()` polled via TanStack (5s interval).
**JSX:** dense table — id / command / cwd / startedAt(RelTime) / status / exitCode.

- [ ] Concrete impl pattern: `useQuery({ refetchInterval: 5000, queryFn: infoAPI.bashProcesses })`, render table. ~40 lines. Wire, smoke, commit: `feat(testend/dev): Processes (bash subprocess list, 5s poll)`

---

#### Task 3.A.6: `views/dev/Metrics.tsx`

**Endpoint:** `infoAPI.runtime()` polled (2s).
**JSX:** 4 stat cards (uptime / goroutines / mem alloc + sys / GC count / db size). Format bytes nicely.

- [ ] ~50 lines. Wire, smoke, commit: `feat(testend/dev): Metrics (runtime stats, 2s poll)`

---

#### Task 3.A.7: `views/dev/Errors.tsx`

**Endpoint:** none — static reference page. Pulls all error codes from `@frontend/shared/api/errorCodes` (proves type+constant sharing).
**JSX:** table of code → i18n key (frontend's mapping for reference) → kind. Filter input.

```tsx
import { useState } from "react";
import { ERROR_CODES } from "@frontend/shared/api/errorCodes";
import { errorKey, kindForCode } from "@frontend/shared/api/errorMap";
import { Pill } from "@/ui";

export function Errors() {
  const [filter, setFilter] = useState("");
  const codes = Object.values(ERROR_CODES).filter((c) => !filter || c.toLowerCase().includes(filter.toLowerCase()));
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 8, borderBottom: "1px solid var(--border)" }}>
        <input value={filter} onChange={(e) => setFilter(e.target.value)} placeholder="filter code…"
          style={{ width: "100%", padding: "4px 8px", border: "1px solid var(--border)", borderRadius: 3, fontSize: 12 }} />
      </div>
      <div style={{ flex: 1, overflow: "auto" }}>
        <table className="dt">
          <thead><tr><th>code</th><th>i18n key</th><th>kind</th></tr></thead>
          <tbody>{codes.map((c) => (
            <tr key={c}><td className="mono">{c}</td><td className="muted mono">{errorKey(c)}</td><td><Pill kind={kindForCode(c) === "warn" ? "warn" : "error"}>{kindForCode(c)}</Pill></td></tr>
          ))}</tbody>
        </table>
      </div>
    </div>
  );
}
```

- [ ] Write, wire, smoke, commit: `feat(testend/dev): Errors (errmap full table from shared errorCodes)`

---

#### Task 3.A.8: `views/dev/Prompts.tsx`

**Endpoint:** `mockLLMAPI.lastPrompt()` (returns the last LLM call's captured messages + tools)
**JSX:** sections by message segment. After 5/27 chat prompt rewrite: segments are `identity` / `how_to_work` / `tools` / `environment` / `capabilities` / `memory_pinned` (drop multi_agent_forging). Show:
- system prompt (concat all segments) in collapsible blocks per segment header
- messages list (raw view)
- tools listed (slim shells)

```tsx
import { useQuery } from "@tanstack/react-query";
import { mockLLMAPI } from "@/api/mockllm";
import { qk } from "@/hooks/queryKeys";
import { useState } from "react";
import { EmptyView } from "@/ui";

interface Msg { role: string; content: string }

export function Prompts() {
  const { data } = useQuery({ queryKey: qk.devInfo().concat(["last-prompt"]), queryFn: () => mockLLMAPI.lastPrompt() });
  const [openSeg, setOpenSeg] = useState<Record<string, boolean>>({});
  if (!data || !data.messages) return <EmptyView>no prompt captured yet — trigger a chat send first</EmptyView>;
  const messages = data.messages as Msg[];
  const system = messages.find((m) => m.role === "system");
  // Split system content by section header — backend chat prompt rewrite (5/27) uses these markers (verify against current chat.runner output)
  const segments = system ? splitBySections(system.content) : {};
  return (
    <div style={{ height: "100%", overflow: "auto", padding: 12 }}>
      <h3>System Prompt — Segments</h3>
      <p className="muted" style={{ fontSize: 11 }}>Aligned to 5/27 chat-prompt-redesign: identity / how_to_work / tools / environment / capabilities / memory_pinned. multi_agent_forging removed.</p>
      {Object.entries(segments).map(([name, body]) => (
        <div key={name} style={{ marginBottom: 6, border: "1px solid var(--border)", borderRadius: 4 }}>
          <div onClick={() => setOpenSeg((o) => ({ ...o, [name]: !o[name] }))}
            style={{ padding: "4px 8px", background: "var(--bg-elev)", cursor: "pointer", fontSize: 12 }}>
            {openSeg[name] ? "▾" : "▸"} <strong>{name}</strong> <span className="muted">{body.length} chars</span>
          </div>
          {openSeg[name] && <pre className="raw-json" style={{ margin: 0 }}>{body}</pre>}
        </div>
      ))}
      <h3>User + Assistant Messages</h3>
      <pre className="raw-json">{JSON.stringify(messages.filter((m) => m.role !== "system"), null, 2)}</pre>
      {data.tools && data.tools.length > 0 && (
        <>
          <h3>Tools ({(data.tools as unknown[]).length})</h3>
          <pre className="raw-json">{JSON.stringify(data.tools, null, 2)}</pre>
        </>
      )}
    </div>
  );
}

// Parse "## <segment>\n...body" markdown headers.
function splitBySections(s: string): Record<string, string> {
  const lines = s.split("\n");
  const out: Record<string, string> = {};
  let cur = "preamble";
  let buf: string[] = [];
  for (const ln of lines) {
    const m = ln.match(/^##\s+(.+)$/);
    if (m) {
      if (buf.length) out[cur] = buf.join("\n").trim();
      cur = m[1].trim();
      buf = [];
    } else {
      buf.push(ln);
    }
  }
  if (buf.length) out[cur] = buf.join("\n").trim();
  return out;
}
```

- [ ] Write, wire, smoke (first trigger a chat to capture a prompt, then visit `/dev/prompts`), commit: `feat(testend/dev): Prompts (5/27 segment-aware viewer, multi_agent_forging removed)`

---

### Phase 3.A done. dev/ section complete. 8 commits.

---

### Phase 3.B — current/ (9 views)

Each `current/*` view scopes to `useConvStore().activeId`. If no active, render `<EmptyView>pick a conversation</EmptyView>`. Most subscribe to SSE eventlog and filter by conversationId, or read from `useChatStore().byConv[activeId]`.

---

#### Task 3.B.1: `views/current/EventlogRaw.tsx`

**Endpoint:** SSE eventlog (live) + `GET /api/v1/conversations/{id}/eventlog?from=0` (historic refetch on demand)
**JSX:** scrolling list of raw SSE envelopes — `seq id event payload(json)`. Filter by event name. Click row → `ui.showRaw`.

```tsx
import { useEffect, useState } from "react";
import { subscribe, type StreamEvent } from "@/api/sse";
import { useConvStore } from "@/stores/conv";
import { useUIStore } from "@/stores/ui";
import { EmptyView } from "@/ui";

export function EventlogRaw() {
  const { activeId } = useConvStore();
  const ui = useUIStore();
  const [events, setEvents] = useState<StreamEvent[]>([]);
  const [filter, setFilter] = useState("");
  useEffect(() => {
    if (!activeId) return;
    return subscribe("eventlog", (e) => {
      if ((e.data as { conversationId?: string }).conversationId !== activeId) return;
      setEvents((cur) => [...cur.slice(-500), e]);
    });
  }, [activeId]);
  if (!activeId) return <EmptyView>pick a conversation</EmptyView>;
  const filtered = events.filter((e) => !filter || e.event.includes(filter));
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 8, borderBottom: "1px solid var(--border)" }}>
        <input value={filter} onChange={(e) => setFilter(e.target.value)} placeholder="filter event name…"
          style={{ width: "100%", padding: "4px 8px", border: "1px solid var(--border)", borderRadius: 3, fontSize: 12 }} />
      </div>
      <div style={{ flex: 1, overflow: "auto", fontFamily: "var(--mono)", fontSize: 11 }}>
        {filtered.map((e, i) => (
          <div key={i} onClick={() => ui.showRaw(`#${e.id} ${e.event}`, e.data)}
            style={{ padding: "2px 8px", borderBottom: "1px solid var(--border-soft)", cursor: "pointer", display: "flex", gap: 8 }}>
            <span className="muted" style={{ width: 60 }}>{e.id}</span>
            <span style={{ width: 120 }}>{e.event}</span>
            <span style={{ flex: 1, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{JSON.stringify(e.data).slice(0, 200)}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
```

- [ ] Write, wire, smoke (send chat msg, see message_start → block_start → block_delta × N → block_stop → message_stop), commit: `feat(testend/current): EventlogRaw (live SSE event tap, conv-scoped, click→raw)`

---

#### Task 3.B.2: `views/current/WireTrace.tsx`

**Source:** `useChatStore.byConv[activeId].messages` — render block tree via BlockView with parentId chain emphasized.
**JSX:** for each message, show `message ID + role + status + parentBlockId`, then `<BlockView>` for each top-level block. Add a sidebar showing block-tree depth + a `parentId` chain inspector when a block is clicked.

- [ ] ~80 lines. Reuses BlockView. Wire, smoke, commit: `feat(testend/current): WireTrace (parentId chain visualization)`

---

#### Task 3.B.3: `views/current/Notifications.tsx`

**Source:** `useNotificationsStore.list` filtered by `conversationId === activeId`.
**JSX:** dense table — time / type / action / data summary (click → raw).

- [ ] ~50 lines. Wire, smoke, commit: `feat(testend/current): Notifications (conv-scoped notif feed)`

---

#### Task 3.B.4: `views/current/SubAgents.tsx`

**Endpoint:** `GET /api/v1/conversations/{id}/messages?kind=subagent_run` (filter by attrs.kind)
**JSX:** group by `attrs.runId`, show type / status / maxTurns / token usage. Click → expand to show nested messages tree.

- [ ] ~80 lines. Wire, smoke, commit: `feat(testend/current): SubAgents (subagent_run rows from messages, attrs-grouped)`

---

#### Task 3.B.5: `views/current/ToolCalls.tsx` ⚠▲ (capability disclosure)

**Source:** Two-pane view:
  - **Left**: live tool_call blocks from chatStore for activeId (table: time / toolName / execution_group / destructive / status / durationMs)
  - **Right**: **Active Toolset** snapshot — resident (28) + lazy groups activated.

**Resident/lazy data source:** Need a new dev endpoint to expose `chatService.GetToolset()` state. Two options:
  - (a) Reuse `/dev/mock-llm/last-prompt` — `tools[]` in the captured prompt reflects current offer set
  - (b) Add `/dev/toolset` (cheap, but new endpoint = backend change)

Pick **(a)** — no backend addition needed. Pulls from `mockLLMAPI.lastPrompt()`; if `tools` present, group by name prefix (e.g. `activate_tools` / `search_function` / etc.) and visualize 28 resident vs lazy groups.

```tsx
// Sketch:
//   left: useChatStore.byConv[activeId].messages → flatMap blocks where type==="tool_call"
//   right: useQuery → mockLLMAPI.lastPrompt() → group tools by category
//     RESIDENT = always present
//     LAZY = present only when activate_tools(category) ran (heuristic: name prefix)
```

- [ ] ~120 lines. Wire, smoke, commit: `feat(testend/current): ToolCalls + active toolset (resident + lazy disclosure)`

---

#### Task 3.B.6: `views/current/Todos.tsx`

**Endpoint:** `GET /api/v1/conversations/{id}/todos`
**JSX:** table — id / subject / status / activeForm / owner / addBlocks / addBlockedBy. Inline status toggle via PATCH.

- [ ] ~70 lines. Wire, smoke, commit: `feat(testend/current): Todos (conv-scoped, status toggle)`

---

#### Task 3.B.7: `views/current/AsksPending.tsx`

**Source:** notificationsStore.list filtered by `type === "ask" && action === "pending"`.
**JSX:** card per pending ask — question / header / options / multiSelect / free-text input fallback. POST `/api/v1/conversations/{id}/asks/{askId}:answer` on submit.

- [ ] ~80 lines. Wire, smoke (trigger ask_user via chat, answer here), commit: `feat(testend/current): AsksPending (interactive answer UI)`

---

#### Task 3.B.8: `views/current/Attachments.tsx`

**Endpoint:** `GET /api/v1/conversations/{id}/attachments` (or messages with attachments)
**JSX:** table — id / filename / contentType / sizeBytes / extractedExcerpt(80 chars).

- [ ] ~50 lines. Wire, smoke, commit: `feat(testend/current): Attachments (per-conv files + extract excerpt)`

---

#### Task 3.B.9: `views/current/Compaction.tsx` ⚠ (補 contextRole 渲染)

**Endpoint:** `GET /api/v1/conversations/{id}` (returns `summary`, `summaryCoversUpToSeq`) + messages with `block.contextRole`.
**JSX:**
  - Top card: summary text (markdown) + coversUpToSeq pill
  - Below: stacked bar showing block distribution by `contextRole`: hot / warm / cold / archived (4 colors)
  - Then: list of compaction blocks (type=compaction) with metadata (coversFromSeq / coversToSeq / blocksArchived / generatedBy)

- [ ] ~100 lines. Wire, smoke, commit: `feat(testend/current): Compaction (summary + contextRole distribution + compaction blocks)`

---

### Phase 3.B done. current/ section complete. 9 commits.

---

### Phase 3.C — config/ (10 views)

Each config view is a CRUD-flavored panel. Common pattern:
- `useQuery` for list + per-id detail
- `useMutation` for create/update/delete with `qc.invalidateQueries`
- Form via uncontrolled `<input>` + state, or controlled with local state

---

#### Task 3.C.1: `views/config/ApiKeys.tsx` ⚠ (補 is_default per-category)

**Endpoints:** `GET/POST/PATCH/DELETE /api/v1/api-keys` + `POST /api/v1/api-keys/{id}:test`
**JSX:** list table (provider/displayName/keyMasked/testStatus/lastTestedAt/isDefault) + Create form + per-row test/edit/setDefault buttons.

**is_default UI:** radio button column per category (llm/search/...). Setting one clears others in same category (backend handles via `ClearDefaultForCategory`; frontend just PATCH `isDefault: true`).

- [ ] ~150 lines. Wire, smoke, commit: `feat(testend/config): ApiKeys (CRUD + per-category is_default radio + :test action)`

---

#### Task 3.C.2: `views/config/ModelConfigs.tsx`

**Endpoints:** `GET /api/v1/model-configs` + `GET /api/v1/providers` + `GET /api/v1/scenarios` + `PUT /api/v1/model-configs/{scenario}`
**JSX:** for each scenario (chat/title-gen/summary/...), a row: scenario name → provider dropdown (from /providers) → modelId text input → Save.

- [ ] ~90 lines. Wire, smoke, commit: `feat(testend/config): ModelConfigs (scenario × provider × model)`

---

#### Task 3.C.3: `views/config/Skills.tsx` ▲ (補 frontmatter 全字段)

**Endpoint:** `GET /api/v1/skills` + `GET /api/v1/skills/{name}`
**JSX:** left list (name + source + description preview) → right detail panel with full SkillFrontmatter fields (name / description / whenToUse / allowedTools / disableModelInvocation / userInvocable / paths / agent / arguments). Show body via Monaco (markdown).

- [ ] ~140 lines. Wire, smoke, commit: `feat(testend/config): Skills (frontmatter full + body Monaco)`

---

#### Task 3.C.4: `views/config/MCPServers.tsx` ⚠ (marketplace V3)

**Endpoints:** `GET /api/v1/mcp-servers` + `POST /api/v1/mcp-servers/{name}:reconnect`
**JSX:** list (name / status / pid / connectedAt / consecutiveFailures / totalCalls / tools.length) + per-row reconnect/delete. Tools count cell expands to show tool list. Health history viewer via separate endpoint if needed.

- [ ] ~120 lines. Wire, smoke, commit: `feat(testend/config): MCPServers (5-status, health, reconnect)`

---

#### Task 3.C.5: `views/config/Sandbox.tsx` ⚠

**Endpoints:** `GET /api/v1/sandbox/runtimes` + `GET /api/v1/sandbox/envs`
**JSX:** two tables side-by-side:
- Runtimes: sr_id / language / version / installedAt / status
- Envs: se_id / owner(5 kinds: function/handler/mcp/skill/conversation) / runtimeId / envStatus(5 states) / sizeBytes / lastUsedAt / lruRank

- [ ] ~110 lines. Wire, smoke, commit: `feat(testend/config): Sandbox (runtimes + envs, 5 owner kinds × 5 status)`

---

#### Task 3.C.6: `views/config/Memory.tsx`

**Endpoints:** `GET /api/v1/memories?type=<t>` + `POST/PATCH/DELETE /api/v1/memories[/name]` + pin via PATCH
**JSX:** tab bar (user / feedback / project / reference) + list with pinned section first → detail panel with editable description/content/type/pinned. source label (user/ai).

- [ ] ~140 lines. Wire, smoke, commit: `feat(testend/config): Memory (4 types × 2 sources, pinned section + CRUD)`

---

#### Task 3.C.7: `views/config/Documents.tsx` ▲▲ (補 Notion 树 + Monaco)

**Endpoints:** `GET /api/v1/documents/tree` + `GET /api/v1/documents/{id}` + `POST/PATCH/DELETE /api/v1/documents`
**JSX:** left tree (recursive with collapse, parentId-based, position-ordered, drag-drop reorder) + right Monaco markdown editor. PATCH document on save.
**Tree component:** recursive `DocTreeNode` — show node.name, indented by path depth, click → load detail in right pane. Drag → PATCH with new parentId + position.

- [ ] ~250 lines. Wire, smoke, commit: `feat(testend/config): Documents (Notion-style tree + Monaco + drag-reorder)`

---

#### Task 3.C.8: `views/config/Permissions.tsx` ⚠ (5/8 §3 final-sweep)

**Endpoints:** `GET /api/v1/permissions` (rules) + `GET /api/v1/permissions/hooks` (hooks table)
**JSX:** two sections — Rules (mode allow/ask/deny, pattern, scope) + Hooks (event → command → match). Editable inline.

(Verify exact endpoints by reading current backend `/permissions*` handlers + references/backend/domains/permissions.md before implementation.)

- [ ] ~140 lines. Wire, smoke, commit: `feat(testend/config): Permissions (rules + hooks, post-§3 final-sweep)`

---

#### Task 3.C.9: `views/config/LLMHealth.tsx`

**Endpoint:** `GET /api/v1/llm/health` (provider connectivity per provider, last test result)
**JSX:** table per provider — provider name / status / lastChecked / latency / errorCount. Manual re-test button.

- [ ] ~90 lines. Wire, smoke, commit: `feat(testend/config): LLMHealth (provider connectivity table)`

---

#### Task 3.C.10: `views/config/Profile.tsx`

**Endpoints:** `GET/POST/PATCH/DELETE /api/v1/users`
**JSX:** list users + Create form (username/displayName/avatarColor/language) + per-row edit + delete (with confirmation). Switch active via usersStore.

- [ ] ~120 lines. Wire, smoke, commit: `feat(testend/config): Profile (user CRUD + multi-profile switch)`

---

### Phase 3.C done. config/ section complete. 10 commits.

---

### Phase 3.D — forge/ (7 views)

Trinity entities (function/handler/workflow), each with list + detail. Detail panels are complex (versions, pending, edit ops, run).

---

#### Task 3.D.1: `views/forge/Functions.tsx` (list)

**Endpoint:** `GET /api/v1/functions`
**JSX:** table — id (link to detail) / name / description / activeVersionId / envStatus / pending(badge) / tags / updatedAt. Filter by name. New button → POST /functions then navigate to detail.

- [ ] ~90 lines. Wire, smoke, commit: `feat(testend/forge): Functions list`

---

#### Task 3.D.2: `views/forge/FunctionDetail.tsx`

**Endpoints:** `GET /api/v1/functions/{id}` + `GET /api/v1/functions/{id}/versions` + `POST /functions/{id}:run` + `POST /functions/{id}:edit` + `POST /functions/{id}:accept` + `POST /functions/{id}:reject` + `POST /functions/{id}:revert`
**JSX:** 3-pane:
- Top: meta + active version pill + pending banner with Accept/Reject buttons
- Middle (tabs): Code (Monaco python) / Parameters (JSON tree) / Return Schema / Dependencies / Env(envStatus + envSyncStage)
- Bottom: Run panel — inputs JSON editor + Run button → execution result + Executions list (D22, with click→detail showing stdout/stderr/durationMs)
- Right side: Versions list (status badges, click to switch active view between versions)

- [ ] ~240 lines. Wire, smoke (create a fn, accept, run), commit: `feat(testend/forge): FunctionDetail (versions + pending + run + executions D22)`

---

#### Task 3.D.3: `views/forge/Handlers.tsx` (list)

Same shape as Functions list + `liveInstances` column + `configState` badge.

- [ ] ~90 lines. Commit: `feat(testend/forge): Handlers list`

---

#### Task 3.D.4: `views/forge/HandlerDetail.tsx`

**Endpoints:** as Function plus `GET/PATCH /api/v1/handlers/{id}/config` + `POST /handlers/{id}:call`
**JSX:** adds Config tab (showing AES-GCM masked config + Set/Clear) + per-instance lifecycle viewer (instances registry) + Call form (method dropdown + args).

- [ ] ~280 lines. Commit: `feat(testend/forge): HandlerDetail (config state + instances + per-call/per-instance + calls D22)`

---

#### Task 3.D.5: `views/forge/Workflows.tsx` (list)

Same shape as Functions list + `enabled / concurrency / needsAttention / liveRuns / lastFiredAt` columns.

- [ ] ~90 lines. Commit: `feat(testend/forge): Workflows list`

---

#### Task 3.D.6: `views/forge/WorkflowDetail.tsx`

**Endpoints:** as Function plus `GET /api/v1/workflows/{id}:check-capabilities` + DAG graph rendering.
**JSX:** 4-pane:
- Top: meta + active version + pending banner + Run/Trigger button (with dryRun toggle)
- Center: **react-flow DAG** rendering `graphParsed.nodes` + `graphParsed.edges`. 13 node types color-coded (capability nodes / control/io nodes).
- Bottom: CapabilityChecker results panel (POST :check-capabilities → list of issues per node)
- Right: Versions, Variables list, recent FlowRuns

**DAG library setup:** Install reactflow already in package.json (P1). Use `<ReactFlow nodes={...} edges={...} />` with custom node component per nodeType.

- [ ] ~350 lines (heaviest view). Wire, smoke (visualize a multi-node workflow, click :check-capabilities), commit: `feat(testend/forge): WorkflowDetail (react-flow DAG + 13 nodes + capability check + variables)`

---

#### Task 3.D.7: `views/forge/ToolsRegistry.tsx` ⚠▲ (capability disclosure visualization)

**Endpoints:** `mockLLMAPI.lastPrompt()` to read offer set (same pattern as ToolCalls);
**JSX:** card grid by category — RESIDENT (28 tools shown by name + description) + LAZY GROUPS (function/handler/workflow/mcp/document/skill — each a card with tool count, expand for tools, marker if currently activated).

```tsx
// Categorization heuristic by name prefix:
const CATEGORIES = {
  RESIDENT: ["activate_tools", "read_memory", "write_memory", "forget_memory", "ask_user_question", "search_skills", "search_mcp_tools", "TodoCreate", "TodoList", "TodoUpdate", "TodoGet", "Read", "Write", "Edit", "Glob", "Grep", "Bash", "BashOutput", "KillShell", "WebFetch", "WebSearch", "Subagent"],
  function:  ["search_function", "get_function", "create_function", "edit_function", "revert_function", "delete_function", "run_function", "search_function_executions", "get_function_execution"],
  handler:   ["search_handler", "get_handler", "create_handler", "edit_handler", "revert_handler", "delete_handler", "call_handler", "update_handler_config", "search_handler_calls", "get_handler_call"],
  workflow:  ["search_workflow", "get_workflow", "create_workflow", "edit_workflow", "revert_workflow", "delete_workflow", "search_workflow_executions", "get_workflow_execution", "trigger_workflow"],
  // ... mcp / document / skill prefixes
};
```

- [ ] ~150 lines. Wire, smoke, commit: `feat(testend/forge): ToolsRegistry (28 resident + 6 lazy groups, post-capability-disclosure)`

---

### Phase 3.D done. forge/ section complete. 7 commits.

---

### Phase 3.E — execute/ (5 views)

---

#### Task 3.E.1: `views/execute/Triggers.tsx`

**Endpoint:** `GET /api/v1/triggers` (list across all workflows) + `POST /api/v1/workflows/{wfId}/triggers/{id}:fire-manual`
**JSX:** dense table — workflow name / kind(cron/fsnotify/webhook/manual) / state / lastFiredAt / nextFireAt(cron). Manual fire button per row.

- [ ] ~80 lines. Commit: `feat(testend/execute): Triggers (4 kinds, manual fire)`

---

#### Task 3.E.2: `views/execute/FlowRuns.tsx`

**Endpoint:** `GET /api/v1/flowruns` paged with cursor + filter by workflowId/status/triggerKind
**JSX:** dense table — id (link to detail) / workflow name / triggerKind / status(badge) / startedAt(RelTime) / elapsedMs / dryRun chip. Infinite scroll via cursor.

- [ ] ~110 lines. Commit: `feat(testend/execute): FlowRuns (paged list + filters)`

---

#### Task 3.E.3: `views/execute/FlowRunDetail.tsx` ▲ (補 RehydrateOnBoot)

**Endpoints:** `GET /api/v1/flowruns/{id}` + `GET /api/v1/flowruns/{id}/nodes`
**JSX:**
- Top: meta — workflowId/versionId/triggerKind/status/startedAt/endedAt/elapsedMs/dryRun
- **Rehydrate banner** if `pausedState` present (shows last persist point + resume capability)
- Center: nodes table — nodeId / nodeType / status(7 states) / input(raw) / output(raw or excerpt) / elapsedMs / attempts / conversationId(link to chat)
- Below: Approval section if any nodeStatus=pending and node type=approval → Approve/Reject form (POST :approve)

- [ ] ~200 lines. Commit: `feat(testend/execute): FlowRunDetail (nodes + rehydrate state + approval inline)`

---

#### Task 3.E.4: `views/execute/ApprovalsQueue.tsx`

**Endpoint:** `GET /api/v1/flowruns?status=paused` filtered to those with pending approval nodes
**JSX:** card per pending approval — workflow / flowrun / node / context. Approve/Reject buttons inline.

- [ ] ~90 lines. Commit: `feat(testend/execute): ApprovalsQueue (pending approval cards)`

---

#### Task 3.E.5: `views/execute/Executions.tsx`

**Endpoints:** 4 D22 tables — `GET /api/v1/functions/{id}/executions` / handler calls / mcp calls / skill executions, aggregated.
**JSX:** tab bar (function / handler / mcp / skill) → each tab shows paged table of recent executions across all entities. Filter by entity name.

- [ ] ~150 lines. Commit: `feat(testend/execute): Executions (D22 — function/handler/mcp/skill exec history)`

---

### Phase 3.E done. execute/ section complete. 5 commits.

---

### Phase 3.F — observe/ (5 views)

---

#### Task 3.F.1: `views/observe/LiveSSE.tsx`

**Source:** all three streams via `subscribe`.
**JSX:** 3 panes (eventlog / notifications / forge) side-by-side. Each shows last 100 events, raw JSON. Reset button per pane → `reconnect(stream)`.

- [ ] ~140 lines. Commit: `feat(testend/observe): LiveSSE (3-pane raw event tap, reset-to-0)`

---

#### Task 3.F.2: `views/observe/NotificationHistory.tsx`

**Source:** `useNotificationsStore.list` (all, no conv scope) + `GET /api/v1/notifications/snapshot` (historic).
**JSX:** dense table — time / type / action / conversationId(if any) / data summary(click→raw). Filter by type.

- [ ] ~90 lines. Commit: `feat(testend/observe): NotificationHistory (all-types, historic + live merged)`

---

#### Task 3.F.3: `views/observe/Catalog.tsx`

**Source:** `useCatalogStore.current` (single endpoint after 5/25)
**JSX:** stats row (generatedAt / fingerprint / total items) + grouped table by source (function/handler/workflow/skill/mcp) → each item: name / description / granularity. Refresh button.

- [ ] ~80 lines. Commit: `feat(testend/observe): Catalog (single-endpoint aligned)`

---

#### Task 3.F.4: `views/observe/Usage.tsx`

**Source:** aggregate from `GET /api/v1/conversations/{id}/messages` across recent convs OR via SQL view if defined. For V3 first cut: just sum `message.inputTokens + outputTokens` across last 50 messages per conv.
**JSX:** stat cards (today total input/output tokens / this conv) + table of conv → totals → cost estimate (using static $/1k token rates).

- [ ] ~120 lines. Commit: `feat(testend/observe): Usage (token totals + estimate)`

---

#### Task 3.F.5: `views/observe/MockLLM.tsx` ⚠

**Endpoints:** `mockLLMAPI.push/queue/clear/lastPrompt`
**JSX:** Monaco editor (json) to compose scripts array → Push button → queue viewer → Clear button. Below: last captured prompt (read-only) for verification.

- [ ] ~140 lines. Commit: `feat(testend/observe): MockLLM (push scripts + queue + last prompt)`

---

### Phase 3.F done. observe/ section complete. 5 commits.

---

## Phase 3 complete. 44 views all real. typecheck + build clean. Browser walk-through shows real data everywhere. Now P4: verification + docs.

---

## Phase 4 — Verification + Doc Sync (10 tasks, 0.5 d)

After P3 every view renders; P4 nails verification + does the documentation pass (§S14 + §F1 trigger table). End state: testend V3 ready to FF-merge to main.

---

### Task 4.1: Full static verification sweep

- [ ] **Step 1: testend typecheck + build**

```bash
cd testend && npm run typecheck && npm run build
```
Expected: 0 errors, 0 warnings. `dist/index.html` + chunked JS files (main ~150 KB, monaco lazy chunk ~3 MB, reactflow ~500 KB).

- [ ] **Step 2: Backend build + staticcheck**

```bash
cd ../backend && go build ./... && staticcheck ./...
```
Expected: 0 errors.

- [ ] **Step 3: Backend test regression**

```bash
cd .. && make test-backend
```
Expected: 174 packages green (P0 changes shouldn't have regressed).

- [ ] **Step 4: Frontend regression (untouched, but verify)**

```bash
cd frontend && npm run typecheck && npm test -- --run && npm run build
```
Expected: 0 errors, vitest green, build clean. We touched `shared/api/errorMap.ts` + added `errorCodes.ts` in P0; this confirms no regression.

- [ ] **Step 5: (no commit — verify only)**

---

### Task 4.2: Manual smoke — 44 routes walk-through

**Files:** (none modified)

- [ ] **Step 1: Boot**

```bash
cd /Users/SP14921/Documents/Personal/PersonalCodeBase/Forgify-testend
make testend & sleep 5
open http://localhost:8742/dev/
```

- [ ] **Step 2: Walk every route**

In browser, click through each of 6 sections in TabNav. For each route:
- Loads without console error (open DevTools console)
- Shows real data or "no X yet" empty state (not the `TODO: ...` placeholder)
- Top bar SSE pills: EL/NF/FG all green within 2s

Record any failure into a scratch list. If any route 404s or console-errors, return to P3 for that view, fix, retest.

Expected: 44 routes all clean.

- [ ] **Step 3: Stop server**

```bash
make stop
```

- [ ] **Step 4: (no commit — verify only)**

---

### Task 4.3: Manual smoke — end-to-end chat flow

- [ ] **Step 1: Boot, navigate to a conversation**

```bash
make testend & sleep 5
open http://localhost:8742/dev/
```

- Pick (or create) a conv in left sidebar
- Ensure a chat-scenario model config is set (Config → Models view, or via main frontend)
- Ensure an API key exists for the configured provider

- [ ] **Step 2: Send a message that triggers tool calls**

In ChatPanel composer, type something like:

> What's the current time? Use a tool if needed.

Press ⌘+Enter to send.

- [ ] **Step 3: Observe**

In ChatPanel (col2): user message renders, then assistant message status flips streaming → completed. BlockView shows:
- (optional) reasoning block (collapsed)
- text block (LLM's response)
- if tool used: tool_call block → tool_result block nested inside, both with progress sub-blocks if any

Switch to `/current/eventlog`: should see full event sequence — `message_start` → `block_start` × N → `block_delta` × many → `block_stop` × N → `message_stop`. Each event seq monotonically increasing.

Switch to `/current/wire`: parentId chain visualization shows tool_result correctly nested under tool_call.

Switch to `/dev/prompts`: see the system prompt segmented (identity, how_to_work, tools, environment) and the captured messages.

- [ ] **Step 4: Stop**

```bash
make stop
```

- [ ] **Step 5: (no commit — verify only)**

---

### Task 4.4: Rewrite `testend-design.md` to V3

**Files:**
- Modify (rewrite): `documents/version-1.2/working/testend/testend-design.md`

**Context:** The V2 design doc is mostly accurate in shape but lists Vue/Pinia and outdated view counts. Rewrite as V3 — React/TanStack/Zustand/Vite, shared types via vite alias, 44 views, backend cleanup record.

- [ ] **Step 1: Write new content**

```bash
# Open the file and replace top-to-bottom (V2 history can stay at bottom as historical archive).
```

The new doc should:
1. **§ V3 当前形态(2026-05-27 重写完工)** — covers Vite-React stack, 4-col layout (unchanged), 44 views, shared types via vite alias (path alias diagram), 3 SSE per-user streams (unchanged), build flow.
2. **§ Backend dev infra (post-P0)** — list of remaining `/dev/*` endpoints + what was deleted (collections, tools, invoke, tester.html fallback) + `--testend-dir` rename + Recorder explanation.
3. **§ V2 历史 (2026-05-14, 已淘汰)** — keep the V2 section content from current doc as historical archive (its 4-col + 33 view + Vue references).
4. **§ V1 历史 (2025-Q1, 已淘汰)** — keep the V1 section as deep history.

(Write the file by reading the existing one + Edit-replacing the top sections; preserve V1/V2 archive at bottom.)

- [ ] **Step 2: Commit**

```bash
git add documents/version-1.2/working/testend/testend-design.md
git commit -m "doc(testend): rewrite testend-design.md to V3 (React + shared types + Recorder)

V2 + V1 sections preserved as historical archive. V3 section
documents: stack (React 19/TanStack v5/Zustand v5/Vite 6/RR6 hash),
shared with frontend via vite path alias (only entity types + errorCodes +
motion tokens), 44 views in 6 flat sections (no FSD), 3 per-user SSE
unchanged, backend dev cleanup record (Recorder + 5 deletions)."
git push origin testend-v3-react
```

---

### Task 4.5: Update `api-design.md` — delete dev endpoint sections

**Files:**
- Modify: `documents/version-1.2/references/backend/api.md`

- [ ] **Step 1: Locate `/dev/*` sections**

```bash
grep -n "dev/collections\|dev/tools\|dev/invoke" documents/version-1.2/references/backend/api.md
```

- [ ] **Step 2: Delete sections for `/dev/collections`, `/dev/tools`, `/dev/invoke`**

Edit out the rows / paragraphs for those three endpoints. Add a note to `/dev/routes` row: "reflection-based via `router.Recorder` (2026-05-27)".

- [ ] **Step 3: Update `--integration-dir` → `--testend-dir` if mentioned**

```bash
grep -n "integration-dir" documents/version-1.2/references/backend/api.md
```

Rename any occurrence.

- [ ] **Step 4: Commit**

```bash
git add documents/version-1.2/references/backend/api.md
git commit -m "doc(api): delete /dev/{collections,tools,invoke} + note /dev/routes reflection

Aligns api-design.md with P0 backend cleanup. --integration-dir
references updated to --testend-dir."
git push origin testend-v3-react
```

---

### Task 4.6: Append `references/changelog.md` dev log

**Files:**
- Modify: `documents/version-1.2/references/changelog.md`

**Context:** Append one dev log entry per §S19 (1-2 sentences, ~30-100 chars). Place under a new (or existing) 2026-05-27 group section.

- [ ] **Step 1: Read current references/changelog.md tail to find the right insertion point**

```bash
tail -80 documents/version-1.2/references/changelog.md
```

- [ ] **Step 2: Insert dev log entry**

After the existing 2026-05-27 entries, add:

```markdown
| 2026-05-27 | **[feat]** testend V3 React 重做 + backend dev 设施清理(`testend-v3-react` 分支 FF→main):栈 Vue→React 19+TanStack v5+Zustand v5+Vite 6;通过 vite path alias 共享 frontend entity TS 类型 + errorCodes 常量(根治 2 周一次的 drift);44 view 重写(扁平,不进 FSD);后端配套:`router.Recorder` 包装 ServeMux 让 `/dev/routes` 反射自动生成,删 `/dev/collections` + `/dev/tools` + `/dev/invoke` + tester.html fallback + `Deps.Tools` 字段,`--integration-dir` → `--testend-dir`。typecheck + build + 174 backend 包 + 44 路由 smoke + 真 LLM chat E2E 全绿。 |
```

- [ ] **Step 3: Update快照 section if needed**

```bash
grep -n "前端 revamp\|当前重心" documents/version-1.2/references/changelog.md | head -5
```

If the 快照 table mentions testend in any "当前状态" row, update accordingly. The "当前重心" might shift from "前端功能交付" to "testend 已重做 V3 + 前端继续".

- [ ] **Step 4: Commit**

```bash
git add documents/version-1.2/references/changelog.md
git commit -m "doc(progress): testend V3 + backend dev cleanup dev log"
git push origin testend-v3-react
```

---

### Task 4.7: Append `testend-rewrite-backend-issues.md` V3 section

**Files:**
- Modify: `documents/version-1.2/working/testend/testend-rewrite/testend-rewrite-backend-issues.md`

- [ ] **Step 1: Append V3 section after the V2 收尾总结**

```markdown
---

## V3 (2026-05-27 — React rewrite) — issue log

### #5 sse.ts comment `5 × 6 block types` stale

- **发现**: V2 sse.ts JSDoc 注释说 5 events × 6 block types,实际 5/14 后 compaction block 加入是 7。
- **判断**: 注释 drift,V3 写新代码无此问题。
- **行动**: V3 sse.ts 注释直接写 7 block types;V2 注释 drift 作为"为什么需要 shared type"的实证。
- **commit**: N/A (V3 写法直接正确)

### #6 V2 IDPrefix 联合类型不全 + 含已废条目

- **发现**: V2 types/api.ts::IDPrefix 缺 `hdi_` / `rel_` / `mch_` / `sr_` / `se_` / `u_`;有已废 `sar_` / `smm_`(subagent 改 messages 行 attrs.kind)。
- **判断**: V3 不再维护 testend 自己的 IDPrefix——id 前缀语义嵌在 frontend entity 类型每个 `id` 字段的注释中,共享 type 即可。
- **行动**: V3 testend 不写 IDPrefix 类型;通过 alias import 类型即跟随 backend §S15 定义。

### #7 `dev_routes.go` 手维护清单 drift(根治版)

- **发现**: V2 testend-rewrite issue #3 已记录手维护清单 drift。5/14 后又 drift 了一遍。
- **判断**: 任何手维护清单都会 drift。需要根本性改造。
- **行动**: V3 P0 引入 `router.Recorder`——包装 `*http.ServeMux`,`HandleFunc(pattern, h)` 调底层 + append `Route{Method, Path}`。`/dev/routes` 直接读 `Recorder.List()`。**Drift 永久消除**。
- **commit**: `feat(router): add Recorder` + `refactor(dev): /dev/routes reads from Recorder.List()`

### Status of #4 (Block.Attrs 双形态)

V2 issue #4 (REST `attrs` 是 JSON 字符串,SSE 是对象) **仍未在后端根治**。V3 testend 继续 client-side workaround:hook `useNormalizedBlock(block)` + `normalizeBlocks(blocks)`(`testend/src/hooks/useNormalizedBlock.ts`)。长期后端 fix 留独立 plan(chat domain 重写时一起做)。

---

### V3 收尾总结(2026-05-27)

P0 backend cleanup(8 commits) + P1 scaffold(7 commits) + P2 infrastructure(15 commits) + P3 views(44 commits)+ P4 verification & doc sync(7 commits)= **~81 commits**。Branch `testend-v3-react` 完工后 FF-merge → main。

后端净改:1 新文件(`recorder.go`)+ 1 删文件(`dev_routes.go`)+ ~6 文件 edit;`Deps.Tools` / `CollectionsDir` 字段 + 2 个 flag + 3 个 handler 删除。无产品核心变动。

前端净改:1 新文件(`shared/api/errorCodes.ts`)+ 1 edit(`shared/api/errorMap.ts` 从 const 抽出)。无功能变动。
```

- [ ] **Step 2: Commit**

```bash
git add documents/version-1.2/working/testend/testend-rewrite/testend-rewrite-backend-issues.md
git commit -m "doc(testend): append V3 issue log (issues #5 #6 #7 + #4 status + V3 总结)"
git push origin testend-v3-react
```

---

### Task 4.8: Create `testend/CLAUDE.md`

**Files:**
- Create: `testend/CLAUDE.md`

**Context:** Sub-project工程纪律。Loaded by Claude Code when working inside `testend/`. Establishes: stack, no FSD, type-only shared imports, version sync rule, commit/push discipline.

- [ ] **Step 1: Write testend/CLAUDE.md**

```markdown
# Testend — Claude 工作守则

> 本文件是 testend 子项目的工程纪律事实源。项目根 [`../CLAUDE.md`](../CLAUDE.md) 仍生效,本文件**补充**而非覆盖;冲突时本文件赢(仅 testend 范围内)。

---

## 一句话

testend 是 Forgify 的**开发调试控制台**,React 19 + TanStack Query v5 + Zustand v5 + Vite 6,通过 vite path alias 共享 `frontend/src/` 的 entity TS 类型 + shared/api/errorCodes 常量。完工于 2026-05-27 V3 重写。

---

## 必读文档

| 用途 | 路径 |
|---|---|
| 设计文档 | [`../documents/version-1.2/working/testend/testend-design.md`](../documents/version-1.2/working/testend/testend-design.md) |
| issue log | [`../documents/version-1.2/working/testend/testend-rewrite/testend-rewrite-backend-issues.md`](../documents/version-1.2/working/testend/testend-rewrite/testend-rewrite-backend-issues.md) |
| V3 rewrite plan/spec | 同目录下 `2026-05-27-react-rewrite-{design,plan}.md` |

---

## 改代码前必做

1. 读对应 view 的源(`testend/src/views/<section>/<View>.tsx`)
2. 如果数据契约变更(entity 字段 / endpoint),先确认 frontend `src/entities/<x>/model/types.ts` 已对齐 backend(共享源在 frontend);testend 跟随,无独立 type 副本
3. 改完跑 `cd testend && npm run typecheck && npm run build`(硬门禁)
4. 同步文档(§F1 testend 部分)

---

## 9 条 testend 纪律

1. **不进 FSD layered 架构**。testend 是 tool,扁平 view-driven。`src/views/<section>/<View>.tsx` 直接读 stores + 调 hooks + 渲染。不要拆 entities / features / widgets / pages。
2. **共享 frontend 只通过 type-only 深引**:`import type { X } from "@frontend/entities/<x>/model/types"`。**不经 barrel `index.ts`**(barrel 会拉 React hook 运行时,污染 testend bundle)。
3. **deps 版本号严格 sync frontend**。`testend/package.json` 中 React / TanStack Query / Zustand / Vite / TypeScript / lucide-react 的版本号**必须**与 `frontend/package.json` 一致。每次 frontend 升级,testend 同步。验证:`npm ls react`(两边),版本号需一字不差。否则会出 "Multiple React instances" 运行时错误。
4. **不写单元测试**。门禁是 `npm run typecheck` + `npm run build` + 浏览器手动 44 路由 smoke + 真 LLM E2E。testend 是 dev tool,加单测是过度工程。
5. **不引 i18n**。testend 用户是开发者(单人),中英混排即可。不要复用 frontend 的 react-i18next。
6. **commit 粒度 = 一 view 一 commit**(或邻近 2-3 简单 view 一 commit)。push 跟每次 commit。
7. **不在 commit message 加 `Co-Authored-By: Claude`**(per project memory)。
8. **不开分支**(主分支 testend-v3-react 是双 session 并行场景的产物;日常 dev 在 main)。
9. **错误展示原码,不走 errorMap**。frontend 走 errorCodes → errorMap → i18n key → t()。testend 直接显示 backend 返回的 `error.code` + `error.message`,debug 视角需要看原始码。

---

## 横切机制(同 frontend §F1 同步触发表)

| testend 代码变动 | 必改文档 |
|---|---|
| 新 view / 删 view | testend-design.md view inventory + references/changelog.md dev log |
| 引入新 dev 后端 endpoint 消费 | api-design.md + testend-design.md + references/changelog.md |
| 改共享 import 模式(alias / type 路径) | testend/CLAUDE.md(本文件)+ frontend/CLAUDE.md(若动到 frontend) |
| 后端 dev/* 端点删除/新增 | api-design.md + testend-design.md + references/changelog.md |
| 发现并修了 testend 影响产品核心思想的 bug | references/changelog.md + testend-rewrite-backend-issues.md V3 段 |

发现文档与代码不符 → 立刻停下修文档,记 `[doc-fix]` dev log。

---

## 跑起来

```bash
make testend       # 一行起来,浏览器自动打开 http://localhost:8742/dev/
make stop          # 关
```

`make testend` 内部:`go run ./backend/cmd/server --dev --port 8742 --testend-dir testend/dist` + `cd testend && npm run build` 先行(若 dist 存在则跳过)。

开发期热重载:`cd testend && npm run dev`(单独跑 vite dev server,5174 端口;后端仍走 8742)。

---

## Verification 三层(每次 commit 前)

| 层 | 命令 | 通过条件 |
|---|---|---|
| 静态 | `cd testend && npm run typecheck` | 0 error |
| 静态 | `cd testend && npm run build` | 0 error / 0 warning |
| 动态 | `make testend` + 浏览器开当前修改的 view | 无 console error / 数据/UI 正确 |

整体回归(大变动后):`make test-backend`(174 包) + 跑 frontend `npm test -- --run`(确保没误碰 frontend shared)。
```

- [ ] **Step 2: Commit**

```bash
git add testend/CLAUDE.md
git commit -m "doc(testend): add CLAUDE.md (sub-project工程纪律 — V3 baseline)"
git push origin testend-v3-react
```

---

### Task 4.9: Update project-root `CLAUDE.md` — add testend doc-map link

**Files:**
- Modify: `CLAUDE.md` (project root)

- [ ] **Step 1: Find the doc-map table**

```bash
grep -n "文档地图\|## 文档地图" CLAUDE.md
```

- [ ] **Step 2: Add testend row**

Locate the doc-map table near the top of CLAUDE.md. Add row:

```markdown
| testend 子项目工程纪律 | `testend/CLAUDE.md` |
| testend V3 设计 | `documents/version-1.2/working/testend/testend-design.md` |
```

- [ ] **Step 3: Update "前端开发守则" section if testend is referenced**

```bash
grep -n "前端开发守则\|testend" CLAUDE.md | head -10
```

Append a short note in the前端开发守则 section: "**testend 子项目**:不进 FSD,扁平 view-driven,共享 frontend entity types via vite path alias;详见 `testend/CLAUDE.md`。"

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "doc(root): add testend doc-map links + brief 前端守则 note"
git push origin testend-v3-react
```

---

### Task 4.10: Final smoke + FF-merge readiness check

**Files:** (none modified)

- [ ] **Step 1: Confirm branch is ahead of main**

```bash
git fetch origin
git log origin/main..HEAD --oneline | head -100
```
Expected: ~81 commits on top of main (P0 + P1 + P2 + P3 + P4).

- [ ] **Step 2: Check main hasn't moved (e2e session hasn't merged yet)**

```bash
git log origin/main..origin/testend-v3-react --oneline | head -3
git log origin/testend-v3-react..origin/main --oneline | head -3  # should be empty if main hasn't moved
```

Two scenarios:

**(A) main hasn't moved** — FF possible:
```bash
git checkout main
git pull --ff-only
git merge --ff-only testend-v3-react
git push origin main
# Then delete the branch
git branch -d testend-v3-react
git push origin --delete testend-v3-react
git worktree remove ../Forgify-testend
```

**(B) main has moved (e2e session merged first)** — rebase first:
```bash
git checkout testend-v3-react
git fetch origin
git rebase origin/main
# Resolve any conflicts (likely in shared files: Makefile / CLAUDE.md / references/changelog.md)
git push origin testend-v3-react --force-with-lease
# Then proceed with FF-merge as (A)
```

- [ ] **Step 3: Final verification on main (post-merge)**

After FF-merge to main:

```bash
cd /Users/SP14921/Documents/Personal/PersonalCodeBase/Forgify
git pull
make test-backend
make testend & sleep 5
# Browser smoke: every section, a few views
make stop
```
Expected: 174 packages green, testend boots, 44 views all clean.

- [ ] **Step 4: Inform user / final commit (none — handoff)**

Plan complete. testend V3 in main. e2e session can FF-merge whenever ready (or already did; this plan handled both orderings).

---

## Phase 4 done. testend V3 ready / merged.

---

## Summary

- **Total commits**: ~81 across 5 phases on branch `testend-v3-react`
- **Plan duration**: 5-6.5 days estimated; tracks actuals via commits + progress-record dev log
- **Forbidden zones honored**: `backend/test/**` + `backend/cmd/coverage-matrix/` untouched throughout
- **Shared files touched**: `Makefile` (1 line in testend target), `CLAUDE.md` (doc-map row), `references/changelog.md` (1 dev log entry), `references/backend/api.md` (3 endpoint sections deleted) — all via own branch, integrated at FF-merge
- **Backend net delta**: +1 new file (recorder.go), -1 deleted (dev_routes.go), ~6 files edited, 3 handlers + 2 fields + 1 flag deleted, 1 flag renamed
- **Frontend net delta**: +1 new file (errorCodes.ts), 1 file edited (errorMap.ts refactor)
- **testend net delta**: complete rewrite — 1 deleted Vue scaffold, ~70 new React files (`src/{api,stores,hooks,layout,ui,views}/`)

Plan complete.

