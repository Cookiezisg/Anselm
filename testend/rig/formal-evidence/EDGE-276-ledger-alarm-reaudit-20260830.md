# EDGE-276 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/document -run '^TestCreate_ConcurrentPositionsDistinct$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/document -run '^TestCreate_ConcurrentPositionsDistinct$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestContractDocsAtt_DocumentChildrenDuplicateMove$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestContractDocsAtt_DocumentChildrenDuplicateMove$'` passed.
- The service test launches 20 same-parent creates concurrently and verifies distinct positions; the black-box scenario verifies position-ordered child pages and cursor continuation without gaps or duplicates.

## Applicability and scheduling

`EDGE-276` is a concurrency/data-order boundary with a user-visible ordering consequence. The service and black-box regressions establish the durable position contract, but L2-L5 still require a real desktop App and five channels to judge concurrent result ordering, list feedback, visual order, and discoverability. Keep the row unfinished and in the manual queue; do not convert missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
