# EDGE-273 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/infra/store/conversation -run '^TestList_'` passed.
- `mise exec -- go test -race -count=1 ./internal/infra/store/conversation -run '^TestList_'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGroups_ListFilters$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGroups_ListFilters$'` passed.
- The black-box scenario verifies absent `workDir`, present-empty `workDir`, concrete `workDir`, and pinned/unpinned partitions; the sections together enumerate each conversation exactly once.

## Applicability and scheduling

`EDGE-273` is a user-visible rail filtering behavior. The store and black-box tests establish the presence semantics, but L2-L5 still require a real desktop App and five channels to judge filter transitions, empty-state feedback, visual stability, and discoverability. Keep the row unfinished and in the manual queue; do not convert missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
