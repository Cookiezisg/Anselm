# EDGE-278 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/document -run '^TestMove_CycleGuard$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/document -run '^TestMove_CycleGuard$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestContractDocsAtt_DocumentChildrenDuplicateMove$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestContractDocsAtt_DocumentChildrenDuplicateMove$'` passed.
- The service test rejects moving a root below its own child with `ErrInvalidParent`; the black-box contract rejects self-parent, descendant-parent, and unknown-parent moves without mutating the tree.

## Applicability and scheduling

`EDGE-278` is a user-visible document-tree guard. The service and black-box regressions establish the durable refusal and no-mutation contract, but L2-L5 still require a real desktop App and five channels to judge blocking feedback, copy, visual stability, and discoverability. Keep the row unfinished and in the manual queue; do not convert missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
