# EDGE-263 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/conversation -run '^TestAddWorktree_(TheOneShot|UpdateFailureLeavesAnHonestHalfState|ExistingDirectoryIsRefusedAndExistingBranchIsReused)$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/conversation -run '^TestAddWorktree_(TheOneShot|UpdateFailureLeavesAnHonestHalfState|ExistingDirectoryIsRefusedAndExistingBranchIsReused)$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGit_WorktreeOneShot$'` passed.
- The failure-injection test confirms that when the final residency persistence fails, the already-created worktree remains on disk, no success projection is returned, and the conversation row remains on its previous residency.

## Applicability and scheduling

`EDGE-263` is a user-visible partial-failure path. The remaining L2-L5 claims require a real desktop App and the five observation channels to judge the error message, recovery guidance, visual treatment, and discoverability. They remain unfinished rather than being converted to `na` or `pass`, and the row is placed in the explicit manual queue under the user's instruction to defer forced interaction until the autonomous frontier is exhausted.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
