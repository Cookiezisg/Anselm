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

## Durable Engine Implementation (016–022)

Resolve the gaps the 2026-05-31 adversarial review found before/while building the engine (extend ADR-010). Strategy: `docs/superpowers/specs/2026-05-31-durable-engine-implementation-strategy.md`.

| ADR | Title | Date | Status |
|---|---|---|---|
| [016](016-durable-interpreter-replaces-topo-walk.md) | Durable interpreter replaces topo-walk scheduler | 2026-05-31 | accepted |
| [017](017-iteration-key-loop-ordinal.md) | iteration_key = deterministic loop back-edge ordinal | 2026-05-31 | accepted |
| [018](018-dedup-key-partial-index.md) | record-once via dedup_key + partial unique index | 2026-05-31 | accepted |
| [019](019-highest-generation-state.md) | step state = highest-generation record-once event | 2026-05-31 | accepted |
| [020](020-pin-callable-closure.md) | pin transitive callable closure at StartRun | 2026-05-31 | accepted |
| [021](021-single-tx-trigger-claim.md) | single-transaction trigger claim, no two-step fallback | 2026-05-31 | accepted |
| [022](022-trigger-retry-schedule-level.md) | trigger retry is schedule-level + durable counter | 2026-05-31 | accepted |
