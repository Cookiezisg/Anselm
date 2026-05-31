# Doc Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform Forgify's document chaos into an enterprise-grade governance system with typed docs, lifecycle states, ADRs, and automated freshness enforcement.

**Architecture:** Flatten `documents/version-1.2/` into `documents/` root (version history now lives in ADRs + git). Introduce 6 doc types (concept/reference/how-to/decision/log/working) each with frontmatter + review-due. Automate via a Go `doc-lint` tool integrated into `make verify`.

**Tech Stack:** Markdown frontmatter (YAML), Go tooling (`backend/cmd/doc-lint/`), Makefile targets, existing `make verify` pipeline.

---

## File Map

### New directories (create)
- `documents/concepts/` — architecture explanations, stable
- `documents/references/backend/domains/` — per-domain reference (from `service-design-documents/`)
- `documents/references/backend/` — contracts (api/db/error-codes/events)
- `documents/references/frontend/` — FSD contracts
- `documents/decisions/` — ADRs, immutable
- `documents/how-to/` — operational playbooks
- `documents/working/` — in-progress research
- `documents/archive/` — dead docs, read-only

### New files (create)
- `documents/INDEX.md` — AI session navigation hub
- `documents/GOVERNANCE.md` — governance rules
- `documents/decisions/template.md` — ADR template
- `documents/decisions/README.md` — decision index
- `documents/decisions/001` through `015` — 15 historical ADRs
- `backend/cmd/doc-lint/main.go` — lint tool (~250 lines)
- `backend/cmd/doc-lint/frontmatter.go` — YAML parser

### Files to move (git mv)
- `documents/version-1.2/backend-design.md` → `documents/concepts/architecture.md`
- `documents/version-1.2/frontend-design.md` → `documents/concepts/frontend-architecture.md`
- `documents/version-1.2/frontend-prd.md` → `documents/concepts/frontend-prd.md`
- `documents/version-1.2/progress-record.md` → `documents/references/changelog.md`
- `documents/version-1.2/service-design-documents/*.md` → `documents/references/backend/domains/`
- `documents/version-1.2/service-contract-documents/api-design.md` → `documents/references/backend/api.md`
- `documents/version-1.2/service-contract-documents/database-design.md` → `documents/references/backend/database.md`
- `documents/version-1.2/service-contract-documents/error-codes.md` → `documents/references/backend/error-codes.md`
- `documents/version-1.2/service-contract-documents/events-design.md` → `documents/references/backend/events.md`
- `documents/version-1.2/frontend-contract-documents/*` → `documents/references/frontend/`
- `documents/version-1.2/adhoc-topic-documents/workflow-revamp/` → `documents/working/workflow-revamp/`
- `documents/version-1.2/adhoc-topic-documents/llm-providers/` → `documents/working/llm-providers/`
- `documents/version-1.2/adhoc-topic-documents/testend/` → `documents/working/testend/`
- All remaining version-1.0, version-1.1, version-1.2/adhoc → `documents/archive/`

### Files to update
- `CLAUDE.md` — all document path references
- `Makefile` — add `lint-docs`, `doc-matrix` targets; add to `verify`

---

## Task 1: Archive Dead Documents

**Files:**
- Create: `documents/archive/`
- Move: `documents/version-1.0/` → `documents/archive/version-1.0/`
- Move: `documents/version-1.1/` → `documents/archive/version-1.1/`
- Move: `documents/version-1.2/adhoc-topic-documents/audit/` → `documents/archive/audit-2026-05/`
- Move: `documents/version-1.2/adhoc-topic-documents/research-archive/` → `documents/archive/`

- [ ] **Step 1: Create archive directory and move dead versions**

```bash
cd /path/to/Forgify
mkdir -p documents/archive
git mv documents/version-1.0 documents/archive/version-1.0
git mv documents/version-1.1 documents/archive/version-1.1
```

- [ ] **Step 2: Archive completed adhoc directories**

```bash
git mv documents/version-1.2/adhoc-topic-documents/audit documents/archive/audit-2026-05
git mv documents/version-1.2/adhoc-topic-documents/research-archive documents/archive/research-archive
git mv documents/version-1.2/adhoc-topic-documents/final_sweep documents/archive/final-sweep-2026-05
git mv documents/version-1.2/adhoc-topic-documents/live-test-v1 documents/archive/live-test-v1
git mv documents/version-1.2/adhoc-topic-documents/live-test-v2 documents/archive/live-test-v2
git mv documents/version-1.2/adhoc-topic-documents/forge_redesign documents/archive/forge-redesign-2026-05
git mv documents/version-1.2/adhoc-topic-documents/eventlog-redesign documents/archive/eventlog-redesign-2026-05
git mv documents/version-1.2/adhoc-topic-documents/refactor-chat-infra documents/archive/refactor-chat-infra-2026-05
git mv documents/version-1.2/adhoc-topic-documents/limits-optimization documents/archive/limits-optimization-2026-05
git mv documents/version-1.2/adhoc-topic-documents/token-iteration documents/archive/token-iteration-2026-05
git mv documents/version-1.2/adhoc-topic-documents/sandbox-iteration-documents documents/archive/sandbox-iteration-2026-05
git mv documents/version-1.2/adhoc-topic-documents/test-pipeline-iteration-documents documents/archive/test-pipeline-iteration-2026-05
git mv documents/version-1.2/adhoc-topic-documents/claude-code-research-documents documents/archive/claude-code-research-2026-05
git mv documents/version-1.2/adhoc-topic-documents/desktop-packaging-notes documents/archive/desktop-packaging-notes-2026-05
```

- [ ] **Step 3: Verify archive structure**

```bash
ls documents/archive/
```

Expected output includes: `version-1.0/  version-1.1/  audit-2026-05/  forge-redesign-2026-05/` etc.

- [ ] **Step 4: Commit**

```bash
git add -A documents/archive/ documents/version-1.0 documents/version-1.1 documents/version-1.2/adhoc-topic-documents/
git commit -m "docs: archive dead documents (v1.0, v1.1, completed adhoc)"
```

---

## Task 2: Create New Directory Skeleton + Move Active Docs

**Files:**
- Create: `documents/concepts/`, `documents/references/backend/domains/`, `documents/references/backend/`, `documents/references/frontend/`, `documents/decisions/`, `documents/how-to/`, `documents/working/`

- [ ] **Step 1: Create directory skeleton**

```bash
mkdir -p documents/concepts
mkdir -p documents/references/backend/domains
mkdir -p documents/references/frontend
mkdir -p documents/decisions
mkdir -p documents/how-to
mkdir -p documents/working
```

- [ ] **Step 2: Move concept docs**

```bash
git mv documents/version-1.2/backend-design.md documents/concepts/architecture.md
git mv documents/version-1.2/frontend-design.md documents/concepts/frontend-architecture.md
git mv documents/version-1.2/frontend-prd.md documents/concepts/frontend-prd.md
```

- [ ] **Step 3: Move backend reference docs**

```bash
git mv documents/version-1.2/service-contract-documents/api-design.md documents/references/backend/api.md
git mv documents/version-1.2/service-contract-documents/database-design.md documents/references/backend/database.md
git mv documents/version-1.2/service-contract-documents/error-codes.md documents/references/backend/error-codes.md
git mv documents/version-1.2/service-contract-documents/events-design.md documents/references/backend/events.md
```

- [ ] **Step 4: Move backend domain design docs**

```bash
for f in documents/version-1.2/service-design-documents/*.md; do
  git mv "$f" "documents/references/backend/domains/$(basename $f)"
done
```

- [ ] **Step 5: Move frontend reference docs**

```bash
git mv documents/version-1.2/frontend-contract-documents/fsd-layers.md documents/references/frontend/fsd-layers.md
git mv documents/version-1.2/frontend-contract-documents/entity-types.md documents/references/frontend/entity-types.md
git mv documents/version-1.2/frontend-contract-documents/cross-cutting.md documents/references/frontend/cross-cutting.md
```

- [ ] **Step 6: Move progress log**

```bash
git mv documents/version-1.2/progress-record.md documents/references/changelog.md
```

- [ ] **Step 7: Move active working docs**

```bash
git mv documents/version-1.2/adhoc-topic-documents/workflow-revamp documents/working/workflow-revamp
git mv documents/version-1.2/adhoc-topic-documents/llm-providers documents/working/llm-providers
git mv documents/version-1.2/adhoc-topic-documents/testend documents/working/testend
```

