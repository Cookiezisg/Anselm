# EDGE-072 · approval 显式零时长

## Verification

The approval contract rejects an explicit zero duration before any approval entity is created.
The black-box contract scenario covers `0s` and the equivalent `0ms`, plus an invalid duration and
a non-empty timeout without `timeoutBehavior`; every case returns HTTP 422 with
`APPROVAL_INVALID_TIMEOUT`. The domain and application tests independently preserve the same
boundary, while `""` remains the documented never-timeout value.

## Focused evidence

```text
cd backend
mise exec -- go test ./internal/domain/approval ./internal/app/approval -count=1
ok  github.com/sunweilin/anselm/backend/internal/domain/approval
ok  github.com/sunweilin/anselm/backend/internal/app/approval

cd testend
mise exec -- go test ./scenarios \
  -run '^TestContractWorkflow_ApprovalTimeoutParsingAndRevert$' -count=1
ok  github.com/sunweilin/anselm/testend/scenarios
```

## Five-level applicability

- L1 pass: `0s`/`0ms`, malformed duration, and missing timeout behavior are rejected with the stable 422 error; no invalid approval is persisted.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.
