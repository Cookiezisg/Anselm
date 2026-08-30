# Batch 85 unified gate · 2026-08-31

## Scope

This batch closed the 50-cell quota from `EDGE-191` through `EDGE-196` without
converting a required real-app or forced-interaction cell into `na`. The final
cell was `EDGE-196|受管 remote media lease`, judged L2-L5 from the single formal
session `/private/tmp/anselm-rig-formal-20260801-7/sessions/20260831-033112`.

The 400+ Journey expansion remains explicitly deferred to phase 2 by the user.
The next formal frontier is the forced/manual item `EDGE|视频轮询超时诚实话`;
this gate does not bypass it.

## Required checks

| Check | Result | Evidence |
|---|---|---|
| Root verification | PASS | `make verify` (backend, frontend, docs, demo) |
| Full black-box testend | PASS | `/private/tmp/anselm-testend-batch50-20260831-final-1788120426.log`, exit `0`, ~327s |
| Rig unit tests | PASS | `python3 -m unittest discover -s testend/rig -p 'test_*.py' -q`, 68 tests |
| Proxy core tests | PASS | `go test ./harness/proxycore` |
| Coverage regeneration | PASS | `gen_coverage.py --check`: 848 rows, 848 carried judgments, 0 tombstones |
| Alarm drift gate | PASS | `alarms.py check`: 2212 live judgments, 2300 baseline judgments excluded |
| Anchor calibration | PASS | 10/10 anchors; judge unlocked for 4h |
| Whitespace audit | PASS | `git diff --check` |

The full testend rerun included the tier-2 block-search regression discovered
by this gate. The fix keeps tier-2 index narrowing lexical-only and adds a
regression fixture that waits for all 70 catalog rows; the focused test and the
full rerun both pass. The proxy core regression also verifies that an upstream
base path such as `/v1/` is joined before forwarding requests.

## Integrity

No threshold, alarm algorithm, CODEX law, anchor answer, five-level standard,
or formal sequence was changed to obtain this result. The formal media-lease
evidence remains five-channel evidence from one attributed session; it does not
claim an independently observed remote lease download that was not recorded.
