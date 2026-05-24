# User Identity Cleanup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the `local-user` magic string into three distinct concerns (pre-onboarding placeholder, HTTP fallback, background-task ownership) so that frontend self-heals from stale state, middleware enforces strict identity, and background tasks iterate over real users.

**Architecture:** Backend middleware splits into `IdentifyUser` (header → ctx) + `RequireUser` (401 if nil). Background tasks fetch the user list and run per-user instead of stamping a magic id. Frontend gains a self-heal effect (validate `activeUserId` against `/users`, clear if stale, auto-select if single user remains) and SSE rebuilds its EventSource whenever `activeUserId` changes. The `local-user` row stays as ordinary data — the string loses its magic.

**Tech Stack:** Go (chi router, GORM, zap, vitest only as frontend infra), React (zustand, TanStack Query, native EventSource).

**Spec:** [`docs/superpowers/specs/2026-05-24-user-identity-cleanup.md`](../specs/2026-05-24-user-identity-cleanup.md)

---

## File Map

### Backend — modify

- `backend/internal/infra/db/db.go` — add `IgnoreRecordNotFoundError: true`
- `backend/internal/domain/errors/sentinel.go` — add `ErrUnauthorizedNoUser`
- `backend/internal/transport/httpapi/errmap.go` — register the sentinel
- `backend/internal/transport/httpapi/middleware/auth.go` — rewrite (split into IdentifyUser + RequireUser; preserve legacy `InjectUserID` as test-only helper)
- `backend/internal/transport/httpapi/middleware/auth_test.go` — rewrite for new semantics
- `backend/internal/transport/httpapi/router.go` (or wherever router wires middleware) — apply RequireUser; exempt `/users`
- `backend/internal/app/catalog/polling.go` — iterate users in `pollLoop`/`tryRefresh` (the only fallback site)
- `backend/internal/app/scheduler/rehydrate.go` — iterate users
- `backend/internal/app/mcp/calltool.go` — remove fallback; require explicit user
- `backend/internal/app/skill/exec_log.go` — remove fallback
- `backend/internal/app/trigger/trigger.go` — remove fallback
- `backend/internal/app/user/user.go` — delete `EnsureDefault` (lines 99-128)
- `backend/internal/app/user/user_test.go` — delete `TestEnsureDefault`
- `backend/cmd/server/main.go` — delete `userService.EnsureDefault(...)` call (line 210); refactor any background-task wiring that passed `DefaultLocalUserID`
- `backend/internal/pkg/reqctx/reqctx.go` — delete `DefaultLocalUserID` constant (lines 21-24)
- `backend/test/harness/seed.go` — rename `LocalCtx()` → `SeedCtx(t)` that creates a user and stamps its id
- Test fixtures (~13 files; mechanical replace "local-user" → "test-user" plus harness call) — list in Task 18

### Frontend — modify

- `frontend/src/store/settings.js` — update comment for `activeUserId`
- `frontend/src/api/client.js` — add 401 handler in `apiFetch`
- `frontend/src/App.jsx` — self-heal + auto-select effect; rewrite fresh-install detection
- `frontend/src/sse/shared.js` — skip when activeUserId null
- `frontend/src/sse/SSEProvider.jsx` — 4-state machine: idle when null, rebuild on change, self-heal on close
- (Possibly) `frontend/src/components/overlays/Onboarding.jsx` — verify it still triggers correctly

### Docs — modify

- `CLAUDE.md` — S15 ID prefix table (add `u_` for users)
- `documents/version-1.2/backend-design.md`
- `documents/version-1.2/service-design-documents/user.md`
- `documents/version-1.2/service-design-documents/catalog.md`
- `documents/version-1.2/service-design-documents/trigger.md`
- `documents/version-1.2/frontend-prd.md`
- `documents/version-1.2/progress-record.md` — add dev log

---

## Execution Order Rationale

1. **Foundation** (errors, GORM) — non-breaking; immediate wins.
2. **Frontend self-heal** — no-op until backend changes; harmless to deploy first; means when backend starts returning 401 the frontend is ready.
3. **Background-task refactor** — depend on `userService.List`; still work with current `local-user` seed during transition.
4. **Test fixtures + harness refactor** — must be done before deleting the const, or tests won't compile.
5. **Middleware behavior change** — the breaking commit.
6. **Delete dead code** — `EnsureDefault`, `DefaultLocalUserID`, related tests.
7. **Docs + verification.**

---

## Phase A — Foundation (non-breaking)

### Task 1: GORM ignore not-found noise

**Files:**
- Modify: `backend/internal/infra/db/db.go`

- [ ] **Step 1: Read current Logger config**

Already known: line 33-40 sets `Logger: gormlogger.Default.LogMode(logLevel)`. We replace with a custom-config logger.

- [ ] **Step 2: Write the new logger**

Replace lines 33-42 with:

```go
logLevel := cfg.LogLevel
if logLevel == 0 {
    logLevel = gormlogger.Warn
}

gormLog := gormlogger.New(
    log.New(os.Stdout, "\r\n", log.LstdFlags),
    gormlogger.Config{
        SlowThreshold:             200 * time.Millisecond,
        LogLevel:                  logLevel,
        IgnoreRecordNotFoundError: true,
        Colorful:                  false,
    },
)

db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{
    NowFunc:     func() time.Time { return time.Now().UTC() },
    Logger:      gormLog,
    PrepareStmt: true,
})
```

