# Batch 87 unified gate · 2026-09-01

## Scope

Batch 87 reached the required `50`-cell threshold at `250/50`. This gate seals the four
new cells for `EDGE-299|顶带 5000 条积压` after a real-App pressure session and does not
touch the forced queue, the phase-2 Journey expansion, or any acceptance threshold.

## Product evidence sealed in this batch

- `EDGE-299` used a real Anselm macOS App, real HTTP skill creation, the real notification
  setting surface, independent three-stream SSE observation, backend/frontend journals,
  LLM wire readiness, Computer Use sampling, and a finalized window-bound recording.
- 10,000 pressure creations returned HTTP `201`; the notification witness recorded 10,000
  `skill.created` durable frames with seq=`16..10015` and no gap. The real App kept a
  fixed-cost top-band projection: one current card, at most two cues, visual `999+`, and
  exact accessible Clear-all semantics rather than thousands of widgets.
- Formal session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-141545`;
  product evidence=`testend/rig/formal-evidence/EDGE-299-notice-backlog-real-app-20260901.md`;
  alarm re-audit=`testend/rig/formal-evidence/EDGE-299-ledger-alarm-reaudit-20260901.md`.

## Required checks

| Check | Result | Recorded fact |
|---|---|---|
| Root verification | PASS | `make verify`; backend, frontend, docs, demo all passed |
| Full black-box testend | PASS | `make -C backend testend`; scenarios passed, `302.089s` |
| Rig unit tests | PASS | `python3 -m unittest discover -s testend/rig -p 'test_*.py' -q`; 70 tests |
| Proxy/wire tests | PASS | `mise exec -- go test ./harness/proxycore ./cmd/llmtap -count=1 -race` |
| Rig Python compilation | PASS | `python3 -m py_compile testend/rig/*.py` |
| Coverage regeneration | PASS | `gen_coverage.py --check`: 848 rows, 848 carried judgments, 0 tombstones |
| Alarm drift gate | PASS | `alarms.py check`: 300 live judgments, 4240 baseline excluded |
| Anchor calibration | PASS | 10/10 anchors; judge unlocked for 4h |
| Whitespace audit | PASS | `git diff --check` |
| Process residue audit | PASS | no conductor-owned App, backend, tap, recorder, llama or testend process remained |

## Ledger state after gate

The authoritative matrix is `848` rows: `779` fully settled and `69` open; `4039` cells
are settled and `201` remain open. `manual_queue=173` and `forced_queue=26` remain unchanged.
The next autonomous frontier is `EDGE-300|顶带公平调度` L2. The batch counter is reset to
`0/50` only after this gate is committed.

## Integrity

The gate did not change CODEX, anchor answers, alarm thresholds or algorithm, formal sequence,
five-level standard, or manual/forced queue semantics. P12's 400+ Journey requirement remains
deferred to phase 2 by explicit user decision.
