# EDGE-283 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/infra/fs/skill -run '^(TestStore_Files_TraversalMatrix|TestStore_Files_SymlinkEscapeBlocked|TestIsInSkillsTree_SymlinkEscapeResolved)$'` passed.
- `mise exec -- go test -race -count=1 ./internal/infra/fs/skill -run '^(TestStore_Files_TraversalMatrix|TestStore_Files_SymlinkEscapeBlocked|TestIsInSkillsTree_SymlinkEscapeResolved)$'` passed.
- `mise exec -- go test -count=1 ./internal/app/skill -run '^(TestFiles_PassthroughChain|TestWriteFile_ManifestRoutesThroughValidation|TestDeleteFile_ManifestRefused)$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/skill -run '^(TestFiles_PassthroughChain|TestWriteFile_ManifestRoutesThroughValidation|TestDeleteFile_ManifestRefused)$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestContractKnowledge_SkillFilesSurface$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestContractKnowledge_SkillFilesSurface$'` passed.
- The matrix covers lexical traversal, absolute paths, backslashes, symlink escapes, manifest deletion, and API forwarding; no file escapes the skill root.

## Applicability and scheduling

`EDGE-283` is a security boundary with a user-visible file-operation refusal surface. Filesystem, service, and HTTP regressions establish the containment contract, but L2-L5 still require a real desktop App and five channels to judge blocking feedback, copy, visual craft, and discoverability. Keep the row unfinished and in the manual queue; do not convert missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
