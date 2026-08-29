# EDGE-267 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/conversation -run '^TestSwitchBranch_MovesTheHeadAndRepromsTheProjection$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/conversation -run '^TestSwitchBranch_MovesTheHeadAndRepromsTheProjection$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGit_SwitchBranchMovesTheProjectionAndDirtyIsRefused$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGit_SwitchBranchMovesTheProjectionAndDirtyIsRefused$'` passed.
- The service and black-box checks confirm branch switching updates the live Git projection while leaving the residency unchanged and writing no workdir marker.

## Applicability and scheduling

`EDGE-267` is a user-visible branch action boundary. The remaining L2-L5 claims require a real desktop App and the five observation channels to judge the post-switch feedback, visual treatment, and discoverability. They remain unfinished rather than being converted to `na` or `pass`, and the row is placed in the explicit manual queue under the user's instruction to defer forced interaction until the autonomous frontier is exhausted.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
