# Batch 87 unified gate · 2026-08-31

## Scope

Batch 87 crossed the required 50-cell threshold at `56/50`. The final cells were
`EDGE-210|免费档配额耗尽` and `EDGE-234|三步优雅关停`, both completed through the
real-App stop-and-fix path before this gate. The gate does not touch the forced queue,
the 400+ Journey deferral, or any acceptance threshold.

## Product evidence sealed in this batch

- `EDGE-210` used two fresh real-App sessions against the managed gateway line. The
  llmtap fault was deliberately limited to the chat completion: one HTTP `402
  QUOTA_EXHAUSTED` and one HTTP `200` stream carrying `BUDGET_EXHAUSTED`; challenge,
  install, models and other gateway traffic remained real. The first run exposed raw
  provider diagnostics in the transcript; the stop-and-fix replaced them with actionable
  bilingual quota copy and a `Settings → Models & keys` route. No real gateway quota
  exhaustion is claimed.
- `EDGE-234` used a real App session with three resident SSE streams. Shutdown cancelled
  the request context before HTTP shutdown, all three streams reached clean EOF, backend
  graceful shutdown completed, and conductor-owned processes exited without SIGKILL
  escalation. L5 was explicitly recorded as not applicable because this internal
  lifecycle action has no user-discoverable feature surface.
- Both items retained red evidence where the first observation was invalid or defective;
  no failed observation was overwritten by a green claim. Independent ledger/alarm
  re-audits are `EDGE-210-ledger-alarm-reaudit-fixed-real-app-20260831.md` and
  `EDGE-234-ledger-alarm-reaudit-real-app-20260831.md`.

## Required checks

| Check | Result | Recorded fact |
|---|---|---|
| Root verification | PASS | `make verify`; backend, frontend, docs and demo all passed |
| Full black-box testend | PASS | `make -C backend testend`; acceptance scenarios passed, `317.372s`, exit 0 |
| Rig unit tests | PASS | `python3 -m unittest discover -s testend/rig -p 'test_*.py' -q`; 70 tests |
| Proxy/wire tests | PASS | `mise exec -- go test ./cmd/llmtap ./harness/proxycore -count=1 -race -v` |
| Go formatting | PASS | `gofmt -l` returned no files for touched llmtap sources |
| Script/whitespace audit | PASS | `py_compile`, `bash -n` for rig scripts, and `git diff --check` |
| Coverage regeneration | PASS | `gen_coverage.py --check`: 848 rows, 848 carried judgments, 0 tombstones |
| Alarm drift gate | PASS | `alarms.py check`: 109 live judgments, 4240 baseline judgments excluded |
| Anchor calibration | PASS | `anchors.py check`: 10/10 anchors; judge unlocked for 4h |
| Process cleanup | PASS | no conductor-owned App/backend/tap/recorder/testend process remained |

## Ledger state after gate

The authoritative matrix is `848` rows: `731` fully settled and `117` open; `3852`
cells are settled and `388` remain open. `forced_queue=25` remains untouched. The next
autonomous frontier is `EDGE-235|关停预算格`; user-forced interactions remain deferred
to the final manual phase.

## Integrity

The gate did not change the CODEX, anchor answers, alarm thresholds/algorithm, formal
sequence, five-level standard, or forced/manual queue semantics. The gate records the
current working state only; the current working tree also contains unrelated changes
from the other team, which must not be included in the acceptance commit.