- [ ] **Step 8: Move frontend design docs**

```bash
mkdir -p documents/references/frontend/slices
for f in documents/version-1.2/frontend-design-documents/*.md; do
  git mv "$f" "documents/references/frontend/slices/$(basename $f)"
done
```

- [ ] **Step 9: Archive remaining version-1.2 skeleton**

```bash
# Move the now-empty or near-empty version-1.2 to archive
git mv documents/version-1.2 documents/archive/version-1.2-skeleton
```

- [ ] **Step 10: Verify structure**

```bash
find documents -maxdepth 2 -type d | sort
```

Expected:
```
documents/archive
documents/concepts
documents/decisions
documents/how-to
documents/references
documents/references/backend
documents/references/backend/domains
documents/references/frontend
documents/references/frontend/slices
documents/working
documents/working/llm-providers
documents/working/testend
documents/working/workflow-revamp
```

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "docs: restructure into concepts/references/decisions/working/archive"
```

---

## Task 3: Write GOVERNANCE.md

**Files:**
- Create: `documents/GOVERNANCE.md`

- [ ] **Step 1: Write GOVERNANCE.md**

Create `documents/GOVERNANCE.md` with this content:

```markdown
# Forgify Documentation Governance

**This document defines how all documents in this repository are managed.**
Last reviewed: 2026-05-31

---

## Document Types

Every document must declare one type in its frontmatter. Type determines write rules, review cadence, and termination protocol.

| Type | Purpose | Mutability | Review Cadence |
|---|---|---|---|
| `concept` | Architecture explanations, design rationale | Evolves with system | Quarterly |
| `reference` | Specs that must match code exactly | Must sync on every code change | Per code change |
| `how-to` | Step-by-step operational guides | Updated when process changes | Semi-annual |
| `decision` | ADRs — why we chose X over Y | **Immutable** (supersede, never edit) | Never |
| `log` | Time-ordered progress journal | Append-only | Never |
| `working` | In-progress research, temporary | Active until landed | 90-day max |

---

## Frontmatter Standard

Every document except `archive/` must have this frontmatter:

```yaml
---
id: DOC-NNN          # unique, assigned at creation
type: concept        # one of the 6 types above
status: active       # draft | active | superseded | deprecated | archived
owner: @weilin
created: YYYY-MM-DD
reviewed: YYYY-MM-DD
review-due: YYYY-MM-DD
audience: [human, ai]  # who reads this
superseded-by:       # fill when status → superseded
landed-into:         # working docs only: fill when conclusions extracted
---
```

---

## Directory Map

```
documents/
├── INDEX.md              ← AI session entry point (≤50 lines)
├── GOVERNANCE.md         ← this file
├── concepts/             ← stable architecture explanations
├── references/           ← must-stay-in-sync-with-code specs
│   ├── backend/
│   │   ├── api.md
│   │   ├── database.md
│   │   ├── error-codes.md
│   │   ├── events.md
│   │   ├── changelog.md
│   │   └── domains/
│   └── frontend/
│       ├── fsd-layers.md
│       ├── entity-types.md
│       ├── cross-cutting.md
│       └── slices/
├── decisions/            ← ADRs, append-only
├── how-to/               ← operational playbooks
├── working/              ← in-progress, max 90 days
└── archive/              ← read-only graveyard
```

---

## Document Lifecycle

```
Draft → Active → Superseded → Archived
              └→ Deprecated → Archived
```

- **Draft**: Being written. Not authoritative.
- **Active**: Authoritative. The single source of truth.
- **Superseded**: Replaced by a newer document. Link via `superseded-by`.
- **Deprecated**: Intentionally phased out. Will be archived.
- **Archived**: Read-only. Cannot be modified. Lives in `archive/`.

---

## Working Document Protocol

Working documents have a maximum 90-day lifespan. On completion:

1. Extract conclusions into the appropriate `concepts/` or `references/` doc
2. Fill `landed-into:` frontmatter field with the target doc path
3. Move the file to `archive/`
4. Update `INDEX.md` if it referenced the working doc

Working docs older than 90 days with empty `landed-into` are flagged by `make lint-docs`.

---

## Update Triggers

| Code change | Required doc update |
|---|---|
| New/changed API endpoint | `references/backend/api.md` + domain doc |
| New/changed DB table or column | `references/backend/database.md` + domain doc |
| New/changed error code | `references/backend/error-codes.md` + domain doc |
| New/changed SSE event | `references/backend/events.md` + domain doc |
| Architecture decision | New ADR in `decisions/` |
| Phase completed | `concepts/architecture.md` phase table + `references/changelog.md` |
| Frontend entity type changed | `references/frontend/entity-types.md` |
| FSD layer rules changed | `references/frontend/fsd-layers.md` + `CLAUDE.md §FSD` |

---

## Authority Hierarchy

When docs conflict, higher wins:

```
CLAUDE.md > documents/references/ > documents/concepts/ > documents/working/ > documents/archive/
```

---

## Quality Gates

`make lint-docs` runs as part of `make verify` and enforces:

