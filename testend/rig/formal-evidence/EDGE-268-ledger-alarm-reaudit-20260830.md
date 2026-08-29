# EDGE-268 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/conversation -run '^TestArchiveWorkDir_ScopeAndCount$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/conversation -run '^TestArchiveWorkDir_ScopeAndCount$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGroups_ArchiveWholeGroup$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGroups_ArchiveWholeGroup$'` passed.
- The service and black-box checks confirm the first archive affects only the intended unpinned group, the repeated request returns `archived=0`, and the no-op does not emit a second lifecycle echo.

## Applicability and scheduling

`EDGE-268` is a user-visible group action. The remaining L2-L5 claims require a real desktop App and the five observation channels to judge confirmation, result feedback, visual treatment, and discoverability. They remain unfinished rather than being converted to `na` or `pass`, and the row is placed in the explicit manual queue under the user's instruction to defer forced interaction until the autonomous frontier is exhausted.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
