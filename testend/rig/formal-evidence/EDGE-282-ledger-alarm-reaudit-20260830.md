# EDGE-282 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/skill -run '^(TestUpdateInstalled_DriftRefusalAndToolChangeResetsGate|TestUpdateInstalled_UnchangedToolsKeepApproval)$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/skill -run '^(TestUpdateInstalled_DriftRefusalAndToolChangeResetsGate|TestUpdateInstalled_UnchangedToolsKeepApproval)$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestSkillInstall_FullChain$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestSkillInstall_FullChain$'` passed.
- The update path refuses local drift without force, exposes the affected file, restores upstream content with force, resets approval when `allowed-tools` changes, and retains approval when it does not.

## Applicability and scheduling

`EDGE-282` is a user-visible update-conflict and trust-gate path. Service and HTTP regressions establish the durable safety behavior, but L2-L5 still require a real desktop App and five channels to judge conflict copy, recovery choice, visual craft, and discoverability. Keep the row unfinished and in the manual queue; do not convert missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
