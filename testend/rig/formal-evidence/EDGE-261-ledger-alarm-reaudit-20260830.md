# EDGE-261 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/conversation -run '^TestAddWorktree_ExistingDirectoryIsRefusedAndExistingBranchIsReused$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/conversation -run '^TestAddWorktree_ExistingDirectoryIsRefusedAndExistingBranchIsReused$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGit_WorktreeOneShot$'` passed.
- The service and black-box checks confirm the existing sibling directory is refused with `CONVERSATION_WORKTREE_EXISTS`, `details.path` names the blocking directory, residency remains unchanged, and no second workdir marker is written.

## Applicability and scheduling

`EDGE-261` is a user-visible worktree collision. The remaining L2-L5 claims require a real desktop App and the five observation channels to judge the error feedback, visual treatment, and discoverability. They remain unfinished rather than being converted to `na` or `pass`, and the row is placed in the explicit manual queue under the user's instruction to defer forced interaction until the autonomous frontier is exhausted.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is `EDGE-262|worktree 分支已存在`.
