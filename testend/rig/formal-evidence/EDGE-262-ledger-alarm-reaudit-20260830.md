# EDGE-262 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/conversation -run '^TestAddWorktree_ExistingDirectoryIsRefusedAndExistingBranchIsReused$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/conversation -run '^TestAddWorktree_ExistingDirectoryIsRefusedAndExistingBranchIsReused$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGit_ReusesExistingBranch$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGit_(WorktreeOneShot|ReusesExistingBranch)$'` passed.
- The service and black-box checks confirm an existing `wt/<name>` branch is reused, the worktree is created at the flat sibling derived from the main repository, and the conversation residency moves to that worktree.

## Applicability and scheduling

`EDGE-262` is a user-visible recovery path. The remaining L2-L5 claims require a real desktop App and the five observation channels to judge the recovery feedback, visual treatment, and discoverability. They remain unfinished rather than being converted to `na` or `pass`, and the row is placed in the explicit manual queue under the user's instruction to defer forced interaction until the autonomous frontier is exhausted.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
