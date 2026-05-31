---
id: ADR-021
title: Single-transaction trigger claim; no two-step fallback
status: accepted
date: 2026-05-31
supersedes:
superseded-by:
---

# ADR-021: trigger dispatch claims a firing in a single transaction

## Status

accepted — 2026-05-31

## Context

`17` §6 offered two claim implementations: a single transaction (`claim pending→claimed` + create flowrun + backfill `flowrun_id` + `status=started`) and a two-step "退路" with a `claimed_at` lease + boot-time stale-claim recovery. The review showed `11`'s canon pseudocode is the **two-step** version, which produces the very "claimed-but-no-flowrun" strand the contract claims to eliminate — and `CANON-BOOT`'s four steps never scan for stale claims, so a crash between the two steps strands the firing permanently.

## Decision

**Mandate the single-transaction claim.** SQLite's single-writer makes `claim + create flowrun + backfill + status=started` atomic in one tx:
- crash before commit → rolls back → firing stays `pending` → boot dispatcher re-consumes it;
- crash after commit → firing `started` + flowrun exists → boot replays the flowrun (Theme 1), dispatcher skips it (not `pending`).

There is no intermediate "claimed-but-no-flowrun" state. **Delete the two-step fallback** from `17` §6 (and the `claimed_at` lease column, unless retained purely as an audit timestamp).

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Two-step claim + lease + stale-claim GC | Re-introduces the strand window + needs boot-time recovery the single-tx eliminates by construction. Only justified under multi-writer contention, which a local single-process SQLite app does not have. |

## Consequences

**Positive:**
- No strand state, no stale-claim scan in boot; the crash matrix has two clean outcomes.

**Negative / Trade-offs:**
- `StartRun`'s flowrun-creation runs inside the dispatcher's claim transaction (acceptable — both are local SQLite writes; `StartRun` must therefore be tx-aware, taking the `*gorm.DB` tx handle).
