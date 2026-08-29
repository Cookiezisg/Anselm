# EDGE-272 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/conversation -run '^TestWorkDirGroups_'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/conversation -run '^TestWorkDirGroups_'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGroups_CountsDoNotDriftAcrossPaging$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGroups_CountsDoNotDriftAcrossPaging$'` passed.
- The black-box scenario creates a group spanning multiple pages, re-reads the projection after every page, and confirms the count remains identical while the pages enumerate exactly that count.

## Applicability and scheduling

`EDGE-272` is a user-visible rail behavior. The service and black-box regressions establish the durable projection contract, but L2-L5 still require the real desktop App and five channels to judge scrolling feedback, visual stability, hierarchy, and discoverability. Keep the row unfinished and in the manual queue; do not convert the missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
