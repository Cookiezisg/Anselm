# EDGE-271 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/conversation -run '^TestWorkDirActions_AreAllOrNothing$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/conversation -run '^TestWorkDirActions_AreAllOrNothing$'` passed.
- The focused test covers archive and delete, both an `RAISE(ABORT)` row error and an `RAISE(IGNORE)` silent skip; the service returns an error and leaves every row, broadcast, and relation cascade unchanged.

## Applicability and scheduling

`EDGE-271` is a transaction-atomicity implementation seam. It has no independent durable user state, interaction timing, visual surface, or discoverability entry: those product claims belong to the batch archive/delete journeys already held for real App observation. L2-L5 are therefore explicitly not applicable, rather than missing verification.

The alarm ledger was not used to waive this result. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this row is settled.
