# Batch 90 unified gate - 2026-09-05

## Scope

Batch 90 crossed the required 50-cell threshold while closing
`EDGE-296|触点 deleted 行借名` L2-L5. This gate records the post-batch verification
without changing the five-level standard, CODEX, anchors, alarm thresholds, queue policy,
or the phase-2 deferral of the 400+ Journey expansion.

## Gate results

| Check | Result | Recorded fact |
|---|---|---|
| Root verification | PASS | `mise exec -- make verify`; backend, frontend, docs, and demo passed |
| Full black-box testend | PASS | `go test -count=1 -parallel 16 -timeout 15m ./scenarios/...` passed twice consecutively after a transient first failure; final run `349.150s` |
| Rig unit tests | PASS | `python3 -m unittest discover -s testend/rig -p 'test_*.py' -q`; 75 tests |
| Proxy/wire tests | PASS | `go test ./harness/proxycore ./cmd/llmtap -count=1 -race` passed |
| Rig Python compilation | PASS | `python3 -m py_compile testend/rig/*.py` |
| Coverage regeneration | PASS | `gen_coverage.py --check`: 848 rows, 848 carried judgments, 0 tombstones |
| Anchor calibration | PASS | `anchors.py check`: 10/10; judge unlocked for 4h |
| Alarm drift gate | PASS | `alarms.py check`: clean, 32 live judgments and 4240 baseline judgments excluded |
| Whitespace audit | PASS | `git diff --check` |
| Process residue audit | PASS | no conductor-owned App, backend, tap, recorder, llama, or testend process remained |

## Recovery note

The first full black-box invocation exited non-zero after about five minutes, but its terminal
output was too large to preserve a reliable failing test name. It was not promoted to evidence.
Two fresh runs with the same command and isolated test execution both completed with `ok` and no
failure, panic, or residue markers. This remains recorded as a transient testend observation for
nightly repetition; no code or gate threshold was changed to make it pass.

## Ledger state

After the four EDGE-296 judgments, the authoritative matrix is 848 rows: 834 fully settled and
50 cells open; 4190 cells are settled and 50 remain open. `manual_queue=165` and
`forced_queue=14`; the current batch is 53/50. The next forced item is
`EDGE|OS 通知被静默拒`, which requires a signed build and macOS notification permission and is
not replaced by an unsigned development-bundle result.

## Integrity

The gate did not alter CODEX, anchors, alarm algorithms, formal sequence, five-level judgment
standard, or manual/forced queue semantics. P12's 400+ Journey requirement remains deferred to
phase 2 by explicit user decision.
