# Workflow-Revamp Implementation Log

Per-milestone work log: end-to-end推演, chosen/rejected approaches + why, design-gap root resolutions, pitfalls. Strategy in [`docs/superpowers/specs/2026-05-31-durable-engine-implementation-strategy.md`](../../superpowers/specs/2026-05-31-durable-engine-implementation-strategy.md). ADRs in `docs/decisions/`.

Impl owner: Claude (full take-over per `/goal` 2026-05-31). Design authority over 00–17. Root-fix over patch.

---

## 2026-05-31 — Kickoff: review → take-over → play locked

**Context.** Took over after a 5th adversarial review (49-agent fan-out + per-finding verification) put "照着建" readiness at **4/10**: 1 blocker + ~15 majors, concentrated in the journal/replay-key geology and an incomplete DRY consolidation, not in missing code. Goal directive: resolve gaps **from the root** (amend 17/00 + ADR), never patch the call site.

**End-to-end推演 of the engine** (the spine I'm building toward): `trigger fires → trigger_firings inbox (persist-before-act) → single dispatcher claims (single-tx) + StartRun → interpreter walks pinned graph from trigger node → each agent/tool node = activity (node_started → execute → node_completed journaled) → case reads journaled payload, picks branch (branch_taken) → fork-join awaits active in-edges → approval parks (signal_awaited + approvals row), resumes on signal_received → terminal → flowrun completed`. Crash anywhere → boot replays from journal (copy journaled results, stop at first un-journaled), parked approvals resume at their wait point. `:replay` a failed run → generation++, re-run only highest-gen failures.

**Engine shape — chosen: refactor-in-place onto the durable spine** (ADR-016). Reshape `app/scheduler` topo-walk → structural durable interpreter; collapse 14 dispatchers → 5-node activities; CEL replaces text/template; amend `workflow` graph model; new journal/approval/trigger stores. **Rejected:** (a) greenfield parallel engine + big-bang cutover — pre-launch, no data to preserve (CANON-MIGRATION), big-bang violates "each phase delivers value"; (b) bolt journaling under the old topo-walk — keeps the message-queue-era abstractions the revamp killed.

**Why M0 (contract) is not code.** The journal table, its record-once keys, and `iteration_key` are the geology every later milestone TDDs against. You cannot write a record-once dedup test on a contract whose `17`§1 declares a blanket `UNIQUE(...,type)` that the same doc's §2 says must not apply to `node_failed`. So M0 makes `17`§1/§7 the complete, typed, internally-consistent source + ADRs, then M1+ build on solid ground. Behavioral gaps (join-skip, polling-dedup, handler-state, agent-host, continue-as-new) are deferred to their milestones and resolved JIT — not over-designed ahead of the code that teaches them.

**Root resolutions locked for M0** (detail in spec §2; ADRs 016–022):
- **R1/ADR-017** `iteration_key` = enclosing loop header's back-edge traversal ordinal at activation, computed by the deterministic walk (pure function of walk position, can't drift), 1-D (nested loops rejected). Closes the "geology undefined" major.
- **R2/ADR-018** unify the record-once mess: one computed `dedup_key TEXT NOT NULL` + one partial unique index `WHERE type NOT IN ('node_started','node_failed')`. Dodges SQLite's NULL-distinct-in-unique trap a naive `turn/tool_call_id` index would hit. Closes the §1-vs-§2 contradiction + agent_step 3-way key inconsistency.
- **R3/ADR-019** one state principle: a step's current state = its highest-generation record-once event. Resolves replay copy-hit-vs-write-key + the failures-query predicate together.
- **R4/ADR-020** `pinned_callables` = transitive forge-callable closure at StartRun (depth ≤ 2). Fixes the blocker + `02:32`'s "无 pin" A-5 contradiction.
- **R5/ADR-021** mandate single-tx claim; delete the deadlock-prone two-step fallback.
- **R6/ADR-022** trigger retry is schedule-level: `trigger_schedules.retry_policy` + `consecutive_failures`; deactivate reads the counter.
- **R7** `workflows.concurrency` already exists (old field) — doc-completeness, not a gap (resolved by reading code).
- **R8** rewrite `17`§1 complete+typed; **delete** stale schema copies in `00`/`11` (finish the DRY consolidation the contract claimed).
- **R9** field-name DRY: `signal_awaited` (not `awaiting_signal`) for the event; add `allowReason`; polling interval on `function_versions` (drop `intervalSeconds`); timer-gate documented on all non-trigger nodes.

**Surfaces confirmed solid** (attacked in review, held — building on them as-is): wall-clock determinism (CEL no-now + journaled deadlines), single-writer seq monotonicity, cron dedup idempotency, boot (c)-before-(d) ordering, approval timeout↔decision first-wins (both `signal_received`), A-5 parked-resume version consistency, field-name canon for `agentRef`/`callable`/`yes`-`no`.

**Pitfalls noted.** Explore A's "keep 14 dispatchers verbatim" is wrong for the revamp (5-node collapse + CEL + active-branch join change them) — corrected. SQLite treats NULLs as distinct in unique indexes → drove the `dedup_key`-column design (R2).

Next: write ADRs 016–022, rewrite `17`§1/§7, delete stale copies, fix 02/05/16, then M1 (journal foundation, TDD).