Add imports at top: `"log"`, `"os"`.

- [ ] **Step 3: Build**

Run: `cd backend && go build ./...`
Expected: success.

- [ ] **Step 4: Run db tests**

Run: `cd backend && go test ./internal/infra/db/...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/internal/infra/db/db.go
git commit -m "chore(backend): silence GORM record-not-found noise

Lookup-or-default patterns (e.g. middleware user resolver) intentionally
probe by id and tolerate misses. The default GORM logger prints these as
Warnings, flooding dev logs. IgnoreRecordNotFoundError:true keeps the rest
of the logger's behavior intact."
```

---

### Task 2: Add UNAUTH_NO_USER sentinel

**Files:**
- Read first: `backend/internal/domain/errors/` (find the sentinel file)
- Modify: the sentinel file
- Modify: `backend/internal/transport/httpapi/errmap.go`

- [ ] **Step 1: Locate the sentinel file**

Run: `find backend/internal/domain/errors -type f -name '*.go'`
Note the path of the file defining other sentinels (e.g., `ErrNotFound`).

- [ ] **Step 2: Add the new sentinel**

In the same file, add:

```go
// ErrUnauthorizedNoUser is returned when a request reaches a user-scoped route
// without a valid X-Forgify-User-ID header. Frontend treats this as a cue to
// clear localStorage.activeUserId and re-onboard.
//
// ErrUnauthorizedNoUser:请求未携带有效 X-Forgify-User-ID;前端据此清 localStorage
// 重走 onboarding。
var ErrUnauthorizedNoUser = errors.New("unauthorized: no valid user id")
```

- [ ] **Step 3: Register the mapping**

Locate `errmap.go::errTable` (likely a slice of `{sentinel, code, status}`). Add the row:

```go
{errorsdomain.ErrUnauthorizedNoUser, "UNAUTH_NO_USER", http.StatusUnauthorized},
```

- [ ] **Step 4: Build**

Run: `cd backend && go build ./...`
Expected: success.

- [ ] **Step 5: Verify via existing errmap test if present**

Run: `cd backend && go test ./internal/transport/httpapi/...`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/internal/domain/errors backend/internal/transport/httpapi/errmap.go
git commit -m "feat(backend): add ErrUnauthorizedNoUser sentinel + UNAUTH_NO_USER mapping

