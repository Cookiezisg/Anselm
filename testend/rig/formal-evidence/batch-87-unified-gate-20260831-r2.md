# Batch 87 unified gate · 2026-08-31 · r2

## Scope

This is the current close-out for batch 87 after `EDGE-239|CHECK 加词整表重建`.
The earlier `batch-87-unified-gate-20260831.md` remains a historical snapshot at
`60/50`; this record supersedes its ledger counts without rewriting history. The
gate did not touch `EDGE-236|父进程死人开关`, the forced/manual queue, or the deferred
400+ Journey expansion.

## Required checks

| Check | Result | Recorded fact |
|---|---|---|
| Root verification | PASS | `make verify`; backend, frontend, docs and web demo all passed |
| Full black-box testend | PASS | `make -C backend testend`; `testend/scenarios` passed in `357.515s` |
| Rig unit tests | PASS | `python3 -m unittest discover -s testend/rig -p 'test_*.py' -q`; `70/70` |
| Proxy/wire race tests | PASS | `go test ./harness/proxycore ./cmd/llmtap -count=1 -race` |
| Go format audit | PASS | all `backend` and `testend` Go files formatted |
| Dart format/analyze | PASS | frontend format, generation and analyze passed; `17/17` targeted startup tests passed |
| Coverage regeneration | PASS | `gen_coverage.py --check`: `848 rows, 848 carried judgments, 0 tombstones` |
| Alarm drift gate | PASS | `alarms.py check`: `125 live judgments`, `4240` baseline judgments excluded |
| Anchor calibration | PASS | `10/10` anchors; judge unlocked for 4h |
| Script/whitespace audit | PASS | `py_compile`, `bash -n`, `gofmt -l`, `git diff --check` all passed |
| Owned-process audit | PASS | no conductor-owned App/backend/tap/recorder/embedder remains |

## EDGE-239 evidence

The real desktop session is
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-162419`. It booted a
real App from an old SQLite schema and verified that migration restored the three
CHECK marker words, preserved rows and indexes, and left both SQLite integrity
checks clean. The valid fixture was inside the App container; an earlier
`/private/tmp` attempt was rejected by the macOS App sandbox and is explicitly not
counted as product evidence.

Formal evidence:
`EDGE-239-check-rebuild-migration-real-app-20260831.md`.

The five-level ledger result is `L2=F1/L3=na/L4=na/L5=na`. The three `na` entries
are applicability boundaries for an internal boot migration with no independent
user action, visual object, or discoverable entry; they are not waivers. The
independent ledger re-audit is
`EDGE-239-ledger-alarm-reaudit-real-app-20260831.md`.

## Ledger state

The authoritative matrix is `848` rows: `735` fully settled and `113` open;
`3868/4240` cells are settled and `372` remain open. `manual_queue=173` and
`forced_queue=26`. The active autonomous frontier is
`EDGE-240|ADD COLUMN 结果幂等`; `EDGE-236` remains in the forced human tail.
Batch 87 is at `69/50`.

## Integrity

The alarm thresholds and algorithm, CODEX, anchor answers, five-level standard,
formal sequence, and queue semantics were not changed. This gate stages only
acceptance evidence, working-record updates, the recorder/conductor fixes, and
the scoped startup failure fix; unrelated worktree changes from the other team
remain unstaged.
