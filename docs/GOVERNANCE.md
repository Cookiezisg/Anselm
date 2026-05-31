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
CLAUDE.md > docs/references/ > docs/concepts/ > docs/working/ > docs/archive/
```

---

## Session Artifacts (`superpowers/`)

The `docs/superpowers/` directory is managed by the Superpowers skill system and **cannot be relocated** — the skills hardcode this path. Files here are AI-generated session artifacts, not human-authored documents, so frontmatter is not required and `make lint-docs` skips this directory entirely.

| Subdirectory | Contents | Lifecycle |
|---|---|---|
| `superpowers/plans/` | Implementation plans (writing-plans skill output) | Consumed once executed → `git mv` to `archive/` |
| `superpowers/specs/` | Design specs (brainstorming skill output) | Consumed once feature lands → `git mv` to `archive/` |

**Cleanup rule:** After executing a plan or landing a spec's feature, move the file to `docs/archive/` manually. Stale plans in `superpowers/` are noise for future AI sessions.

---

## Quality Gates

`make lint-docs` runs as part of `make verify` and enforces:

1. All non-archive `.md` files have valid frontmatter
2. All required frontmatter fields are present
3. No `review-due` date is in the past (warns, doesn't fail)
4. No `working/` document is older than 90 days without `landed-into`
5. No `decisions/` document has been modified after creation (git blame check)
6. `INDEX.md` is ≤ 50 lines
