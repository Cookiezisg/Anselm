# Batch 87 unified gate · 2026-08-31

## Scope

This gate closes the 150-cell batch boundary after `EDGE-266`, `EDGE-267`, and
`EDGE-268 L2`. It does not change the CODEX, anchor set, alarm thresholds,
five-level standard, queue policy, or the deferred phase-2 Journey expansion.

Ledger snapshot before the gate: `848` rows, `755` fully settled, `93` open;
`3948` settled cells and `292` open cells; `manual_queue=173`,
`forced_queue=26`; batch `87=150/50`.

## Checks

| Check | Result | Evidence |
| --- | --- | --- |
| Root `make verify` | PASS | backend, frontend, docs, and demo all passed |
| `make -C backend testend` | PASS | `testend/scenarios` passed in `332.728s` |
| Rig Python self-tests | PASS | `70 tests`, `OK` |
| Proxy/LLM recorder race tests | PASS | `go test ./harness/proxycore ./cmd/llmtap -count=1 -race` |
| Go format audit | PASS | `gofmt -l backend testend` empty |
| Python/Shell syntax | PASS | `py_compile` and `bash -n` passed |
| Coverage regeneration check | PASS | `848 rows, 848 carried judgments, 0 tombstones` |
| Anchor calibration | PASS | `10/10`, judge unlocked |
| Alarm check | PASS | `208 live judgments`, baseline excluded from drift curves |
| Documentation verification | PASS | docs lint clean; six pre-existing review-due warnings only |
| `git diff --check` | PASS | no whitespace errors |
| Process audit | PASS | no owned Anselm App/backend/tap/recorder/embedder process remained |

The negative-case refusal messages printed during rig self-tests are expected
assertions of the ledger and capability guards; the suite completed `OK`.

## Decision

The unified gate is green. The next autonomous cell is `EDGE-268 L3`; manual
and forced rows remain deferred to the tail. The user-deferred 400+ Journey
expansion remains phase 2.