Prep for middleware refactor: routes without a valid user id will return
this sentinel instead of silently demoting to local-user."
```

---

## Phase B — Frontend Self-Heal (non-breaking; works even before backend changes)

### Task 3: apiFetch 401 handler

**Files:**
- Modify: `frontend/src/api/client.js`

- [ ] **Step 1: Add the 401 branch inside apiFetch's `!res.ok` handler**

In `apiFetch`, after the existing `payload`/`code`/`message` extraction (around line 60), add:

```js
if (res.status === 401 && code === "UNAUTH_NO_USER") {
  // Self-heal: clear stale activeUserId so App.jsx re-renders into onboarding.
  // Don't crash the caller — still throw so callers can react if they care.
  try { useSettings.getState().set({ activeUserId: null }); } catch {}
}
```

Place it directly before `throw new ApiError(...)`.

Update the comment on `activeUserHeader` (line 21-25) — remove the "backend defaults to local-user" wording:

```js
// activeUserHeader — reads settings.activeUserId and returns the
// X-Forgify-User-ID header pair. Returns {} when null; backend will then
// reject with 401 / UNAUTH_NO_USER for any user-scoped route.
//
// 读 settings.activeUserId 注 X-Forgify-User-ID;空时后端用户路由返 401。
function activeUserHeader() {
```

- [ ] **Step 2: Vite build sanity**

Run: `cd frontend && npm run build`
Expected: success.

- [ ] **Step 3: Commit**

```bash
git add frontend/src/api/client.js
git commit -m "feat(frontend): self-heal on 401 UNAUTH_NO_USER

apiFetch now clears settings.activeUserId when the backend rejects an
unknown / stale id. App.jsx self-heal effect (next task) reacts by
re-rendering into onboarding or auto-selecting the single remaining user."
```

---

### Task 4: App.jsx self-heal + auto-select + fresh-install detection

**Files:**
- Modify: `frontend/src/App.jsx`

- [ ] **Step 1: Read current App.jsx structure**

Note the existing `usersQ` query and `isFreshInstall` derivation around lines 63-72.

- [ ] **Step 2: Replace the fresh-install logic**

Replace lines 56-72 (the comment block + isFreshInstall calculation) with:

```jsx
  // /users query — drives both fresh-install detection and self-heal.
  //
  // /users 查询:fresh-install 检测 + activeUserId 自愈共用。
  const usersQ = useQuery({
    queryKey: qk.users(),
    queryFn: () => apiFetch("/users"),
    select: pickList,
  });
  const users = usersQ.data || [];

  // Self-heal: clear activeUserId if it's not in the user list.
  // Then auto-select when exactly one user exists, so single-user installs
  // don't see a picker after their localStorage gets wiped.
  //
  // 自愈:activeUserId 不在列表里就清;只剩一人时自动选上,
  // 避免单用户被打扰。
  useEffect(() => {
    if (usersQ.isLoading || usersQ.isError) return;
    const activeId = settings.activeUserId;
    if (activeId && !users.find((u) => u.id === activeId)) {
      settings.set({ activeUserId: null });
      return;
    }
    if (!activeId && users.length === 1) {
      settings.set({ activeUserId: users[0].id });
    }
  }, [usersQ.isLoading, usersQ.isError, users, settings.activeUserId]);

  // Fresh install: zero users in DB. Show onboarding.
  // Multi-user with no activeUserId: show picker (handled by AppShell).
  //
  // fresh install:0 个 user;走 onboarding。
  const isFreshInstall = !usersQ.isLoading && users.length === 0;
  const showOnboarding = forceShowOnboarding || isFreshInstall;
```

- [ ] **Step 3: Build**

Run: `cd frontend && npm run build`
Expected: success.

- [ ] **Step 4: Manual smoke (the dev server should already be hot-reloading)**

Open localhost:5173, confirm app still renders. (Real verification matrix happens in Task 26.)

- [ ] **Step 5: Commit**

```bash
git add frontend/src/App.jsx
git commit -m "feat(frontend): App.jsx self-heal + auto-select for activeUserId

- After /users resolves, validate settings.activeUserId; clear if absent.
- When exactly one user exists and activeUserId is null, auto-select it
  so single-user installs don't see a picker after a localStorage wipe.
- Fresh-install detection: users.length === 0 (no more username sniffing
  for 'default')."
```

---

### Task 5: SSEProvider 4-state machine

**Files:**
- Read first: `frontend/src/sse/SSEProvider.jsx`, `frontend/src/sse/shared.js`
- Modify: both

- [ ] **Step 1: Read both files end-to-end to understand current shape**

Run: `cat frontend/src/sse/shared.js frontend/src/sse/SSEProvider.jsx`

- [ ] **Step 2: Update shared.js — refuse to create EventSource when uid empty**

In `createSSE` (or equivalent factory), add at the top:

```js
export function createSSE(path, uid, handlers = {}) {
  if (!uid) return null;   // idle when no user; caller should not connect.
  // ...existing body that appends ?userID=uid and instantiates EventSource
}
```

Confirm all call sites null-check the returned value.

- [ ] **Step 3: Update SSEProvider — react to activeUserId changes + self-heal on close**

The current provider likely sets up EventSource in a useEffect keyed on `activeUserId`. Tweak it to:
- Build only when `activeUserId` non-null.
- On the EventSource `error` event where `readyState === EventSource.CLOSED`, if the captured uid still equals the current `activeUserId`, call `useSettings.getState().set({ activeUserId: null })` and `queryClient.invalidateQueries({ queryKey: qk.users() })`.

Concrete sketch (adapt to file shape):

```jsx
useEffect(() => {
  if (!activeUserId) return;             // idle state — nothing to do
  const es = createSSE("/eventlog", activeUserId, handlers);
  if (!es) return;
  const onErr = () => {
    if (es.readyState !== EventSource.CLOSED) return;
    // Connection dropped permanently — usually means backend rejected (401)
    // or restarted. Self-heal only if our id is still the one we connected
    // with; otherwise the activeUserId effect will rebuild anyway.
    const current = useSettings.getState().activeUserId;
    if (current === activeUserId) {
      useSettings.getState().set({ activeUserId: null });
      qc.invalidateQueries({ queryKey: qk.users() });
    }
  };
  es.addEventListener("error", onErr);
  return () => {
    es.removeEventListener("error", onErr);
    es.close();
  };
}, [activeUserId]);
```

Do the same for the other two SSE channels (notifications, forge) — match whatever pattern SSEProvider already uses.

- [ ] **Step 4: Build**

Run: `cd frontend && npm run build`
Expected: success.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/sse
git commit -m "feat(frontend): SSE 4-state machine — idle/connect/rebuild/self-heal

Never opens EventSource when activeUserId is null (would 401 instantly).
Rebuilds connection on activeUserId change. On unexpected close with the
same id still active, triggers self-heal so an expired session falls back
to onboarding instead of looking 'connected' but silent."
```

---

## Phase C — Background Tasks (still work with current local-user seed)

### Task 6: catalog polling iterates users

**Files:**
- Modify: `backend/internal/app/catalog/polling.go`
- Verify: `backend/internal/app/catalog/service.go` (find how `Service` wires `userResolver`)

- [ ] **Step 1: Read catalog Service struct**

Run: `grep -nE "type Service struct|userResolver|userSvc|userList" backend/internal/app/catalog/*.go`

- [ ] **Step 2: Add a UserLister port to the Service**

If `Service` doesn't already have a user-list dep, add one (smallest possible interface):

```go
// UserLister is the minimal users.Service port catalog needs for per-user polling.
//
// UserLister:catalog 做 per-user 轮询所需 users.Service 的最小端口。
type UserLister interface {
    List(ctx context.Context) ([]*userdomain.User, error)
}
```

And accept it via the constructor (`NewService(...)`). Wire it from `cmd/server/main.go`.

- [ ] **Step 3: Rewrite Refresh to iterate**

Replace lines 99-101 (the `if !ok { fallback to DefaultLocalUserID }` block) with a per-user loop. The new `Refresh` becomes the per-user worker, called by a new `RefreshAll`:

```go
// RefreshAll fans out Refresh over every user. The polling loop calls this.
// Zero users → no-op.
//
// RefreshAll 对每个 user 跑一次 Refresh;0 user 时静默 no-op。
func (s *Service) RefreshAll(ctx context.Context) {
    users, err := s.userList.List(ctx)
    if err != nil {
        s.log.Warn("catalog: list users failed; skipping tick", zap.Error(err))
        return
    }
    for _, u := range users {
        uctx := reqctxpkg.SetUserID(context.Background(), u.ID)
        if err := s.Refresh(uctx); err != nil {
            s.log.Warn("catalog: per-user refresh failed",
                zap.String("user_id", u.ID), zap.Error(err))
        }
    }
}
```

And remove the fallback block from `Refresh`:

```go
func (s *Service) Refresh(ctx context.Context) error {
    if _, ok := reqctxpkg.GetUserID(ctx); !ok {
        return fmt.Errorf("catalog.Refresh: %w", reqctxpkg.ErrMissingUserID)
    }
    // ... rest unchanged
}
```

Update `tryRefresh` to call `RefreshAll`:

```go
func (s *Service) tryRefresh(ctx context.Context) {
    if !s.busy.CompareAndSwap(false, true) {
        return
    }
    defer s.busy.Store(false)
    s.RefreshAll(ctx)
}
```

- [ ] **Step 4: Update HTTP refresh handler call site**

Find the handler that exposes `POST /catalog:refresh` (or similar) and ensure it calls `Refresh(ctx)` (single-user, current request) not `RefreshAll`. Should already be correct; just verify.

- [ ] **Step 5: Build + test**

```bash
cd backend && go build ./... && go test ./internal/app/catalog/...
```
Expected: success.

- [ ] **Step 6: Commit**

```bash
git add backend/internal/app/catalog backend/cmd/server/main.go
git commit -m "refactor(backend): catalog polling iterates users instead of magic id

Background polling no longer stamps reqctxpkg.DefaultLocalUserID. New
RefreshAll fans out per-user Refresh calls; the HTTP refresh handler
still hits the single-user Refresh path with the request's userID."
```

---

### Task 7: scheduler rehydrate iterates users

**Files:**
- Modify: `backend/internal/app/scheduler/rehydrate.go`
- Modify: `backend/cmd/server/main.go` (any boot call)

- [ ] **Step 1: Read the file**

Run: `cat backend/internal/app/scheduler/rehydrate.go`

- [ ] **Step 2: Apply the same iterate-users pattern**

If `RehydrateOnBoot` currently takes a `ctx` and stamps `DefaultLocalUserID`, rewrite:

```go
func (s *Service) RehydrateOnBoot(ctx context.Context) error {
    users, err := s.userList.List(ctx)
    if err != nil {
        return fmt.Errorf("scheduler.RehydrateOnBoot: list users: %w", err)
    }
    for _, u := range users {
        uctx := reqctxpkg.SetUserID(context.Background(), u.ID)
        if err := s.rehydrateForUser(uctx, u.ID); err != nil {
            s.log.Warn("scheduler: rehydrate failed for user",
                zap.String("user_id", u.ID), zap.Error(err))
        }
    }
    return nil
}
```

Wire `userList` through the constructor; update `cmd/server/main.go` boot wiring.

- [ ] **Step 3: Build + test**

```bash
cd backend && go build ./... && go test ./internal/app/scheduler/...
```

- [ ] **Step 4: Commit**

```bash
git add backend/internal/app/scheduler backend/cmd/server/main.go
git commit -m "refactor(backend): scheduler rehydrate iterates users on boot"
```

---

### Task 8: mcp/skill/trigger remove fallback

**Files:**
- Modify: `backend/internal/app/mcp/calltool.go`
- Modify: `backend/internal/app/skill/exec_log.go`
- Modify: `backend/internal/app/trigger/trigger.go`

- [ ] **Step 1: For each file, grep for DefaultLocalUserID**

Run: `grep -n DefaultLocalUserID backend/internal/app/mcp/calltool.go backend/internal/app/skill/exec_log.go backend/internal/app/trigger/trigger.go`

- [ ] **Step 2: Replace each fallback with an error return**

For each occurrence like:
```go
if _, ok := reqctxpkg.GetUserID(ctx); !ok {
    ctx = reqctxpkg.SetUserID(ctx, reqctxpkg.DefaultLocalUserID)
}
```

Change to:
```go
uid, err := reqctxpkg.RequireUserID(ctx)
if err != nil {
    return /*zero values,*/ fmt.Errorf("<pkg>.<Method>: %w", err)
}
_ = uid // use it where needed
```

Match the package prefix to S16 (`fmt.Errorf("<pkg>.<Method>: %w", err)`). Use the function's existing signature for the zero-value.

For HealthSnapshot in mcp: pass the userID from the caller context, don't fabricate one.

- [ ] **Step 3: Build**

```bash
cd backend && go build ./...
```

If callers break (the compiler will tell you), audit each caller — they MUST already have a user ctx (these methods are always called from request-scoped paths). If a caller doesn't, that's a latent bug surfaced by the change; fix it by threading ctx properly.

- [ ] **Step 4: Test**

```bash
cd backend && go test ./internal/app/mcp/... ./internal/app/skill/... ./internal/app/trigger/...
```

If tests fail because fixtures don't stamp a user, update them to use `reqctxpkg.SetUserID(ctx, "test-user")` (literal — these tests will be batched into Task 18).

- [ ] **Step 5: Commit**

```bash
git add backend/internal/app/mcp backend/internal/app/skill backend/internal/app/trigger
git commit -m "refactor(backend): remove DefaultLocalUserID fallback in mcp/skill/trigger

These code paths always run inside a request-scoped ctx — the fallback
was masking latent wiring bugs. Now they return ErrMissingUserID
(treated as 500 'wiring bug' per reqctxpkg semantics) if ctx lacks user."
```

---

## Phase D — Test Fixtures + Harness

### Task 9: Rename harness LocalCtx → SeedCtx

**Files:**
- Modify: `backend/test/harness/seed.go`

- [ ] **Step 1: Read current helper**

Run: `cat backend/test/harness/seed.go`

- [ ] **Step 2: Rename and rebehavior**

Old (likely):
```go
func (h *Harness) LocalCtx() context.Context {
    return reqctxpkg.SetUserID(context.Background(), reqctxpkg.DefaultLocalUserID)
}
```

New:
```go
// SeedCtx creates a test user (id="test-user") and returns a ctx stamped with it.
// Idempotent: re-uses the user on repeat calls.
//
// SeedCtx 创建测试用户 "test-user" 并返回带 user 的 ctx;可重复调用。
func (h *Harness) SeedCtx(t testing.TB) context.Context {
    t.Helper()
    if err := h.userSvc.EnsureExists(context.Background(), "test-user", "test"); err != nil {
        t.Fatalf("seed test user: %v", err)
    }
    return reqctxpkg.SetUserID(context.Background(), "test-user")
}

// LocalCtxAs returns a ctx stamped with the given user id and seeds it.
// Kept for tests that need a specific user id different from "test-user".
//
// LocalCtxAs 用指定 id 建用户并返 ctx;给需要自定义 id 的测试用。
func (h *Harness) LocalCtxAs(t testing.TB, id string) context.Context {
    t.Helper()
    if err := h.userSvc.EnsureExists(context.Background(), id, "test"); err != nil {
        t.Fatalf("seed user %s: %v", id, err)
    }
    return reqctxpkg.SetUserID(context.Background(), id)
}
```

You'll likely need a tiny `EnsureExists(ctx, id, username)` method on `userapp.Service` — add it (idempotent: if user exists, no-op).

- [ ] **Step 3: Build**

```bash
cd backend && go build ./...
```

- [ ] **Step 4: Commit**

```bash
git add backend/test/harness backend/internal/app/user
git commit -m "test(backend): harness SeedCtx replaces LocalCtx; explicit per-test seeding

LocalCtx() relied on EnsureDefault seeding 'local-user' at boot. New
SeedCtx(t) creates a test user explicitly via userSvc.EnsureExists, so
each test owns its fixture and we can delete EnsureDefault safely."
```

---

### Task 10: Update test/ pipeline files

**Files (one commit total):**
- Modify: `backend/test/document/document_test.go`
- Modify: `backend/test/document/workflow_attach_test.go`
- Modify: `backend/test/scheduler/approval_e2e_test.go`
- Modify: `backend/test/scheduler/scheduler_test.go`
- Modify: `backend/test/workflow/workflow_test.go`
- Modify: `backend/test/catalog/trinity_catalog_test.go`

- [ ] **Step 1: For each file, replace `th.LocalCtx()` with `th.SeedCtx(t)` and `th.LocalCtxAs("local-user")` with `th.LocalCtxAs(t, "test-user")`**

Use the Edit tool per file. Do NOT use sed (per CLAUDE.md tool discipline).

For literal `reqctxpkg.DefaultLocalUserID` usages, replace with the string `"test-user"`.

- [ ] **Step 2: Build**

```bash
cd backend && go build -tags=pipeline ./test/...
```

- [ ] **Step 3: Run unit subset that can run without env**

```bash
cd backend && make test-unit
```
Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add backend/test
git commit -m "test(backend): switch pipeline fixtures from local-user to seeded test-user"
```

---

### Task 11: Update internal/*/test files

**Files (one commit total):**
- Modify: `backend/internal/transport/httpapi/handlers/*_test.go` — all 10 that use `InjectUserID`. They'll continue to work because we'll keep `InjectUserID` as a test-only helper in Task 12, but their hardcoded user expectation may need updating (they assume `local-user`).
- Modify: `backend/internal/domain/document/document_test.go` (lines 41, 57, 88)
- Modify: `backend/internal/infra/store/document/document_test.go` (line 29 const)
- Modify: `backend/internal/app/document/document_test.go` (line 18 const)
- Modify: `backend/internal/app/tool/document/document_test.go` (line 33)

- [ ] **Step 1: Replace literal `"local-user"` with `"test-user"` in each file**

Use Edit per file.

- [ ] **Step 2: Replace `reqctxpkg.DefaultLocalUserID` with the string `"test-user"`** in any test file (not production code yet — that's the const deletion task).

- [ ] **Step 3: Build + test**

```bash
cd backend && make test-unit
```

- [ ] **Step 4: Commit**

```bash
git add backend/internal
git commit -m "test(backend): replace literal local-user fixtures with test-user"
```

---

## Phase E — Middleware Refactor (the breaking commit)

### Task 12: Split middleware into IdentifyUser + RequireUser

**Files:**
- Modify: `backend/internal/transport/httpapi/middleware/auth.go`

- [ ] **Step 1: Replace file body**

Full replacement (preserves `HeaderUserID`, `UserResolver`, `InjectUserID` test helper; adds new `IdentifyUser`/`RequireUser`):

```go
package middleware

import (
    "context"
    "net/http"

    errorsdomain "github.com/sunweilin/forgify/backend/internal/domain/errors"
    userdomain "github.com/sunweilin/forgify/backend/internal/domain/user"
    reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
    responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
)

// HeaderUserID is the per-request profile selector.
//
// HeaderUserID:per-request profile selector。
const HeaderUserID = "X-Forgify-User-ID"

// UserResolver is the minimal port IdentifyUser needs from userapp.Service.
//
// UserResolver:IdentifyUser 所需 userapp.Service 端口。
type UserResolver interface {
    Get(ctx context.Context, id string) (*userdomain.User, error)
}

// IdentifyUser reads X-Forgify-User-ID (or ?userID= for SSE) and stamps
// ctx with the validated user id. Unknown / missing id → ctx left empty;
// downstream RequireUser middleware will 401 if the route needs a user.
//
// IdentifyUser 读 X-Forgify-User-ID(SSE 用 ?userID=),校验后写入 ctx;
// 不识别/缺失 → ctx 不带 user,由 RequireUser 决定是否 401。
func IdentifyUser(resolver UserResolver) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            uid := r.Header.Get(HeaderUserID)
            if uid == "" {
                uid = r.URL.Query().Get("userID")
            }
            if uid != "" && resolver != nil {
                if _, err := resolver.Get(r.Context(), uid); err != nil {
                    uid = "" // unknown id → treat as missing
                }
            }
            ctx := r.Context()
            if uid != "" {
                ctx = reqctxpkg.SetUserID(ctx, uid)
            }
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}

// RequireUser rejects requests whose ctx has no user id with 401 / UNAUTH_NO_USER.
// Mount on every user-scoped route. Skip on /users (CRUD), /health (liveness).
//
// RequireUser:ctx 无 user 时 401;挂在所有用户路由上,
// /users CRUD 与 /health 例外。
func RequireUser(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if _, ok := reqctxpkg.GetUserID(r.Context()); !ok {
            responsehttpapi.WriteError(w, errorsdomain.ErrUnauthorizedNoUser)
            return
        }
        next.ServeHTTP(w, r)
    })
}

// InjectUserID is a test-only middleware that stamps a fixed "test-user" id
// (and creates ctx for downstream handlers in handler tests). Production
// wiring must use IdentifyUser + RequireUser.
//
// InjectUserID:test-only,固定塞 "test-user";生产用 IdentifyUser+RequireUser。
func InjectUserID(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        ctx := reqctxpkg.SetUserID(r.Context(), "test-user")
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

// InjectUserIDWith preserved as an alias for legacy callers; deprecated.
// Tests should switch to using IdentifyUser with a fake resolver if they
// want the production middleware behavior.
//
// InjectUserIDWith:legacy 别名,新代码不要用。
func InjectUserIDWith(_ UserResolver) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler { return InjectUserID(next) }
}
```

(Adjust the response-helper import path to match the actual project — likely `responsehttpapi` or similar; verify via `grep -n WriteError backend/internal/transport/httpapi/...`.)

- [ ] **Step 2: Verify responsehttpapi.WriteError exists**

Run: `grep -rn "func WriteError" backend/internal/transport/httpapi/`
If it doesn't exist with the right signature, use the existing error-writing helper (likely `responsehttpapi.Error(w, err)` or similar). Match the project's pattern.

- [ ] **Step 3: Build**

```bash
cd backend && go build ./...
```

If build fails because handler tests' `InjectUserID(mux)` usages no longer compile (signature changed) — they shouldn't, since the new `InjectUserID(next http.Handler) http.Handler` is the same shape.

- [ ] **Step 4: Run middleware tests**

```bash
cd backend && go test ./internal/transport/httpapi/middleware/...
```

Likely fails — these tests assert the old fallback behavior. We'll rewrite them in Task 13.

- [ ] **Step 5: Commit (even with the test failure noted)**

```bash
git add backend/internal/transport/httpapi/middleware/auth.go
git commit -m "refactor(backend): split user middleware into IdentifyUser + RequireUser

Replaces the 4-tier fallback chain (header → query → first-user → local-user)
with strict semantics: unknown id → ctx without user → RequireUser 401s.
InjectUserID kept as a test helper that stamps a fixed 'test-user'.

Tests for the old behavior will fail; rewritten in next commit."
```

---

### Task 13: Rewrite auth_test.go for new semantics

**Files:**
- Modify: `backend/internal/transport/httpapi/middleware/auth_test.go`

- [ ] **Step 1: Read current tests**

Run: `cat backend/internal/transport/httpapi/middleware/auth_test.go`

- [ ] **Step 2: Replace with tests for the new semantics**

Drop fallback-chain assertions. Add cases:

```go
func TestIdentifyUser_HeaderPresent_StampsCtx(t *testing.T) {
    // valid header → ctx has uid
}
func TestIdentifyUser_HeaderMissing_LeavesCtxEmpty(t *testing.T) {
    // no header → ctx has no user
}
func TestIdentifyUser_UnknownHeader_LeavesCtxEmpty(t *testing.T) {
    // header refers to non-existent user → ctx has no user (no demote)
}
func TestIdentifyUser_QueryFallback_ForSSE(t *testing.T) {
    // ?userID= query honored when header missing
}
func TestRequireUser_NoCtxUser_Returns401(t *testing.T) {
    // RequireUser without IdentifyUser → 401 with UNAUTH_NO_USER code
}
func TestRequireUser_WithCtxUser_PassesThrough(t *testing.T) {
    // IdentifyUser + RequireUser + valid header → 200
}
```

Use the existing test helper `httptest.NewRecorder()` etc. Use a fake `UserResolver` (the test will need a tiny in-line struct that implements `Get(ctx, id) (*userdomain.User, error)`).

- [ ] **Step 3: Run tests**

```bash
cd backend && go test ./internal/transport/httpapi/middleware/...
```
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add backend/internal/transport/httpapi/middleware/auth_test.go
git commit -m "test(backend): rewrite auth middleware tests for IdentifyUser + RequireUser"
```

---

### Task 14: Apply RequireUser in router; exempt /users

**Files:**
- Modify: `backend/internal/transport/httpapi/router.go` (or wherever the chi router is wired)

- [ ] **Step 1: Find the router file**

Run: `grep -rn "IdentifyUser\|InjectUserID\|chi.Router\|Mount" backend/internal/transport/httpapi/ backend/cmd/server/ | head`

- [ ] **Step 2: Wire the two middlewares**

Pattern (adapt to actual chi structure):

```go
r := chi.NewRouter()
r.Use(middlewarehttpapi.IdentifyUser(userResolver))

// User CRUD — IdentifyUser stamps if header is valid; RequireUser is NOT applied
// because onboarding must call POST /users before any user exists.
r.Route("/users", func(r chi.Router) {
    r.Get("/", userHandler.List)
    r.Post("/", userHandler.Create)
    // ...
})

// Everything else requires a valid user.
r.Group(func(r chi.Router) {
    r.Use(middlewarehttpapi.RequireUser)
    r.Mount("/conversations", convRoutes)
    r.Mount("/documents", docRoutes)
    // ...all the rest...
})
```

Confirm SSE routes (`/eventlog`, `/notifications`, `/forge`) live under the `Use(RequireUser)` block.

- [ ] **Step 3: Build**

```bash
cd backend && go build ./...
```

- [ ] **Step 4: Smoke run**

```bash
cd backend && go run ./cmd/server &
SERVER_PID=$!
sleep 1
# unauth call should 401
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/api/v1/conversations
# /users should work without header
curl -s http://localhost:8080/api/v1/users
kill $SERVER_PID
```

Expected: 401, then `{"data":[...]}` (possibly with the legacy local-user row).

- [ ] **Step 5: Commit**

```bash
git add backend/internal/transport/httpapi
git commit -m "feat(backend): wire IdentifyUser + RequireUser; exempt /users from RequireUser

Pre-onboarding clients can hit /users (list / create) without a header;
every other route now 401s on missing or unknown user id."
```

---

## Phase F — Delete Dead Code

### Task 15: Delete EnsureDefault + DefaultLocalUserID

**Files:**
- Modify: `backend/internal/app/user/user.go` (delete lines 99-128 = `EnsureDefault`)
- Modify: `backend/internal/app/user/user_test.go` (delete `TestEnsureDefault`)
- Modify: `backend/cmd/server/main.go` (delete `userService.EnsureDefault(...)` call)
- Modify: `backend/internal/pkg/reqctx/reqctx.go` (delete `DefaultLocalUserID` const, lines 21-24)

- [ ] **Step 1: Grep one more time for any straggler refs**

```bash
grep -rn "DefaultLocalUserID\|EnsureDefault" backend/
```
Expected: only the lines we're about to delete. If anything else surfaces, fix it first (likely a test fixture missed in Task 10/11).

- [ ] **Step 2: Make the four deletions**

Use Edit for each. Confirm the const-deletion block leaves the import for `errors` intact (it's still used by `ErrMissingUserID`).

- [ ] **Step 3: Build + test**

```bash
cd backend && go build ./... && make test-unit && staticcheck ./...
```
Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add backend/internal/app/user backend/cmd/server/main.go backend/internal/pkg/reqctx
git commit -m "refactor(backend): delete EnsureDefault + DefaultLocalUserID

The magic-id era is over. Fresh installs start with zero users; onboarding
creates the first user. Background tasks iterate; middleware 401s on
unknown id."
```

---

## Phase G — Docs

### Task 16: CLAUDE.md S15 prefix table

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Find S15 line**

```bash
grep -n "S15" CLAUDE.md
```

- [ ] **Step 2: Add `u_` to the prefix list**

In the prefix enumeration, add `u_` user before the existing prefixes.

- [ ] **Step 3: Commit (later — bundle with other docs)**

---

### Task 17: Update service design docs

**Files:**
- Modify: `documents/version-1.2/backend-design.md`
- Modify: `documents/version-1.2/service-design-documents/user.md`
- Modify: `documents/version-1.2/service-design-documents/catalog.md`
- Modify: `documents/version-1.2/service-design-documents/trigger.md`

- [ ] **Step 1: For each file, grep for `local-user` / `DefaultLocalUserID` / `EnsureDefault`**

```bash
grep -nE "local-user|DefaultLocalUserID|EnsureDefault" documents/version-1.2/
```

- [ ] **Step 2: Update each hit**

Replace "缺 header → 走默认 local-user" wording with "缺 header → 401 / UNAUTH_NO_USER; 前端 self-heal 触发 onboarding".

For `user.md`: remove the EnsureDefault section; add a short "no auto-seed; onboarding creates first user; backgound tasks iterate" paragraph.

For `catalog.md` / `trigger.md`: update polling description to "per-user iteration; zero-user no-op".

- [ ] **Step 3: Commit (with Task 16)**

```bash
git add CLAUDE.md documents/version-1.2
git commit -m "docs: update user-identity semantics across CLAUDE + service designs

Reflects the no-magic-id middleware (IdentifyUser + RequireUser), the
absence of EnsureDefault, and the per-user iteration model for background
tasks. Adds u_ prefix to S15 ID table."
```

---

### Task 18: Update frontend-prd + progress-record

**Files:**
- Modify: `documents/version-1.2/frontend-prd.md` (§16 boilerplate-bug log + §17 endpoints + §19 multi-user)
- Modify: `documents/version-1.2/progress-record.md` (add dev log entry)

- [ ] **Step 1: PRD §16 — add a bug entry**

Append a row to the §16 table:

```markdown
| activeUserId 引用已删除用户时后端日志噪音 + 静默降级 | DB wipe / 浏览器换 profile 后 localStorage 里的 user id 不存在,后端 silently fallback 到首个 user;请求看着成功但 attribute 错号 | 后端拆 IdentifyUser+RequireUser,unknown id 返 401/UNAUTH_NO_USER;前端 apiFetch 401 handler + App.jsx self-heal effect 清 activeUserId,users.length===1 时 auto-select。已修。|
```

- [ ] **Step 2: PRD §17 — note the new error code**

Add `UNAUTH_NO_USER` to the list of common error codes if a list exists.

- [ ] **Step 3: PRD §19 — clarify multi-user flow**

Describe: fresh install → 0 users → Onboarding → first user → activeUserId set. Multi-user picker only when ≥2 users and activeUserId is null.

- [ ] **Step 4: progress-record dev log**

Append (S19: 1-2 sentences, ~30-100 汉字):

```markdown
- 2026-05-24 [user-identity] 砍掉 local-user 魔法字符串:middleware 拆 IdentifyUser+RequireUser
  严格 401;后台任务 iterate users;前端 self-heal stale activeUserId,users.length===1 时 auto-select。
  16+ 测试 fixture 改用 SeedCtx;EnsureDefault 删除。规范见 spec 2026-05-24-user-identity-cleanup.md。
```

- [ ] **Step 5: Commit**

```bash
git add documents/version-1.2/frontend-prd.md documents/version-1.2/progress-record.md
git commit -m "docs: log user-identity cleanup in frontend-prd §16/§17/§19 + progress"
```

---

## Phase H — Verification

### Task 19: All-green unit + static checks

- [ ] **Step 1: Run unit tests**

```bash
cd backend && make test-unit
```
Expected: ~170 tests green.

- [ ] **Step 2: Run staticcheck**

```bash
cd backend && staticcheck ./...
```
Expected: clean.

- [ ] **Step 3: Run pipeline tests (env-gated; OK to skip if env missing)**

```bash
cd backend && make test-pipeline
```
Expected: green OR clean skip with "DeepSeek key missing" / similar.

- [ ] **Step 4: Frontend build**

```bash
cd frontend && npm run build
```
Expected: success.

- [ ] **Step 5: If any test fails, fix in-place and re-run before proceeding**

---

### Task 20: Manual verification matrix

Run each scenario from spec §8 in order. Each is a checkbox. After each, take a screenshot or log the outcome.

- [ ] **Scenario 1: Fresh install**

```bash
rm ~/.forgify/forgify.db
make dev
# Open browser → onboarding should render
# Verify: backend log shows no "record not found" noise
# Verify: GET /api/v1/conversations returns 401 if you curl it
# POST /api/v1/users with a body succeeds
```

- [ ] **Scenario 2: The original bug — DB wipe + localStorage kept**

```bash
# With dev running, open browser → onboard a user → use the app
# Stop dev. rm ~/.forgify/forgify.db. Restart dev.
# Reload browser (don't clear localStorage)
# Expect: within one render, onboarding appears (activeUserId cleared by self-heal)
# Expect: backend log clean (no flood)
```

- [ ] **Scenario 3: Single onboarded user, normal use** — works as before; no picker.

- [ ] **Scenario 4: Two users; switch then delete the non-active** — no crash.

- [ ] **Scenario 5: Two users; delete the active** — self-heal clears activeUserId; auto-select picks the other.

- [ ] **Scenario 6: Background catalog polling on 0 users** — boot fresh; tail logs for 60s; no errors, no work, no spam.

- [ ] **Scenario 7: Background polling on 2 users** — manual: POST /users twice; tail logs through one tick; both refreshed.

- [ ] **Scenario 8: SSE with stale ?userID=** —
```bash
curl -N "http://localhost:8080/api/v1/eventlog?userID=u_stale"
# Expect: 401 UNAUTH_NO_USER response, then connection closed
```

- [ ] **Scenario 9: SSE reconnect on activeUserId change** — browser devtools network tab; switch user via picker; observe old EventSource close + new open.

- [ ] **Scenario 10/11/12: covered by Task 19**

- [ ] **Step Final: Commit the verification result**

If any scenario fails, file a follow-up bug task; do not roll back unless the failure is catastrophic.

---

## Done Criteria

All boxes ticked. CI clean. Spec §8 matrix verified. Docs updated.

---

## Self-Review

Performed at write time:
- Every spec section §1–§11 maps to at least one task: identified gaps covered above.
- No "TBD" / "TODO" left in steps.
- Type consistency: `IdentifyUser`, `RequireUser`, `RefreshAll`, `SeedCtx`, `LocalCtxAs` names used uniformly throughout.
- Frontend names: `useSettings.getState()`, `apiFetch`, `useUsers` (existing), `qk.users()` (existing) — match current frontend conventions.
