# EDGE-269 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/conversation -run '^TestDeleteWorkDir_(SoftDeletesAndCascades|NeverTouchesAMessageRow)$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/conversation -run '^TestDeleteWorkDir_(SoftDeletesAndCascades|NeverTouchesAMessageRow)$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGroups_DeleteWholeGroup$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGroups_DeleteWholeGroup$'` passed.
- The service and black-box checks confirm deletion crosses archive state, excludes pinned conversations, leaves message rows untouched, and does not mutate the filesystem.

## Applicability and scheduling

`EDGE-269` is a destructive user-visible group action. The remaining L2-L5 claims require a real desktop App and the five observation channels to judge confirmation, destructive feedback, visual treatment, and discoverability. They remain unfinished rather than being converted to `na` or `pass`, and the row is placed in the explicit manual queue under the user's instruction to defer forced interaction until the autonomous frontier is exhausted.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
