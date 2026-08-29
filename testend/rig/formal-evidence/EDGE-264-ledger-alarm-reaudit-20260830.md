# EDGE-264 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/conversation -run '^TestGitActions_NotARepoIsOneAnswerForEveryFlavour$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/conversation -run '^TestGitActions_NotARepoIsOneAnswerForEveryFlavour$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGit_NotARepoWriteActions$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDirGit_NotARepoWriteActions$'` passed.
- The service and black-box checks confirm that unmounted, missing, and plain-directory residencies give all three write actions the same `CONVERSATION_WORK_DIR_NOT_GIT_REPO` response.

## Applicability and scheduling

The “no Git executable” environment variant was not fabricated on this host and is not claimed as a live run. `EDGE-264` remains a user-visible error path: the remaining L2-L5 claims require a real desktop App and the five observation channels to judge the error copy, recovery guidance, visual treatment, and discoverability. They remain unfinished rather than being converted to `na` or `pass`, and the row is placed in the explicit manual queue under the user's instruction to defer forced interaction until the autonomous frontier is exhausted.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
