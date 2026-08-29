# EDGE-277 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/document -run '^TestUpdate_PathCascade$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/document -run '^TestUpdate_PathCascade$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestContractDocsAtt_DocumentNameGuardsSoftDelete$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestContractDocsAtt_DocumentNameGuardsSoftDelete$'` passed.
- The service test verifies the renamed root and descendant path; the black-box document contract includes rename-to-descendant path cascade coverage.

## Applicability and scheduling

`EDGE-277` is a user-visible document-tree path behavior. The service and black-box regressions establish the durable cascade, but L2-L5 still require a real desktop App and five channels to judge Library refresh, path feedback, visual stability, and discoverability. Keep the row unfinished and in the manual queue; do not convert missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
