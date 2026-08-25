# EDGE-003 ledger/alarm re-audit · 2026-08-25

## Trigger

Writing the five EDGE-003 cells in one controlled batch opened `gap-too-fast` and
`discovery-collapse`. The alarm thresholds and the ledger gate were not changed.

## Evidence review

- Re-read `testend/rig/formal-evidence/EDGE-003-deterministic-checkpoint-investigation-20260825.md`.
- Re-ran:
  `cd backend && mise exec -- go test ./internal/app/loop ./internal/app/contextcheckpoint ./internal/app/contextmgr -count=1`.
- The focused regression passed and proves the exact fault sequence: utility failure, primary
  checkpoint failure, deterministic emergency checkpoint, same-step completion.
- The four `na` cells are explicit scope classifications, not silent passes: this branch has no
  UI/DB/SSE/real-gateway surface, so L2–L5 cannot honestly borrow EDGE-002's real App session.
- `gen_coverage.py --check` reports 848 rows, 500 carried judgments, and zero tombstones.
- No CODEX law, anchor set, alarm threshold, sequence policy, or evidence requirement was relaxed.

## Resolution

This is a legitimate small judgment batch with one mechanism-level pass and four mechanically
justified non-applicable levels. Keep the alarms' statistical signal intact, acknowledge only this
reviewed interval, and reopen the edge if a future product surface exposes deterministic fallback
as a user-visible path.
