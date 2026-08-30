# Batch 84 unified gate · 2026-08-30

## Scope

This gate seals the 52/50-cell batch produced by `EDGE-183` and `EDGE-184`.
The first root gate run found two frontend regressions; they were fixed before this
second run. No acceptance threshold, CODEX law, anchor, alarm algorithm, or sequence
rule was changed.

## Results

| Gate | Result | Evidence |
|---|---|---|
| Root `make verify` | PASS | backend, frontend, docs, and demo all returned success |
| Frontend | PASS | generation, formatting, analysis, and 5452 tests |
| Backend black-box | PASS | `testend/scenarios` `ok`, 375.079s |
| Rig Python tests | PASS | 68 tests, 23.967s |
| Coverage | PASS | 848 rows, 848 carried judgments, 0 tombstones |
| Anchors | PASS | 10/10, judge unlocked |
| Alarms | PASS | clean; 2164 live judgments, 2300 baseline judgments excluded |
| Documentation | PASS | `make -C docs verify` through root gate |
| Patch hygiene | PASS | `git diff --check` clean |

## Regression repair

The startup error copy had lost its actionable development hint. The English and
Chinese strings now name the local backend recovery path again. MCP roster cards now
render status, tool count, and call count as independently locatable text segments,
while retaining the compact middle-dot visual grammar and singular English `1 call`.
Focused tests and the full frontend gate passed after the repair.

## Process audit

After the root gate, no conductor-owned Anselm backend, Flutter app, `ssetap`, `llmtap`,
or testend process remained. The user-managed Ollama daemon and its model runner remain
intentionally running for later search acceptance and are not testend-owned residue.

## Seal

Batch 84 is sealed at `52/50`. The next autonomous frontier remains
`EDGE|每租户模板 URL` L2. Forced user interaction remains deferred; P12's 400+ journey
expansion remains explicitly deferred to phase 2.
