# Batch 87 unified gate · 2026-08-31

## Scope

Batch 87 crossed the required 50-cell threshold at `60/50` after `EDGE-235|关停预算格`
was closed as `L2=F2/L3=A4/L4=C4/L5=na`. The real App redline found in the first
shutdown session was fixed and re-tested before the ledger was closed. The gate did not
touch the forced queue or resume the deferred 400+ Journey expansion.

## Required checks

| Check | Result | Recorded fact |
|---|---|---|
| Root verification | PASS | `make verify`; backend, frontend, docs and demo all passed |
| Full black-box testend | PASS | `make -C backend testend`; scenarios passed in `359.528s` |
| Rig unit tests | PASS | `python3 -m unittest discover -s testend/rig -p 'test_*.py' -q`; `70/70` |
| Proxy/wire race tests | PASS | `go test ./harness/proxycore ./cmd/llmtap -count=1 -race` |
| Go format audit | PASS | all `backend` and `testend` Go files formatted |
| Coverage regeneration | PASS | `gen_coverage.py --check`: `848 rows, 848 carried judgments, 0 tombstones` |
| Alarm drift gate | PASS | `alarms.py check`: `113 live judgments`, `4240` baseline judgments excluded |
| Anchor calibration | PASS | `10/10` anchors; judge unlocked for 4h |
| Script/whitespace audit | PASS | `py_compile`, `bash -n`, `git diff --check` |
| Owned-process audit | PASS | no conductor-owned App/backend/tap/recorder/embedder remains |

## Ledger state

The semantic matrix is `848` rows: `732` fully settled and `116` open; `3856/4240`
cells are settled and `384` remain open. The mechanical first open row is `EDGE-168`,
but it is in the explicitly deferred manual/forced queue; the active formal sequence
therefore advances to `EDGE-236|父进程死人开关`, which remains deferred until the user can
perform the required parent-process `kill -9` interaction. `manual_queue=173` and
`forced_queue=25` are unchanged.

## Integrity

The alarm threshold and algorithm, CODEX, anchor answers, five-level standard, formal
sequence and queue semantics were not changed. The repository contains unrelated
uncommitted work from the other team; the eventual commit must stage only this batch's
acceptance evidence, working-record updates, recorder retry, and the scoped startup-copy
fix, without reverting or absorbing unrelated changes.
