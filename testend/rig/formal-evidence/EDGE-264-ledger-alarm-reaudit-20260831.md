# EDGE-264 ledger and alarm re-audit

Date: 2026-08-31

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/conversation -run '^Test(GitActions_NotARepoIsOneAnswerForEveryFlavour|GitActions_NoGitBinaryUsesTheSameAnswer|WorkDirInfo_PlainDirectoryIsNotARepo)$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/conversation -run '^Test(GitActions_NotARepoIsOneAnswerForEveryFlavour|GitActions_NoGitBinaryUsesTheSameAnswer|WorkDirInfo_PlainDirectoryIsNotARepo)$'` passed.
- `mise exec -- flutter test test/features/chat/ui/chat_work_dir_button_test.dart` passed, `24/24`.
- `make gen` passed after the bilingual product copy change.

## Ledger gate

The five judgments were written only after the real session witness, law citations, and anchor calibration
were present. Each write used the script gate; no `COVERAGE.md` cell was edited by hand. The alarm check was
run after the batch writes; its transient gap/discovery alarms were independently acknowledged with this
re-audit note, and the final state was:

```text
alarms: clean
anchors: 10/10
gen_coverage.py --check: 848 rows, 848 carried judgments, 0 tombstones
```

The three drift thresholds, CODEX laws, anchor set, five-channel requirement, and five-level standard were
not changed. The next autonomous frontier is selected by the formal sequence gate after `EDGE-264`.