1. All non-archive `.md` files have valid frontmatter
2. All required frontmatter fields are present
3. No `review-due` date is in the past (warns, doesn't fail)
4. No `working/` document is older than 90 days without `landed-into`
5. No `decisions/` document has been modified after creation (git blame check)
6. `INDEX.md` is ≤ 50 lines
```

- [ ] **Step 2: Commit**

```bash
git add documents/GOVERNANCE.md
git commit -m "docs: add GOVERNANCE.md with doc types, lifecycle, and quality gates"
```

---

## Task 4: Write INDEX.md

**Files:**
- Create: `documents/INDEX.md`

- [ ] **Step 1: Write INDEX.md**

Create `documents/INDEX.md` with this content:

```markdown
# Forgify Documentation Index

> AI session entry point. Read this first, then follow links. ≤50 lines enforced.

---

## What Are You Looking For?

| Question | Go here |
|---|---|
| System architecture, phase roadmap | `concepts/architecture.md` |
| Frontend PRD + UX requirements | `concepts/frontend-prd.md` |
| Frontend architecture (FSD layers) | `concepts/frontend-architecture.md` |
| Backend code rules (S/T series) | `CLAUDE.md` |
| Specific domain design | `references/backend/domains/<domain>.md` |
| API contracts (endpoints, payloads) | `references/backend/api.md` |
| DB schema | `references/backend/database.md` |
| Error codes | `references/backend/error-codes.md` |
| SSE event protocols | `references/backend/events.md` |
| FSD layer boundaries + slice list | `references/frontend/fsd-layers.md` |
| Entity TS types ↔ API mapping | `references/frontend/entity-types.md` |
| DIP / errorMap / SSE / queryKeys | `references/frontend/cross-cutting.md` |
| Frontend slice design | `references/frontend/slices/<slice>.md` |
| Recent progress + dev log | `references/changelog.md` |
| Why we made a specific decision | `decisions/README.md` |
| How to do X operationally | `how-to/` |
| Active research in progress | `working/` |

---

## Authority Hierarchy

`CLAUDE.md` > `references/` > `concepts/` > `working/` > `archive/`

Conflicts: higher authority wins. Stale = bug, fix immediately.

---

## Active Working Docs

| Topic | Status | Started |
|---|---|---|
| workflow-revamp | active | 2026-05-20 |
| llm-providers | landed (R1-R5 shipped) | 2026-05-25 |
| testend | landed (V3 shipped) | 2026-05-27 |
```

- [ ] **Step 2: Count lines to verify ≤ 50**

```bash
wc -l documents/INDEX.md
```

Expected: ≤ 50

- [ ] **Step 3: Commit**

```bash
git add documents/INDEX.md
git commit -m "docs: add INDEX.md as AI session navigation hub"
```

---

## Task 5: ADR Template + Decisions Index

**Files:**
- Create: `documents/decisions/template.md`
- Create: `documents/decisions/README.md`

- [ ] **Step 1: Write ADR template**

Create `documents/decisions/template.md`:

```markdown
---
id: ADR-NNN
title: <short decision title>
status: proposed     # proposed | accepted | rejected | superseded | deprecated
date: YYYY-MM-DD
supersedes:          # ADR-NNN if this replaces a prior decision
superseded-by:       # fill when this is replaced
---

# ADR-NNN: <Title>

## Status

accepted — YYYY-MM-DD

## Context

What situation forced this decision? What constraints existed? What alternatives were on the table?

## Decision

What we decided, stated clearly. One paragraph max.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Option A | ... |
| Option B | ... |

## Consequences

**Positive:**
- ...

**Negative / Trade-offs:**
- ...

**Neutral:**
- ...
```

- [ ] **Step 2: Write decisions/README.md (decision index)**

Create `documents/decisions/README.md`:

```markdown
# Architecture Decision Records

Decisions are immutable. To change a decision, write a new ADR and set `supersedes: ADR-NNN`.

---

## Foundational (001–005)

| ADR | Title | Date | Status |
|---|---|---|---|
| [001](001-local-first-no-saas.md) | Local-first, no SaaS | 2026-04-22 | accepted |
| [002](002-clean-arch-4-layers.md) | Clean Architecture 4 layers | 2026-04-22 | accepted |
| [003](003-pure-go-sqlite.md) | Pure Go SQLite (modernc) | 2026-04-23 | accepted |
| [004](004-wails-http-reuse.md) | Wails shell, reuse HTTP API | 2026-05-12 | accepted |
| [005](005-three-sse-streams-cap.md) | Three SSE streams, permanent cap | 2026-05-12 | accepted |

## LLM Infrastructure (006–009)

| ADR | Title | Date | Status |
|---|---|---|---|
| [006](006-own-llm-client-no-eino.md) | Own LLM client, eject Eino | 2026-05-12 | accepted |
| [007](007-per-user-sse.md) | Per-user SSE subscriptions | 2026-05-12 | accepted |
| [008](008-no-shared-openai-compat.md) | No shared OpenAI-compat provider (R5) | 2026-05-30 | accepted |
| [009](009-native-gemini-api.md) | Native Gemini generateContent, no shim | 2026-05-30 | accepted |

## Workflow Engine (010–012)

| ADR | Title | Date | Status |
|---|---|---|---|
| [010](010-durable-execution.md) | Durable execution via journal+replay | 2026-05-31 | accepted |
| [011](011-cel-conditions.md) | CEL for workflow conditions | 2026-05-31 | accepted |
| [012](012-no-checkpoint-undo.md) | No Checkpoint/Undo feature | 2026-05-27 | accepted |

## Platform & Capabilities (013–015)

| ADR | Title | Date | Status |
|---|---|---|---|
| [013](013-modelcaps-replaces-modelmeta.md) | modelcaps replaces modelmeta | 2026-05-30 | accepted |
| [014](014-sandbox-v2-embedded-mise.md) | Sandbox v2 with embedded mise binary | 2026-05-13 | accepted |
| [015](015-fsd-6-layer-frontend.md) | FSD 6-layer architecture for frontend | 2026-05-27 | accepted |
```

- [ ] **Step 3: Commit**

```bash
git add documents/decisions/
git commit -m "docs: add ADR template and decisions index"
```

---

## Task 6: Write ADRs 001–005 (Foundational)

**Files:**
- Create: `documents/decisions/001-local-first-no-saas.md`
- Create: `documents/decisions/002-clean-arch-4-layers.md`
- Create: `documents/decisions/003-pure-go-sqlite.md`
- Create: `documents/decisions/004-wails-http-reuse.md`
- Create: `documents/decisions/005-three-sse-streams-cap.md`

- [ ] **Step 1: Write ADR-001**

Create `documents/decisions/001-local-first-no-saas.md`:

```markdown
---
id: ADR-001
title: Local-first, no SaaS
status: accepted
date: 2026-04-22
---

# ADR-001: Local-first, no SaaS

## Status

accepted — 2026-04-22

## Context

Forgify is an agentic workflow platform. The build-or-SaaS fork was the first major decision: build a hosted multi-tenant service, or a local desktop app. SaaS would mean auth, billing, multi-tenancy, data residency concerns, and infrastructure ops from day one.

## Decision

Local-first desktop app (Wails). Single user, single machine. No SaaS, no multi-tenancy.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| SaaS / cloud-hosted | Auth, billing, infra, compliance overhead for a one-person project before product-market fit. Agents touching local filesystem makes remote execution dangerous and slow. |
| Electron with Node backend | Go ecosystem (type safety, performance, single binary) preferred; Wails provides equivalent native shell with Go backend. |

## Consequences

**Positive:**
- Zero auth complexity (single hardcoded `local-user`; no tokens, sessions, or RBAC)
- Agents can safely touch local filesystem, run local processes
- No infra costs during development
- Single binary distribution

**Negative / Trade-offs:**
- No collaboration features
- Smaller addressable market
- Future SaaS migration would require non-trivial auth layer

**Neutral:**
- All SSE subscriptions are per-user (only one user exists, simplifies design)
```

- [ ] **Step 2: Write ADR-002**

Create `documents/decisions/002-clean-arch-4-layers.md`:

```markdown
---
id: ADR-002
title: Clean Architecture 4 layers
status: accepted
date: 2026-04-22
---

# ADR-002: Clean Architecture 4 layers

## Status

accepted — 2026-04-22

## Context

The pre-rewrite backend had handlers writing SQL directly, a 696-line god `ToolService`, and mixed responsibilities everywhere. A new architecture was needed before Phase 2+.

## Decision

Strict 4-layer Clean Architecture:

```
transport → app → (domain ∪ infra/store) → infra/db
```

Dependency direction is strictly bottom-up. Lower layers never import upper layers. Domain layer defines interfaces (ports); infra implements them.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Flat package structure | Previous state — caused the god object problem |
| 3-layer (no domain) | Domain layer needed to own business invariants and port interfaces independently of infra |
| Hexagonal (many adapters) | Overkill for local single-user app; 4 layers sufficient |

## Consequences

**Positive:**
- Clear testability: domain and app layers testable without HTTP or DB
- Enforced via `staticcheck` + package naming conventions (S12/S13)
- New domain can be added by following the pattern

**Negative / Trade-offs:**
- More boilerplate (interface per domain)
- Package naming aliases required everywhere (`apikeyapp`, `apikeystore`, etc.)
```

- [ ] **Step 3: Write ADR-003**

Create `documents/decisions/003-pure-go-sqlite.md`:

```markdown
---
id: ADR-003
title: Pure Go SQLite (modernc)
status: accepted
date: 2026-04-23
---

# ADR-003: Pure Go SQLite (modernc)

## Status

accepted — 2026-04-23

## Context

SQLite is the right database for a local-first single-user app. The standard `mattn/go-sqlite3` requires CGO, which complicates cross-platform builds significantly (different toolchains for Windows/Linux/Mac).

## Decision

Use `modernc.org/sqlite` — a pure Go SQLite port with no CGO. DSN uses `_pragma=...` syntax instead of the standard `?_fk=on` form.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| mattn/go-sqlite3 | Requires CGO; cross-platform builds require separate toolchains |
| PostgreSQL | Overkill for local-first; requires external process |
| BoltDB/BadgerDB | No SQL; schema migrations would be manual |

## Consequences

**Positive:**
- `GOOS=windows go build ./...` works in one command, no cross-compile toolchain
- Pure Go, easier to embed in Wails

**Negative / Trade-offs:**
- DSN syntax differs (`_pragma=foreign_keys=on` instead of `?_fk=on`)
- Slightly slower than CGO SQLite in benchmarks (irrelevant for single-user)
```

- [ ] **Step 4: Write ADR-004**

Create `documents/decisions/004-wails-http-reuse.md`:

```markdown
---
id: ADR-004
title: Wails shell, reuse HTTP API (no native binding)
status: accepted
date: 2026-05-12
---

# ADR-004: Wails shell, reuse HTTP API (no native binding)

## Status

accepted — 2026-05-12

## Context

Wails offers native Go↔JS bindings as its primary feature: Go functions callable directly from the frontend without HTTP. This is the "Wails way." However, Forgify had an existing full HTTP API.

## Decision

Use Wails only as a native window shell. The frontend communicates with the backend exclusively via the existing HTTP API (localhost). No Wails native bindings used.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Wails native bindings | Would require maintaining two integration surfaces (HTTP for testend/dev + native for prod); SSE streaming is awkward via native bindings |
| Electron | Node.js backend; we prefer Go single-binary |
| Tauri (Rust) | Rust backend would require rewrite |

## Consequences

**Positive:**
- Testend and `curl` work the same in desktop mode
- No Wails-specific abstraction layer to maintain
- `wails dev` just starts the existing HTTP server + Wails window

**Negative / Trade-offs:**
- Localhost HTTP has ~0.1ms overhead vs native IPC (irrelevant in practice)
- Wails native binding feature unused
```

- [ ] **Step 5: Write ADR-005**

Create `documents/decisions/005-three-sse-streams-cap.md`:

```markdown
---
id: ADR-005
title: Three SSE streams, permanent cap
status: accepted
date: 2026-05-12
---

# ADR-005: Three SSE streams, permanent cap

## Status

accepted — 2026-05-12

## Context

SSE connection count proliferates as features grow. Early design had many per-resource streams; each new feature added a new endpoint. This led to connection limit issues and unpredictable reconnect behavior.

## Decision

Exactly three SSE streams, never more (E1 standard):

1. **Event log** `GET /api/v1/eventlog` — 5 events × 7 block types; agent conversation stream
2. **Notifications** `GET /api/v1/notifications` — global entity change notifications; open vocabulary
3. **Forge stream** `GET /api/v1/forge` — 4 events × 3 kinds (function/handler/workflow); closed enum

All three are per-`user_id`. New features must fit into these three streams. Adding a fourth stream requires a new ADR.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Per-resource SSE | Connection count unbounded; each conversation/flowrun would open its own stream |
| WebSocket | Heavier protocol; SSE sufficient for server-push-only patterns |
| Polling | Higher latency, more server load |

## Consequences

**Positive:**
- Predictable connection count (always exactly 3 per connected client)
- Forced discipline: new features must use existing streams
- Simpler client-side reconnect logic

**Negative / Trade-offs:**
- Notification fan-out requires client-side filtering
- Adding genuinely new stream types requires ADR + deliberate design
```

- [ ] **Step 6: Commit**

```bash
git add documents/decisions/
git commit -m "docs(adr): add ADR 001-005 foundational decisions"
```

---

## Task 7: Write ADRs 006–009 (LLM Infrastructure)

**Files:**
- Create: `documents/decisions/006-own-llm-client-no-eino.md`
- Create: `documents/decisions/007-per-user-sse.md`
- Create: `documents/decisions/008-no-shared-openai-compat.md`
- Create: `documents/decisions/009-native-gemini-api.md`

- [ ] **Step 1: Write ADR-006**

Create `documents/decisions/006-own-llm-client-no-eino.md`:

```markdown
---
id: ADR-006
title: Own LLM client, eject Eino
status: accepted
date: 2026-05-12
---

# ADR-006: Own LLM client, eject Eino

## Status

accepted — 2026-05-12

## Context

Forgify originally used ByteDance's Eino framework for LLM orchestration. Eino added significant complexity: framework-specific types, opaque middleware chains, and constraints on how streaming worked. As provider requirements diverged (Anthropic native protocol, Gemini native, thinking blocks, tool calling), the framework became a bottleneck.

## Decision

Eject Eino entirely. Build `infra/llm` from scratch:
- `Provider` interface (`Name/DefaultBaseURL/BuildRequest/ParseStream`)
- Shared transport layer (`transport.go`, 120s `*http.Client`, `doRequest`, `classifyHTTPError`)
- `providerRegistry` with named providers
- Each of 11 providers fully self-contained

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Keep Eino | Framework constraints prevented native Anthropic/Gemini support; thinking blocks required hacks |
| LangChain Go | Same problem; framework-first rather than protocol-first |
| OpenAI SDK only | Can't handle Anthropic/Gemini native protocols |

## Consequences

**Positive:**
- Each provider matches its official API exactly
- Thinking blocks, tool use, streaming all work natively
- Zero framework dependency, full control

**Negative / Trade-offs:**
- ~800 lines of infra/llm to maintain
- New provider requires implementing BuildRequest + ParseStream
```

- [ ] **Step 2: Write ADR-007**

Create `documents/decisions/007-per-user-sse.md`:

```markdown
---
id: ADR-007
title: Per-user SSE subscriptions
status: accepted
date: 2026-05-12
---

# ADR-007: Per-user SSE subscriptions

## Status

accepted — 2026-05-12

## Context

SSE subscriptions could be scoped per-resource (per conversation, per flowrun) or per-user. Per-resource is more granular but requires managing N connections per user.

## Decision

All three SSE streams subscribe by `user_id`. The client receives all events for the user and filters client-side by `conversationId`, `scope`, etc.

## Consequences

**Positive:**
- Always exactly 3 connections (matches ADR-005 cap)
- No subscription management complexity
- Works perfectly for single-user local app

**Negative / Trade-offs:**
- Client receives events it doesn't need and must filter
- Multi-user (future SaaS) would require re-evaluation
```

- [ ] **Step 3: Write ADR-008**

Create `documents/decisions/008-no-shared-openai-compat.md`:

```markdown
---
id: ADR-008
title: No shared OpenAI-compat provider (R5 refactor)
status: accepted
date: 2026-05-30
---

# ADR-008: No shared OpenAI-compat provider (R5 refactor)

## Status

accepted — 2026-05-30

## Context

After ADR-006, infra/llm had a `openAICompatProvider` struct shared by 9 providers (deepseek, qwen, zhipu, moonshot, doubao, openrouter, ollama, custom, openai). Each provider called the shared BuildRequest/ParseStream. As provider-specific quirks accumulated (different auth headers, different thinking encoding, different tool call formats), the shared struct grew complex conditional logic.

## Decision

R5 refactor: delete `openAICompatProvider`. Each of the 9 providers gets its own complete `BuildRequest` and `ParseStream` implementation matching its official API docs exactly.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Keep shared struct with more conditionals | The conditional branches were already unreadable; would get worse with Gemini/Anthropic parity |
| Code generation | Overkill for 9 providers |

## Consequences

**Positive:**
- Each provider file is self-contained and readable
- Provider-specific bugs isolated; changes don't affect other providers
- Matches each provider's official API exactly

**Negative / Trade-offs:**
- ~3× more code across provider files
- Common patterns (retry, timeout) duplicated — mitigated by shared `transport.go`
```

- [ ] **Step 4: Write ADR-009**

Create `documents/decisions/009-native-gemini-api.md`:

```markdown
---
id: ADR-009
title: Native Gemini generateContent, no OpenAI shim
status: accepted
date: 2026-05-30
---

# ADR-009: Native Gemini generateContent, no OpenAI shim

## Status

accepted — 2026-05-30

## Context

Google provides both a native `generateContent` API and an OpenAI-compatible endpoint (`/openai/v1/...`). The OpenAI shim would allow reusing existing OpenAI provider code. However, the native API has capabilities the shim doesn't expose: `thoughtSignature` round-tripping (required for Gemini 3 multi-turn tool loops), `thought: true` reasoning parts, and `systemInstruction`.

## Decision

Implement a native `geminiProvider` targeting `v1beta` `streamGenerateContent?alt=sse`:
- Model in URL path (not request body)
- `x-goog-api-key` header auth
- `contents/parts`, `systemInstruction`, `tools.functionDeclarations`
- `generationConfig.thinkingConfig` for reasoning
- Round-trip `thoughtSignature` for Gemini 3 multi-turn

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| OpenAI-compat shim | Can't round-trip `thoughtSignature`; no reasoning part access |

## Consequences

**Positive:**
- Full Gemini 3 multi-turn tool loop support
- Reasoning text (`thought: true` parts) accessible
- `thoughtSignature` preserved across turns

**Negative / Trade-offs:**
- Separate code path; changes to Gemini API require updating native implementation
```

- [ ] **Step 5: Commit**

```bash
git add documents/decisions/
git commit -m "docs(adr): add ADR 006-009 LLM infrastructure decisions"
```

---

## Task 8: Write ADRs 010–015 (Workflow, Platform, Frontend)

**Files:**
- Create: `documents/decisions/010-durable-execution.md`
- Create: `documents/decisions/011-cel-conditions.md`
- Create: `documents/decisions/012-no-checkpoint-undo.md`
- Create: `documents/decisions/013-modelcaps-replaces-modelmeta.md`
- Create: `documents/decisions/014-sandbox-v2-embedded-mise.md`
- Create: `documents/decisions/015-fsd-6-layer-frontend.md`

- [ ] **Step 1: Write ADR-010**

Create `documents/decisions/010-durable-execution.md`:

```markdown
---
id: ADR-010
title: Durable execution via journal+replay
status: accepted
date: 2026-05-31
---

# ADR-010: Durable execution via journal+replay

## Status

accepted — 2026-05-31

## Context

Workflow execution must survive crashes. Nodes may run for minutes (LLM calls, sandbox execution). The design required choosing between: (a) message-queue / actor model, (b) durable execution via journal+replay, (c) simple fire-and-forget with manual retry.

## Decision

Durable execution: every workflow step writes a journal entry before executing. On crash-restart, the executor replays from the last committed journal entry. This is the "sagas" pattern.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Message-queue / actor model | Requires external broker (Kafka, NATS) or in-process actor framework; adds distributed systems complexity for a local app |
| Fire-and-forget + manual retry | No crash safety; user must manually re-run failed workflows |
| Event sourcing (full) | Overkill; journal+replay gives same crash safety at 1/3 the complexity |

## Consequences

**Positive:**
- Workflow survives process crashes
- Reproducible: same journal → same result
- No external dependencies (journal is SQLite rows)

**Negative / Trade-offs:**
- Node implementations must be idempotent (replay safety)
- Journal must be pruned (rows accumulate)
- More complex executor code
```

- [ ] **Step 2: Write ADR-011**

Create `documents/decisions/011-cel-conditions.md`:

```markdown
---
id: ADR-011
title: CEL for workflow conditions
status: accepted
date: 2026-05-31
---

# ADR-011: CEL for workflow conditions

## Status

accepted — 2026-05-31

## Context

Workflow Case nodes require a condition language for branch selection. Options: custom DSL, CEL (Common Expression Language), JavaScript eval, or template string comparison.

## Decision

CEL (Common Expression Language) — the same expression language used by Kubernetes admission controllers, Firebase Rules, and Google's API filtering.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Custom DSL | No existing parser, debugger, or LLM training data; would need maintenance |
| JavaScript eval | Security risk (eval in sandbox possible but complex); not suitable for simple boolean conditions |
| Template string comparison | Too limited for complex conditions (AND/OR, type coercion, null safety) |

## Consequences

**Positive:**
- Existing spec, test libraries, documentation
- LLMs write correct CEL expressions reliably (in training data)
- Type-safe evaluation

**Negative / Trade-offs:**
- External dependency (`google/cel-go`)
- Learning curve for non-Google engineers (minimal for this project)
```

- [ ] **Step 3: Write ADR-012**

Create `documents/decisions/012-no-checkpoint-undo.md`:

```markdown
---
id: ADR-012
title: No Checkpoint/Undo feature
status: accepted
date: 2026-05-27
---

# ADR-012: No Checkpoint/Undo feature

## Status

accepted — 2026-05-27

## Context

§10.1 of an earlier design spec planned a Checkpoint/Undo system: users could snapshot agent state and roll back. This would require dedicated infrastructure for state serialization and storage.

## Decision

Drop Checkpoint/Undo. Trinity (function/handler/workflow) has versioning at the entity level. Filesystem operations can be undone via git. The use cases don't justify dedicated checkpoint infrastructure for a single-user local app.

## Consequences

**Positive:**
- No checkpoint table, no snapshot serialization code
- Simpler agent state model

**Negative / Trade-offs:**
- Agent mid-run state cannot be rolled back (must re-run)
- Users who wanted undo will need to use git or re-run workflows
```

- [ ] **Step 4: Write ADR-013**

Create `documents/decisions/013-modelcaps-replaces-modelmeta.md`:

```markdown
---
id: ADR-013
title: modelcaps replaces modelmeta
status: accepted
date: 2026-05-30
---

# ADR-013: modelcaps replaces modelmeta

## Status

accepted — 2026-05-30

## Context

`pkg/modelmeta` stored static model metadata (context window, max output). It couldn't express per-provider-and-model capability differences (thinking shape, tool call support variance) or allow user-level overrides.

## Decision

Replace with `pkg/modelcaps`: per-(provider, model) ability catalog using family rules + per-model precise overrides. `CapabilityService.ResolveCapabilities` merges: user override (`model_cap_overrides` table) > static per-model rule > family default.

## Consequences

**Positive:**
- Users can override capability assumptions without code changes
- Handles provider-specific thinking shapes (Anthropic budget_tokens vs Gemini thinkingConfig)
- Per-model precision where family rules are wrong

**Negative / Trade-offs:**
- More complex resolution pipeline
- Static rules must be kept current as providers release new models
```

- [ ] **Step 5: Write ADR-014**

Create `documents/decisions/014-sandbox-v2-embedded-mise.md`:

```markdown
---
id: ADR-014
title: Sandbox v2 with embedded mise binary
status: accepted
date: 2026-05-13
---

# ADR-014: Sandbox v2 with embedded mise binary

## Status

accepted — 2026-05-13

## Context

Sandbox v1 required users to have Python/Node/etc. installed separately. The install experience was poor. Sandbox v2 needed a self-contained solution.

## Decision

Bundle `mise` (a polyglot version manager) binary via `go:embed`. `make resources` downloads the platform-appropriate binary to `mise/<goos>-<goarch>/`. The embedded binary is used to install and manage sandbox runtimes. Sandbox v1 is deprecated.

## Consequences

**Positive:**
- Zero external dependencies for sandbox setup
- Reproducible runtime versions across machines

**Negative / Trade-offs:**
- Binary size increases (~30MB for mise)
- `make resources` must be run once before `make e2e`
- Platform-specific binaries must be kept current
```

- [ ] **Step 6: Write ADR-015**

Create `documents/decisions/015-fsd-6-layer-frontend.md`:

```markdown
---
id: ADR-015
title: FSD 6-layer architecture for frontend
status: accepted
date: 2026-05-27
---

# ADR-015: FSD 6-layer architecture for frontend

## Status

accepted — 2026-05-27

## Context

The original frontend was a flat structure with mixed concerns. During the V1.2 revamp, a scalable architecture was needed. Feature-Sliced Design (FSD) emerged from the React community as a structured approach for complex frontends.

## Decision

Adopt FSD 6-layer architecture:

```
app → pages → widgets → features → entities → shared
```

Strict downward dependencies only. Enforced by `steiger` + `eslint-plugin-boundaries` at lint time. Each slice has an `index.ts` barrel as its public API.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Flat component structure | Doesn't scale; circular dependency prone |
| Next.js app router conventions | Not using Next.js; Wails desktop doesn't need SSR |
| Domain-driven folder structure | Less community tooling; FSD has steiger for enforcement |

## Consequences

**Positive:**
- Clear dependency rules enforced by tooling
- New features follow a predictable pattern
- DIP pattern for shared↔upper-layer communication

**Negative / Trade-offs:**
- More boilerplate (index.ts barrel per slice)
- Learning curve for engineers unfamiliar with FSD
- `steiger` adds to lint time
```

- [ ] **Step 7: Commit**

```bash
git add documents/decisions/
git commit -m "docs(adr): add ADR 010-015 workflow, platform, frontend decisions"
```

---

## Task 9: Add Frontmatter to All Active Documents

**Files:**
- Modify: all `.md` files in `documents/concepts/`, `documents/references/`, `documents/working/`

The frontmatter standard:

```yaml
---
id: DOC-NNN
type: concept|reference|how-to|working|log
status: active
owner: @weilin
created: YYYY-MM-DD
reviewed: 2026-05-31
review-due: YYYY-MM-DD
audience: [human, ai]
---
```

Review-due periods: `concept` = 90 days, `reference` = 30 days, `working` = 90 days, `log` = never.

- [ ] **Step 1: Add frontmatter to concepts/**

Prepend to `documents/concepts/architecture.md`:
```yaml
---
id: DOC-001
type: concept
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-05-31
review-due: 2026-08-31
audience: [human, ai]
---
```

Prepend to `documents/concepts/frontend-prd.md`:
```yaml
---
id: DOC-002
type: concept
status: active
owner: @weilin
created: 2026-05-15
reviewed: 2026-05-31
review-due: 2026-08-31
audience: [human, ai]
---
```

Prepend to `documents/concepts/frontend-architecture.md`:
```yaml
---
id: DOC-003
type: concept
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-08-31
audience: [human, ai]
---
```

- [ ] **Step 2: Add frontmatter to references/backend/ contracts**

Prepend to `documents/references/backend/api.md` (id: DOC-010, type: reference, review-due: 2026-06-30).
Prepend to `documents/references/backend/database.md` (id: DOC-011, type: reference, review-due: 2026-06-30).
Prepend to `documents/references/backend/error-codes.md` (id: DOC-012, type: reference, review-due: 2026-06-30).
Prepend to `documents/references/backend/events.md` (id: DOC-013, type: reference, review-due: 2026-06-30).

All use:
```yaml
---
id: DOC-01X
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
```

- [ ] **Step 3: Add frontmatter to references/backend/domains/**

For each domain file (apikey, ask, catalog, chat, compaction, conversation, document, filesystem, flowrun, function, handler, mcp, memory, mention, model, permissions, relation, sandbox, scheduler, search, skill, trigger, todo, web, workflow):

```yaml
---
id: DOC-1XX          # assign sequential IDs starting at DOC-101
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
```

Use a script to add frontmatter to all domain docs at once:

```bash
i=101
for f in documents/references/backend/domains/*.md; do
  if ! head -1 "$f" | grep -q "^---"; then
    tmpfile=$(mktemp)
    printf -- "---\nid: DOC-%d\ntype: reference\nstatus: active\nowner: @weilin\ncreated: 2026-04-22\nreviewed: 2026-05-31\nreview-due: 2026-06-30\naudience: [human, ai]\n---\n\n" "$i" > "$tmpfile"
    cat "$f" >> "$tmpfile"
    mv "$tmpfile" "$f"
    i=$((i+1))
  fi
done
```

- [ ] **Step 4: Add frontmatter to references/frontend/**

Apply same pattern to all files in `documents/references/frontend/` and `documents/references/frontend/slices/`:

```yaml
---
id: DOC-2XX
type: reference
status: active
owner: @weilin
created: 2026-05-27
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
```

- [ ] **Step 5: Add frontmatter to references/changelog.md**

```yaml
---
id: DOC-300
type: log
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-05-31
review-due: never
audience: [human, ai]
---
```

- [ ] **Step 6: Add frontmatter to working/ docs**

For `documents/working/workflow-revamp/00-overview.md` and the index file (create one if missing):

```yaml
---
id: WRK-001
type: working
status: active
owner: @weilin
created: 2026-05-20
reviewed: 2026-05-31
review-due: 2026-08-20
audience: [human, ai]
landed-into:
---
```

For `documents/working/llm-providers/` — this is already landed (R1-R5 shipped). Add:

```yaml
---
id: WRK-002
type: working
status: archived
owner: @weilin
created: 2026-05-25
reviewed: 2026-05-30
review-due: never
audience: [human, ai]
landed-into: documents/concepts/architecture.md
---
```

For `documents/working/testend/` — also landed (V3 shipped):

```yaml
---
id: WRK-003
type: working
status: archived
owner: @weilin
created: 2026-05-25
reviewed: 2026-05-27
review-due: never
audience: [human, ai]
landed-into: documents/references/backend/domains/
---
```

- [ ] **Step 7: Commit**

```bash
git add -A documents/
git commit -m "docs: add frontmatter to all active documents"
```

---

## Task 10: Write doc-lint Tool

**Files:**
- Create: `backend/cmd/doc-lint/main.go`
- Create: `backend/cmd/doc-lint/frontmatter.go`

- [ ] **Step 1: Write frontmatter.go**

Create `backend/cmd/doc-lint/frontmatter.go`:

```go
package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"time"
)

type Frontmatter struct {
	ID          string
	Type        string
	Status      string
	Owner       string
	Created     string
	Reviewed    string
	ReviewDue   string
	Audience    string
	LandedInto  string
	SupersededBy string
}

var requiredFields = []string{"id", "type", "status", "owner", "created", "reviewed", "review-due"}

var validTypes = map[string]bool{
	"concept": true, "reference": true, "how-to": true,
	"decision": true, "log": true, "working": true,
}

var validStatuses = map[string]bool{
	"draft": true, "active": true, "superseded": true,
	"deprecated": true, "archived": true,
}

// parseFrontmatter reads YAML frontmatter from a markdown file.
// Returns nil if the file has no frontmatter block.
func parseFrontmatter(path string) (*Frontmatter, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	if !scanner.Scan() {
		return nil, nil
	}
	if strings.TrimSpace(scanner.Text()) != "---" {
		return nil, nil // no frontmatter
	}

	fm := &Frontmatter{}
	fields := map[string]string{}
	for scanner.Scan() {
		line := scanner.Text()
		if strings.TrimSpace(line) == "---" {
			break
		}
		parts := strings.SplitN(line, ":", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])
		fields[key] = val
	}

	fm.ID = fields["id"]
	fm.Type = fields["type"]
	fm.Status = fields["status"]
	fm.Owner = fields["owner"]
	fm.Created = fields["created"]
	fm.Reviewed = fields["reviewed"]
	fm.ReviewDue = fields["review-due"]
	fm.LandedInto = fields["landed-into"]
	fm.SupersededBy = fields["superseded-by"]
	return fm, nil
}

func validateFrontmatter(path string, fm *Frontmatter) []string {
	var issues []string

	if fm == nil {
		return []string{fmt.Sprintf("missing frontmatter block")}
	}

	// Required fields
	fieldMap := map[string]string{
		"id": fm.ID, "type": fm.Type, "status": fm.Status,
		"owner": fm.Owner, "created": fm.Created,
		"reviewed": fm.Reviewed, "review-due": fm.ReviewDue,
	}
	for _, f := range requiredFields {
		if fieldMap[f] == "" {
			issues = append(issues, fmt.Sprintf("missing required field: %s", f))
		}
	}

	// Valid type
	if fm.Type != "" && !validTypes[fm.Type] {
		issues = append(issues, fmt.Sprintf("invalid type %q (must be one of: concept, reference, how-to, decision, log, working)", fm.Type))
	}

	// Valid status
	if fm.Status != "" && !validStatuses[fm.Status] {
		issues = append(issues, fmt.Sprintf("invalid status %q", fm.Status))
	}

	// Review-due check (warn only for past dates)
	if fm.ReviewDue != "" && fm.ReviewDue != "never" {
		due, err := time.Parse("2006-01-02", fm.ReviewDue)
		if err == nil && time.Now().After(due) {
			issues = append(issues, fmt.Sprintf("WARN: review-due %s is in the past", fm.ReviewDue))
		}
	}

	return issues
}
```

- [ ] **Step 2: Write main.go**

Create `backend/cmd/doc-lint/main.go`:

```go
// Command doc-lint validates documentation frontmatter and lifecycle rules.
//
// Checks:
//   - All non-archive .md files have valid frontmatter
//   - All required frontmatter fields are present
//   - review-due dates (warns on past dates, does not fail)
//   - working/ docs older than 90 days without landed-into
//   - INDEX.md is ≤ 50 lines
//   - decisions/ files are not modified after creation (git blame check)
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

func main() {
	root := flag.String("root", ".", "repository root")
	flag.Parse()

	docsDir := filepath.Join(*root, "documents")
	exitCode := 0
	warnings := 0

	err := filepath.WalkDir(docsDir, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			// Skip archive entirely
			if d.Name() == "archive" {
				return filepath.SkipDir
			}
			return nil
		}
		if filepath.Ext(path) != ".md" {
			return nil
		}

		rel, _ := filepath.Rel(*root, path)

		fm, parseErr := parseFrontmatter(path)
		if parseErr != nil {
			fmt.Printf("ERROR %s: cannot read file: %v\n", rel, parseErr)
			exitCode = 1
			return nil
		}

		issues := validateFrontmatter(path, fm)
		for _, issue := range issues {
			if strings.HasPrefix(issue, "WARN:") {
				fmt.Printf("WARN  %s: %s\n", rel, issue)
				warnings++
			} else {
				fmt.Printf("ERROR %s: %s\n", rel, issue)
				exitCode = 1
			}
		}

		// Check working/ lifecycle
		if fm != nil && fm.Type == "working" && fm.Status == "active" && fm.LandedInto == "" {
			if fm.Created != "" {
				created, err := time.Parse("2006-01-02", fm.Created)
				if err == nil && time.Since(created) > 90*24*time.Hour {
					fmt.Printf("ERROR %s: working doc older than 90 days with no landed-into\n", rel)
					exitCode = 1
				}
			}
		}

		return nil
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "walk error: %v\n", err)
		os.Exit(1)
	}

	// Check INDEX.md line count
	indexPath := filepath.Join(docsDir, "INDEX.md")
	if data, err := os.ReadFile(indexPath); err == nil {
		lines := strings.Count(string(data), "\n")
		if lines > 50 {
			fmt.Printf("ERROR documents/INDEX.md: %d lines (must be ≤ 50)\n", lines)
			exitCode = 1
		}
	}

	// Check decisions/ immutability via git
	decisionsDir := filepath.Join(docsDir, "decisions")
	entries, _ := os.ReadDir(decisionsDir)
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".md") {
			continue
		}
		if e.Name() == "template.md" || e.Name() == "README.md" {
			continue
		}
		path := filepath.Join(decisionsDir, e.Name())
		rel, _ := filepath.Rel(*root, path)
		out, err := exec.Command("git", "-C", *root, "log", "--oneline", "--", rel).Output()
		if err == nil {
			commitCount := len(strings.Split(strings.TrimSpace(string(out)), "\n"))
			if commitCount > 1 {
				fmt.Printf("WARN  %s: decision file has %d commits (decisions should be immutable)\n", rel, commitCount)
				warnings++
			}
		}
	}

	if exitCode == 0 {
		fmt.Printf("doc-lint: OK (%d warnings)\n", warnings)
	} else {
		fmt.Printf("doc-lint: FAILED (%d warnings)\n", warnings)
	}
	os.Exit(exitCode)
}
```

- [ ] **Step 3: Verify it builds**

```bash
cd backend && go build ./cmd/doc-lint/...
```

Expected: no output (success)

- [ ] **Step 4: Run against current state**

```bash
cd backend && go run ./cmd/doc-lint/... --root=..
```

Expected: all errors are about missing frontmatter in files not yet processed by Task 9. After Task 9 completes, should show `doc-lint: OK`.

- [ ] **Step 5: Commit**

```bash
git add backend/cmd/doc-lint/
git commit -m "tools(doc-lint): add document frontmatter and lifecycle linter"
```

---

## Task 11: Write doc-freshness-matrix Tool

**Files:**
- Create: `backend/cmd/doc-matrix/doc_freshness.go`
- Modify: `backend/cmd/doc-matrix/main.go` (extend existing coverage-matrix)

This tool compares the `reviewed` date in each reference doc against the last git commit touching the corresponding code directory, outputting a freshness table.

- [ ] **Step 1: Create doc_freshness.go**

Create `backend/cmd/doc-matrix/doc_freshness.go`:

```go
package main

import (
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

type FreshnessRow struct {
	DocPath      string
	Domain       string
	LastReviewed time.Time
	LastCodeChange time.Time
	Status       string // FRESH | STALE | UNKNOWN
}

// domainCodePaths maps domain doc names to their backend source paths.
var domainCodePaths = map[string]string{
	"apikey":       "backend/internal/domain/apikey",
	"chat":         "backend/internal/app/chat",
	"conversation": "backend/internal/domain/conversation",
	"document":     "backend/internal/domain/document",
	"flowrun":      "backend/internal/domain/flowrun",
	"function":     "backend/internal/domain/function",
	"handler":      "backend/internal/domain/handler",
	"mcp":          "backend/internal/app/mcp",
	"memory":       "backend/internal/domain/memory",
	"model":        "backend/internal/domain/model",
	"sandbox":      "backend/internal/infra/sandbox",
	"scheduler":    "backend/internal/app/scheduler",
	"workflow":     "backend/internal/domain/workflow",
	"trigger":      "backend/internal/domain/trigger",
}

func computeFreshnessMatrix(repoRoot string) []FreshnessRow {
	domainsDir := filepath.Join(repoRoot, "documents", "references", "backend", "domains")
	entries, err := readDirMDs(domainsDir)
	if err != nil {
		return nil
	}

	var rows []FreshnessRow
	for _, name := range entries {
		domain := strings.TrimSuffix(name, ".md")
		docPath := filepath.Join(domainsDir, name)

		fm, err := parseFrontmatterFromPath(docPath)
		var lastReviewed time.Time
		if err == nil && fm != nil && fm.Reviewed != "" {
			lastReviewed, _ = time.Parse("2006-01-02", fm.Reviewed)
		}

		codePath, ok := domainCodePaths[domain]
		var lastCodeChange time.Time
		status := "UNKNOWN"
		if ok {
			lastCodeChange = lastGitChange(repoRoot, codePath)
			if !lastReviewed.IsZero() && !lastCodeChange.IsZero() {
				if lastCodeChange.After(lastReviewed) {
					status = "⚠️ STALE"
				} else {
					status = "✅ FRESH"
				}
			}
		}

		relDoc, _ := filepath.Rel(repoRoot, docPath)
		rows = append(rows, FreshnessRow{
			DocPath:        relDoc,
			Domain:         domain,
			LastReviewed:   lastReviewed,
			LastCodeChange: lastCodeChange,
			Status:         status,
		})
	}
	return rows
}

func lastGitChange(repoRoot, path string) time.Time {
	out, err := exec.Command("git", "-C", repoRoot, "log", "-1", "--format=%ai", "--", path).Output()
	if err != nil {
		return time.Time{}
	}
	s := strings.TrimSpace(string(out))
	if s == "" {
		return time.Time{}
	}
	t, err := time.Parse("2006-01-02 15:04:05 -0700", s)
	if err != nil {
		return time.Time{}
	}
	return t
}

func readDirMDs(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	var names []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".md") {
			names = append(names, e.Name())
		}
	}
	return names, nil
}

func parseFrontmatterFromPath(path string) (*Frontmatter, error) {
	// Reuse the parseFrontmatter function from doc-lint
	// In practice, inline a minimal version here or share via a common package.
	// For now, duplicate the minimal logic needed.
	return parseFrontmatter(path)
}

func renderFreshnessTable(rows []FreshnessRow) string {
	var sb strings.Builder
	sb.WriteString("## Doc Freshness Matrix\n\n")
	sb.WriteString("| Domain | Last Reviewed | Last Code Change | Status |\n")
	sb.WriteString("|---|---|---|---|\n")
	for _, r := range rows {
		reviewed := "—"
		if !r.LastReviewed.IsZero() {
			reviewed = r.LastReviewed.Format("2006-01-02")
		}
		changed := "—"
		if !r.LastCodeChange.IsZero() {
			changed = r.LastCodeChange.Format("2006-01-02")
		}
		fmt.Fprintf(&sb, "| %s | %s | %s | %s |\n", r.Domain, reviewed, changed, r.Status)
	}
	return sb.String()
}
```

- [ ] **Step 2: Verify it builds**

```bash
cd backend && go build ./cmd/doc-matrix/...
```

Expected: no output (success)

- [ ] **Step 3: Run freshness check**

```bash
cd backend && go run ./cmd/doc-matrix/... --root=.. --mode=freshness
```

Expected: a freshness table showing FRESH/STALE/UNKNOWN per domain.

- [ ] **Step 4: Commit**

```bash
git add backend/cmd/doc-matrix/
git commit -m "tools(doc-matrix): add doc freshness matrix against git history"
```

---

## Task 12: Update Makefile

**Files:**
- Modify: `Makefile` (root)

- [ ] **Step 1: Read current Makefile lint/verify targets**

```bash
grep -n "lint\|verify\|matrix\|audit" Makefile | head -30
```

- [ ] **Step 2: Add doc-lint and doc-matrix targets**

In the Makefile, add after the existing `lint-frontend` target:

```makefile
## Documentation
.PHONY: lint-docs doc-matrix

# Run documentation linter (frontmatter, lifecycle, freshness warnings)
lint-docs:
	cd backend && go run ./cmd/doc-lint/... --root=..

# Generate documentation freshness matrix
doc-matrix:
	cd backend && go run ./cmd/doc-matrix/... --root=.. --mode=freshness
```

- [ ] **Step 3: Add lint-docs to verify target**

Find the `verify` target and add `lint-docs` to its dependency list. It should look like:

```makefile
verify: vet build lintprompts audit mock lint-docs
```

- [ ] **Step 4: Run verify to confirm it passes**

```bash
make lint-docs
```

Expected: `doc-lint: OK (N warnings)`

- [ ] **Step 5: Commit**

```bash
git add Makefile
git commit -m "build: add lint-docs + doc-matrix to Makefile; lint-docs in verify"
```

---

## Task 13: Update CLAUDE.md Paths

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Read current document map table in CLAUDE.md**

```bash
grep -n "documents/version-1.2" CLAUDE.md | head -40
```

- [ ] **Step 2: Update the document map table**

Find the `## 文档地图` table and replace all `documents/version-1.2/` paths:

| Old path | New path |
|---|---|
| `documents/version-1.2/backend-design.md` | `documents/concepts/architecture.md` |
| `documents/version-1.2/progress-record.md` | `documents/references/changelog.md` |
| `documents/version-1.2/service-design-documents/<domain>.md` | `documents/references/backend/domains/<domain>.md` |
| `documents/version-1.2/service-contract-documents/` | `documents/references/backend/` |
| `documents/version-1.2/desktop-packaging-notes.md` | `documents/archive/desktop-packaging-notes-2026-05/` |
| `documents/version-1.2/frontend-prd.md` | `documents/concepts/frontend-prd.md` |
| `documents/version-1.2/frontend-contract-documents/fsd-layers.md` | `documents/references/frontend/fsd-layers.md` |
| `documents/version-1.2/frontend-contract-documents/entity-types.md` | `documents/references/frontend/entity-types.md` |
| `documents/version-1.2/frontend-contract-documents/cross-cutting.md` | `documents/references/frontend/cross-cutting.md` |
| `documents/version-1.2/frontend-design-documents/<slice>.md` | `documents/references/frontend/slices/<slice>.md` |
| `documents/version-1.2/adhoc-topic-documents/testend/testend-design.md` | `documents/archive/...` |

Also update `§S14` and `§F1` trigger tables where they reference document paths.

- [ ] **Step 3: Verify no dead paths remain**

```bash
grep -c "documents/version-1.2" CLAUDE.md
```

Expected: `0`

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md document map to new path structure"
```

---

## Task 14: Write how-to Skeleton

**Files:**
- Create: `documents/how-to/add-new-domain.md`
- Create: `documents/how-to/release-checklist.md`
- Create: `documents/how-to/debug-sse-stream.md`

- [ ] **Step 1: Write add-new-domain.md**

Create `documents/how-to/add-new-domain.md`:

```markdown
---
id: HOW-001
type: how-to
status: active
owner: @weilin
created: 2026-05-31
reviewed: 2026-05-31
review-due: 2026-11-30
audience: [human, ai]
---

# How to Add a New Domain

**Pre-condition:** You have a domain name (e.g., `widget`) and a rough idea of its entities and operations.

## Step 1: End-to-end Walkthrough

Before writing code, complete the end-to-end template (CLAUDE.md "端到端推演模板"):

```
触发源 → transport handler → app service → infra/store/domain → DB
```

List all cross-domain dependencies. Do not proceed until this is done.

## Step 2: Domain Layer

Create `backend/internal/domain/widget/`:
- `widget.go` — Entity, Repository interface, Service interface, errors, sentinel values
- `providers.go` if the domain has a provider whitelist

Package name: `widget`. Imports: stdlib + domain types only (no app/infra).

## Step 3: Infra Layer

Create `backend/internal/infra/store/widget/`:
- `widget.go` — Repository implementation (GORM)

Package alias when imported: `widgetstore`.

## Step 4: App Layer

Create `backend/internal/app/widget/`:
- `widget.go` — Service implementation

Package alias when imported: `widgetapp`.

## Step 5: Transport Layer

Create `backend/internal/transport/httpapi/handlers/widget.go`:
- Register routes in `Register(mux, deps)` pattern
- Each handler: decode → call service → write envelope
- Register all sentinels in `errmap.go::errTable`

## Step 6: Wire in main.go

Add store → service → handler chain following existing patterns.

## Step 7: Documentation

- Create `documents/references/backend/domains/widget.md`
- Update `documents/references/backend/api.md` with new endpoints
- Update `documents/references/backend/database.md` with new tables
- Update `documents/references/changelog.md` with dev log
- Add ADR if any significant design decision was made

## Step 8: Tests

- Unit tests: `backend/internal/app/widget/widget_test.go`
- Pipeline test: `backend/test/api/widget/widget_pipeline_test.go`
- Add `// covers: METHOD /path` annotations

## Verification

```bash
make unit
make lint-docs
staticcheck ./...
```
```

- [ ] **Step 2: Write release-checklist.md**

Create `documents/how-to/release-checklist.md`:

```markdown
---
id: HOW-002
type: how-to
status: active
owner: @weilin
created: 2026-05-31
reviewed: 2026-05-31
review-due: 2026-11-30
audience: [human, ai]
---

# Release Checklist

## Pre-release

- [ ] `make verify` green (vet×5 + build×5 + lintprompts + audit + mock + lint-docs)
- [ ] `make e2e` green (mock + sandbox + live)
- [ ] `make doc-matrix` — no STALE domains
- [ ] All working/ docs either landed or have review-due in future
- [ ] `documents/references/changelog.md` up to date

## Build

```bash
wails build -platform darwin/arm64
```

## Post-release

- [ ] Tag release: `git tag v1.2.X`
- [ ] Push tag: `git push origin v1.2.X`
- [ ] Update phase table in `documents/concepts/architecture.md`
```

- [ ] **Step 3: Write debug-sse-stream.md**

Create `documents/how-to/debug-sse-stream.md`:

```markdown
---
id: HOW-003
type: how-to
status: active
owner: @weilin
created: 2026-05-31
reviewed: 2026-05-31
review-due: 2026-11-30
audience: [human, ai]
---

# How to Debug SSE Streams

## Monitor a stream

```bash
# Event log
curl -N -H "X-User-ID: local-user" http://localhost:8080/api/v1/eventlog

# Notifications
curl -N -H "X-User-ID: local-user" http://localhost:8080/api/v1/notifications

# Forge stream
curl -N -H "X-User-ID: local-user" http://localhost:8080/api/v1/forge
```

## Check sequence gaps

SSE messages carry `id:` field with sequence numbers. Gaps indicate dropped events. The client sends `Last-Event-ID` header on reconnect; server returns 410 `SEQ_TOO_OLD` if the buffer no longer holds that seq.

## Check buffer overflow

If you see 410 responses, the event buffer was exceeded. Default buffer is 512 events per stream per user. Investigate the event emission rate or increase `SSEBufferSize` in config.

## Testend stream view

Open testend at `http://localhost:5173` → SSE tab. Shows all three streams in real time with parsed event types and payloads.
```

- [ ] **Step 4: Commit**

```bash
git add documents/how-to/
git commit -m "docs: add how-to skeleton (add-domain, release-checklist, debug-sse)"
```

---

## Task 15: Final Verification

- [ ] **Step 1: Run full lint-docs**

```bash
make lint-docs
```

Expected: `doc-lint: OK (N warnings)` — errors = 0. Warnings for past review-due dates are acceptable at this stage.

- [ ] **Step 2: Run doc-matrix**

```bash
make doc-matrix
```

Expected: freshness table printed with no fatal errors.

- [ ] **Step 3: Run full verify pipeline**

```bash
make verify
```

Expected: all checks green including the new `lint-docs` gate.

- [ ] **Step 4: Verify CLAUDE.md has no dead paths**

```bash
grep "version-1.2" CLAUDE.md | wc -l
```

Expected: `0`

- [ ] **Step 5: Verify INDEX.md ≤ 50 lines**

```bash
wc -l documents/INDEX.md
```

Expected: ≤ 50

- [ ] **Step 6: Verify ADR count**

```bash
ls documents/decisions/*.md | grep -v template | grep -v README | wc -l
```

Expected: `15`

- [ ] **Step 7: Final commit**

```bash
git add -A
git commit -m "docs: governance system complete — 15 ADRs, lint-docs gate, freshness matrix"
git push
```

---

## Self-Review

### Spec Coverage

| Requirement | Covered by |
|---|---|
| 6 doc types with frontmatter | Task 9 (frontmatter) + Task 3 (GOVERNANCE.md) |
| Document lifecycle states | Task 3 (GOVERNANCE.md) |
| ADR pattern, 15 historical decisions | Tasks 5–8 |
| Directory restructure | Tasks 1–2 |
| INDEX.md for AI sessions | Task 4 |
| doc-lint tool integrated in verify | Tasks 10, 12 |
| Freshness matrix | Task 11 |
| CLAUDE.md path updates | Task 13 |
| How-to skeleton | Task 14 |

### Estimates

| Phase | Tasks | Estimated Time |
|---|---|---|
| Archive + restructure | 1–2 | 1h |
| Core governance docs | 3–5 | 1.5h |
| 15 ADRs | 6–8 | 2.5h |
| Frontmatter on all docs | 9 | 1h |
| Tooling | 10–12 | 3h |
| Integration | 13–15 | 1h |
| **Total** | | **~10h** |
