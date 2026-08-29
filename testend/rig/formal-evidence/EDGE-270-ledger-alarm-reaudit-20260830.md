# EDGE-270 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/conversation -run '^TestWorkDirActions_RejectTheTwoUnnameableSpellings$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/conversation -run '^TestWorkDirActions_RejectTheTwoUnnameableSpellings$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGroups_ArchiveWholeGroup$'` passed; the scenario asserts `workDir:""` returns `400 INVALID_REQUEST`.
- The service and black-box checks confirm an empty workDir is rejected for batch archive/delete actions rather than being interpreted as the unmounted conversation group filter.

## Applicability and scheduling

`EDGE-270` is a user-visible blocked-action path. The remaining L2-L5 claims require a real desktop App and the five observation channels to judge the copy, feedback, visual treatment, and discoverability of that refusal. They remain unfinished rather than being converted to `na` or `pass`, and the row is placed in the explicit manual queue under the user's instruction to defer forced interaction until the autonomous frontier is exhausted.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
