---
id: WRK-IMPL-STRATEGY
type: spec
status: active
owner: @weilin (impl: Claude, full take-over per /goal 2026-05-31)
created: 2026-05-31
audience: [human, ai]
---

# Durable Execution Engine — Implementation Strategy

This is the **play** for implementing `docs/working/workflow-revamp/` (00–17; `17` is the contract single-source-of-truth). It is the brainstorming output that precedes the writing-plans milestone plans. It records: the engine-shape decision, the milestone spine, and the **root resolution stance for every design gap found in the 2026-05-31 adversarial review** (the gaps that put "照着建" readiness at 4/10).

Operating mode: full take-over with design authority over 00–17. Gaps/contradictions are resolved **from the root** (amend 17/00 + ADR), never patched at the call site. Async authorization: decisions are made + recorded, not gated on approval.

---

## 1. Engine shape — decision

**Chosen: refactor-in-place onto the durable spine.** Reshape `app/scheduler` from a topological-walk + `PausedState`-snapshot executor into a **structural durable interpreter** (journal + deterministic replay); collapse the 14 `dispatch_*.go` node handlers into the 5-node activity model; replace `app/workflow/expression.go` (Go `text/template`) with CEL; amend the `workflow` graph model (14→5 node kinds, typed config per `17`§7); build new journal/approval/trigger stores. Each milestone leaves the system runnable + tested (design principle #1).

| Rejected alternative | Reason |
|---|---|
| **Greenfield `app/durableengine/`, run both engines, big-bang cutover** | Pre-launch, no data to preserve (CANON-MIGRATION: clear & rebuild) → no reason to run two engines; big-bang violates "each phase delivers value". |
| **Keep 14-node dispatchers, bolt journaling underneath the topo-walk** | Keeps the message-queue-era abstractions the revamp explicitly killed (per-node `Node` rows, `PausedState`, topo in-degree). The 5-node collapse + CEL + active-branch join + journal-as-truth ARE the point. |

**The incision** (from code map):
- **Delete:** `app/scheduler/{state.go,pause.go,rehydrate.go,subdag.go}` (topo walk + pause-state snapshot); `FlowRun.PausedState`; `domain/flowrun/node.go` (`flowrun_nodes` per-dispatch rows → journal replaces); `app/workflow/expression.go` text/template engine.
- **Reshape:** `scheduler.go` `StartRun` stays as the entry but `executeRun`→durable interpreter; the 13 `dispatch_*.go` collapse to activity executors for 5 kinds (`function`/`handler`/`mcp`/`agent`→`tool` activity; `llm`→`agent`; `condition`→`case`; `loop`/`parallel`/`variable`/`wait`/`http` → control-flow / gate / forge-function, no dispatcher); `domain/workflow/node.go` node-type enum 14→5 + typed config.
- **Keep:** `app/workflow/{validate.go,apply.go,capability_check.go}` (authoring-time, orthogonal to execution; amended for 5 nodes); `domain/workflow` graph storage shape (`Version.Graph` JSON); `infra/trigger/{cron,fsnotify,webhook}` listeners (callback contract stable, now write to inbox instead of direct StartRun).
- **Foundation reuse:** GORM-struct-as-schema (`serializer:json;type:text`, `check:... IN(...)`, `gorm.DeletedAt`+`CreatedAt`/`UpdatedAt`); `schema_extras.go` for the partial unique index (D7); `app/handler` registry `Acquire/DestroyOwner/Owner{Kind,ID}`; `app/tool` 9-method `Tool` + `Toolset{Resident,Lazy}`; `eventlogpkg.From(ctx)` emitter; `backend/test/harness` `New(t)` + in-mem SQLite + fake LLM + `SubscribeSSE`.

ADR-016 records this engine-shape decision.

---

## 2. M0 — Contract hardening (design, not code)

The review found 1 blocker + ~15 majors. **M0 resolves only the *geology* — the schema / journal / replay-key model that M1–M2 must TDD against — plus the cheap DRY/field-name cleanups in the §1/§7 I'm rewriting anyway.** Behavioral resolutions (join-skip, polling-dedup, handler-state, agent-host, continue-as-new) are deferred to the milestone that builds them, resolved JIT with an ADR there (per the goal's triage discipline — don't over-design ahead of the code that teaches you).

Each substantive resolution → an ADR (016+). 17 §1/§7 are rewritten to be the *complete, typed, internally-consistent* source; the stale schema copies in `00`/`11` are **deleted** (not disclaimed), satisfying the DRY铁律 the consolidation claimed but didn't finish.

### M0 root resolutions

| # | Finding | Root resolution (standard answer) | ADR |
|---|---|---|---|
| **R1** | `iteration_key` derivation undefined (geology of all dedup) | `iteration_key` = the enclosing loop header's **back-edge traversal ordinal** at node activation, computed by the interpreter during the deterministic walk; `0` outside loops; **one-dimensional** (nested structured loops rejected at accept, C6). It is a pure function of the walk position — never stored as a mutable counter, so it cannot drift; replay recomputes the identical value because loop continuation is a journaled `branch_taken`. | 017 |
| **R2** | record-once `UNIQUE(...,type)` collides with append-many `node_failed`; agent_step key (turn/tool_call_id) inconsistent; SQLite NULL-distinct trap | **Unify A6+A7:** add one computed `dedup_key TEXT NOT NULL` column (app fills: `node\|iter\|type\|gen` for scalar record-once; `…\|turn\|tool_call_id` for agent sub-steps; `""` for attempt types). ONE partial unique index `(flowrun_id, dedup_key) WHERE type NOT IN ('node_started','node_failed')` in `schema_extras.go` (D7). Attempt types append freely (excluded by WHERE). NULL-safe by construction. `AppendEvent` = INSERT; unique violation ⇒ already-recorded ⇒ return existing (compare-and-insert). | 018 |
| **R3** | replay-reset: copy-hit key (no gen) vs write key (gen); failures query predicate | **One principle: a step's current state = its highest-generation record-once event for `(flowrun,node,iteration_key)`.** Replay copy-hit looks up highest-gen result event: `node_completed`→copy (no re-run, no re-write); `node_failed` as highest *and* current replay generation is newer→re-run + write `node_completed@curGen`; none→first run. `GET /flowruns/{id}/failures` = steps whose highest-gen event is `node_failed`. Resolves A8+A9 from one rule. | 019 |
| **R4** | `pinned_callables` closure depth undefined; `02:32` says agent ref "无 pin" (contradicts A-5) | A-5 pins the **transitive forge-callable closure** at `StartRun`: walk graph refs (`tool.callable`, `agent.agentRef`) + recursively each referenced entity's own callable deps (agent's mounted fn/hd; handler methods) to fixed-point; snapshot every `(callable_id→version_id)`. Closure is shallow (depth ≤ 2: workflow→{fn,hd,agent}→{agent's fn,hd}; agents don't call agents; workflow not callable). Fix `02:32` "无 pin"→A-5. | 020 |
| **R5** | claim atomicity: two paths, the two-step deadlocks | **Mandate single-transaction claim** (`claim pending→claimed` + create flowrun + backfill flowrun_id + status=started in one SQLite tx; single-writer makes it atomic). **Delete** the two-step fallback from `17`§6 (it produces the "claimed-but-no-flowrun" strand the contract claims to eliminate). | 021 |
| **R6** | trigger retry config homeless; no durable retry counter | Trigger-layer retry is **schedule-level** (Temporal Schedules): add `retry_policy` (JSON) + `consecutive_failures INT` to `trigger_schedules`. Firing failure increments, success resets; `consecutive_failures ≥ maxAttempts` → workflow auto-deactivate (the deactivate component reads this counter). Add `attention_reason`/`last_action_by` columns to `workflows`. | 022 |
| **R7** | `workflows.concurrency` "in no schema" | **Not a gap** — the column exists on the old `workflows` table (`domain/workflow/workflow.go`). `17`§1 amended to note the dispatcher reads `workflows.concurrency`. Doc-completeness only. | — |
| **R8** | DRY: stale `flowruns`/`flowrun_events` copies in `00`/`11` (each missing different cols); `17`§1 missing `polling_states`, `approvals.cancelled` | Rewrite `17`§1 as the complete typed source (as GORM struct definitions): `flowruns`(+`pinned_callables`,`generation`,`trigger_node_id`; −`paused_state`), all event/approval/trigger tables, `polling_states(workflow_id,node_id,cursor)`, `approvals.status`+`cancelled`. **Delete** the schema blocks in `00`/`11`; they reference `17`§1. | — |
| **R9** | field-name drifts (§7 vs nodes): timer-gate, `awaiting_signal` event name, `allowReason`, polling interval | (a) timer-gate `at?`/`after?` is an optional field on **all non-trigger nodes**; document once; fix `02`/`03` to list it. (b) journal event type canon = **`signal_awaited`**; fix `05`'s "awaiting_signal 事件" (keep `awaiting_signal` only as `flowruns.status`). (c) add `allowReason` to `17`§7 approval config. (d) polling interval lives on `function_versions.polling_interval` (canon); trigger polling spec = `{functionRef}` only — **remove `intervalSeconds`** from `17`§7. | — |

### M0 deferred (resolve JIT at the named milestone)

| Finding | Stance (locked; full ADR at the milestone) | Milestone |
|---|---|---|
| **join skip mechanism** (04 propagated-signal vs 17 derived) | Adopt 17: **no skip event; derive active in-edge set by replaying `branch_taken` over the pinned graph**. Delete 04's "下发 skip 信号". Algorithm spec'd at M3. | M3 |
| **polling dedup_key** (17 vs 11; non-advancing cursor) | `dedup_key=(cursor_in, segment_index)`; cursor-must-advance is the forge-author contract (taught); platform **detects non-advance + errors** (honest), never silently drops. Delete 11's `source-event-id`. | M5 |
| **stateful handler in-mem state across replay** (A15) | Standard (Temporal): activities are pure-of-inputs; handler in-mem state is ephemeral and **does not survive replay even within a flowrun** (earlier calls are copied, not re-run, so state isn't rebuilt). Make it an explicit, taught contract; no engine special-casing. | M7 |
| **agent sub-step host interface** (A10; 17:84 dangling) | `loop.Run(ctx, replayed []AgentStep)` replays recorded turns+tool-calls (copy, no re-call) to first un-journaled sub-step, then live. Fix 17:84's dangling "见 02/§实现风险". | M7 |
| **continue-as-new** (scope-var selection, cross-boundary transfer, :replay of archived) | Snapshot the live scope-var set (highest-gen node_completed outputs still referenced downstream); new segment inherits pinned_callables (NOT re-pin); archived segment not replay-target. Threshold = high `pkg/limits` default. | M6/scale |
| **WP9 N-of-M / discriminator** (16 mislabels "N/A") | Owned trade-off: threshold-joins sink into a forge function (A-7 escape hatch). Fix 16 "N/A 静态 join"→"⚖️ 刻意偏离". | doc-only |

---

## 3. Milestone spine (durable-execution value spine)

Strictly bottom-up (principle #2); complexity climbs (principle #3); each milestone independently demonstrable + pipeline-tested (principle #1). Correctness-命脉 milestones (M1–M4) are TDD: failing test first.

| M | Milestone | Delivers (demonstrable) | TDD命脉 |
|---|---|---|---|
| **M0** | Contract hardening | 17 §1/§7 complete+typed+consistent; ADR 016–022; stale copies deleted | — (design) |
| **M1** | Journal + schema foundation | 4 new tables (GORM structs) + amended flowruns/workflows/function_versions + journal store (`AppendEvent`/`LoadJournal`) | record-once dedup (partial index); seq strict-monotonic; first-wins |
| **M2** | Interpreter core: linear + replay | trigger→tool→tool→end runs; crash-replay copies journaled results, stops at first un-journaled | **replay determinism** (same journal→same path; replay copies, never re-runs LLM/tool) |
| **M3** | Control flow | case (CEL guards, branch_taken) + AND-split fork / **active-branch join** + structured loop (iteration_key); CEL replaces text/template | active-branch join no-deadlock (A-1); loop iteration_key replay |
| **M4** | approval + durable timer | approval parks (signal_awaited + approvals row) + resumes; `at`/`after` timer gate (deadline journaled) | approval survives sim-restart; timeout↔decision first-wins (same `signal_received` bucket) |
| **M5** | trigger/dispatch durable layer | trigger_firings inbox + single dispatcher (overlap/concurrency) + single-tx claim + dedup + catchup + polling + boot rehydrate | firing→flowrun atomic; crash between persist↔start resumes; overlap policies |
| **M6** | lifecycle drain + :replay + failures | active/draining/inactive drain; per-flowrun instance teardown; `:replay` (generation++); failures API; retry-exhaust→notify, trigger-exhaust→deactivate | drain never aborts in-flight; `:replay` re-runs only failed step |
| **M7** | agent domain + agent node | `ag_` forge domain (entity/version/store/CRUD/accept/run + 11 tools) + agent node (sub-step replay, outputSchema enforcement, `loop.Run` replayed-steps) | agent sub-step replay (crash at 3rd tool-call) |
| **M8** | observability + tools + SSE + e2e | trace/nodes/failures/replay/cancel tools; forge SSE 6-kind + progress tick; capability_check (real ref-check); teaching prompt; full 闭环验收 pipeline | `make verify` green; the 13-scenario 闭环 from `11` |

Estimate ≈ 20 days (matches `11`'s 7-block / 17–19-day estimate + M0 contract pass).

---

## 4. Verification & process

- **TDD** on M1–M4 correctness命脉 (replay, record-once, join, approval-resume): failing test first, then implement (per goal + superpowers:test-driven-development).
- **Per milestone:** `make mock` (pipeline, fake LLM) + `cd backend && go build ./... && staticcheck ./...` green before claiming done (verification-before-completion: paste output). New axis `backend/test/durable/` (pipeline tests, T5; in-mem SQLite, fake LLM T6).
- **Bug vs design triage** (goal): if a fix needs a call-site special-case / flag, or the same special-case recurs, or one change needs N docs → **stop, root-fix the design + ADR**, then implement. Pure coding bugs/typos/boundaries → systematic-debugging.
- **`make verify` green** is the M8 release gate (vet×5 + build×5 + lintprompts + matrix audit + pipeline mock).
- **Records:** `IMPLEMENTATION-LOG.md` (per-milestone: end-to-end推演, chosen/rejected+why, gap resolutions, pitfalls); ADRs (`docs/decisions/`); doc sync per §S14/§F1; precise commits → main (no AI attribution, auto-push); milestone brief to user (FYI, not gated).
- **Stay on main, no worktrees** (CLAUDE.md overrides superpowers:using-git-worktrees); isolate via precise `git add`.

---

## 5. Open risks (carried, not blocking)

- M2 replay determinism is the承重 invariant — a dedicated "same journal replayed twice = identical events" property test guards it from M2 onward.
- Reshaping 13 dispatchers → 5 activities touches the most code; M2/M3 carry the bulk. Dispatcher *interface* (`Router.Dispatch`) is preserved to limit blast radius.
- Agent domain (M7) is a full new forge domain (11 tools) — largest single new-code block; sequenced late so the durable core is proven first.
