# Batch 89 unified gate - 2026-09-02

## Scope

Batch 89 crossed the required 50-cell threshold when `EDGE-352|分叉携带附件与
subagent 树` closed L3-L5. This gate records the complete post-batch verification. It
does not change the five-level standard, CODEX, anchors, alarm thresholds, or the
phase-2 deferral of the 400+ Journey expansion.

## Gate results

| Check | Result | Recorded fact |
|---|---|---|
| Root verification | PASS | `mise exec -- make verify`; backend, frontend, docs, and demo passed |
| Full black-box testend | PASS | `make -C backend testend`; `testend/scenarios` passed in `305.835s` |
| Rig unit tests | PASS | `python3 -m unittest discover -s testend/rig -p 'test_*.py' -q`; 71 tests |
| Proxy/wire tests | PASS | `go test ./harness/proxycore ./cmd/llmtap -count=1 -race` from `testend`; both packages passed |
| Rig Python compilation | PASS | `python3 -m py_compile testend/rig/*.py` |
| Coverage regeneration | PASS | `gen_coverage.py --check`: 848 rows, 848 carried judgments, 0 tombstones |
| Anchor calibration | PASS | 10/10 anchors; judge unlocked for 4h |
| Alarm drift gate | PASS | `alarms.py check`: 2168 live judgments, 2300 baseline judgments excluded |
| Whitespace audit | PASS | `git diff --check` |
| Process residue audit | PASS | no conductor-owned App, backend, tap, recorder, llama, or testend process remained |

## Gate recovery

The first root verification correctly stopped on three unformatted files. The files
were formatted with the repository's pinned Dart formatter. The next full run exposed
the new fork-lineage consumer missing the notifications-stream 410 resync subscription;
the consumer now invalidates on both the matching durable lifecycle signal and the
same-stream resync. Focused fork tests and the lifecycle-resync source guard passed,
then the complete root verification passed.

The first proxy command was invoked from the repository root and therefore did not
run against the `testend` Go module. It was rerun from `testend` with `-race` and
passed. The first residue check matched its own shell command; it was rerun with
self-matching excluded and passed. No failed result was promoted to evidence.

## Ledger state

After the three `EDGE-352` judgments, the authoritative matrix is `848` rows: `820`
fully settled and `28` open; `4141` cells are settled and `99` remain open.
`manual_queue=173` and `forced_queue=27` remain unchanged. Batch 89 is closed at
`51/50`; the post-commit working snapshot starts batch 90 at `0/50`.

## Integrity

The gate did not alter CODEX, anchor answers, alarm algorithms, formal sequence,
five-level judgment standard, or manual/forced queue semantics. P12's 400+ Journey
requirement remains deferred to phase 2 by explicit user decision.
