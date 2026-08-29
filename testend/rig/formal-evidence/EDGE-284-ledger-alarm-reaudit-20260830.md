# EDGE-284 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/skill -run '^TestDeleteFile_ManifestRefused$'` passed as part of the skill file-service regression.
- `mise exec -- go test -race -count=1 ./internal/app/skill -run '^TestDeleteFile_ManifestRefused$'` passed as part of the skill file-service regression.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestContractKnowledge_SkillFilesSurface$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestContractKnowledge_SkillFilesSurface$'` passed.
- The manifest delete is rejected with `SKILL_FILE_PATH_INVALID`; the skill remains intact and deletion must use the skill resource endpoint.

## Applicability and scheduling

`EDGE-284` is a user-visible destructive-action guard. Service and HTTP regressions establish that the manifest cannot be deleted through the file surface, but L2-L5 still require a real desktop App and five channels to judge blocking feedback, correct-entry guidance, visual craft, and discoverability. Keep the row unfinished and in the manual queue; do not convert missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
