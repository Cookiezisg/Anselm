# Batch 86 unified gate · 2026-08-31

## Scope

Batch 86 crossed the required 50-cell threshold at `52/50`. The batch closed the
L2-L5 cells for `EDGE-212|瞬时失败绝不轮换` and `EDGE-213|未开通读配额` after
real-App stop-and-fix reviews. It did not touch the forced queue, the 400+ Journey
deferral, or any acceptance threshold.

## Product evidence sealed in this batch

- `EDGE-212` red discovery caught misleading transient quota copy in the real App.
  The fix distinguishes transport/408/429/5xx from revoked-install auth failures,
  preserves the existing managed install, and has focused contract/widget coverage.
  Fresh session `20260831-103415` verified the corrected copy, repair recovery, unchanged
  install, and no `/v1/install` wire request.
- `EDGE-213` fresh session `20260831-104036` started with `RIG_SEED=0` and a failed
  managed provision. The real App showed `Enable free tier`, no fake zero quota, no
  managed key row, and `Not set` defaults. REST/backend recorded the typed
  `FREETIER_NOT_PROVISIONED` 404; no provisioned gateway success is claimed.
- Both sessions passed `rig-check` and `rig-down`, retained the five-channel journals,
  and left no conductor-owned process running. Independent alarm re-audits are
  `EDGE-212-real-app-ledger-alarm-reaudit-20260831.md` and
  `EDGE-213-real-app-ledger-alarm-reaudit-20260831.md`.

## Required checks

| Check | Result | Recorded fact |
|---|---|---|
| Root verification | PASS | `make verify`; backend, frontend, docs, demo all passed |
| Full black-box testend | PASS | `make -C backend testend`; `testend/scenarios` passed, `307.552s` |
| Rig unit tests | PASS | `python3 -m unittest discover -s testend/rig -p 'test_*.py' -q`; 69 tests |
| Proxy/wire tests | PASS | `go test ./harness/proxycore ./cmd/llmtap -count=1 -race` |
| Coverage regeneration | PASS | `gen_coverage.py --check`: 848 rows, 848 carried judgments, 0 tombstones |
| Alarm drift gate | PASS | `alarms.py check`: 52 live judgments, 4240 baseline judgments excluded |
| Anchor calibration | PASS | 10/10 anchors; judge unlocked for 4h |
| Whitespace audit | PASS | `git diff --check` |

## Ledger state after gate

The authoritative matrix is `848` rows: `719` fully settled and `129` open; `3804`
cells are settled and `436` remain open. `forced_queue=24` remains untouched. The
next ordinary frontier is `EDGE-214|开通降级不挂 boot`; the next batch starts at
`0/50` after this gate.

## Integrity

The gate did not change the CODEX, anchor answers, alarm thresholds/algorithm, formal
sequence, five-level standard, or forced/manual queue semantics. The provisional-NA
recognizer was tightened before this gate and covered by a regression test; it prevents
missing real-App evidence from being silently counted as settled.
