# EDGE-275 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/document -run '^TestValidate$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/document -run '^TestValidate$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestContractDocsAtt_DocumentNameGuardsSoftDelete$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestContractDocsAtt_DocumentNameGuardsSoftDelete$'` passed.
- The focused service test rejects content above `documentdomain.MaxContentBytes`; the black-box scenario sends `1<<20+1` bytes and verifies `413 DOCUMENT_CONTENT_TOO_LARGE`, with no automatic split.

## Applicability and scheduling

`EDGE-275` is a user-visible document-editor refusal path. The service and black-box regressions establish the hard size boundary, but L2-L5 still require a real desktop App and five channels to judge the editor feedback, copy, visual treatment, and discoverability. Keep the row unfinished and in the manual queue; do not convert missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
