# EDGE-274 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/conversation -run '^Test(DeleteWorkDir_SoftDeletesAndCascades|DeleteWorkDir_NeverTouchesAMessageRow)$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/conversation -run '^Test(DeleteWorkDir_SoftDeletesAndCascades|DeleteWorkDir_NeverTouchesAMessageRow)$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGroups_DeleteWholeGroup$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGroups_DeleteWholeGroup$'` passed.
- The service test preserves `messages` and `message_blocks` after the conversation tombstone; the black-box scenario verifies the deleted conversation and its message endpoint both answer `404 CONVERSATION_NOT_FOUND` while a pinned survivor remains readable.

## Applicability and scheduling

`EDGE-274` is a user-visible deleted-thread/deep-link behavior. The service and black-box regressions establish the tombstone and physical-log contract, but L2-L5 still require a real desktop App and five channels to judge the tombstone presentation, feedback, visual treatment, and discoverability. Keep the row unfinished and in the manual queue; do not convert missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
