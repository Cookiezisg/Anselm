# EDGE-286 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/skill -run '^(TestActivate_PreambleOnlyWhenBundledFilesExist|TestActivate_SkillDirPlaceholderSubstituted|TestMentionResolver_RendersBodyWithDirAnchor)$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/skill -run '^(TestActivate_PreambleOnlyWhenBundledFilesExist|TestActivate_SkillDirPlaceholderSubstituted|TestMentionResolver_RendersBodyWithDirAnchor)$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestContractKnowledge_SkillDirAnchor$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestContractKnowledge_SkillDirAnchor$'` passed.
- The service and HTTP tests cover the single-file no-preamble case, bundled-file directory preamble, `${CLAUDE_SKILL_DIR}` substitution, and the shared agent Guide path.

## Applicability and scheduling

`EDGE-286` is a user-visible progressive-disclosure and guidance surface. Service and HTTP regressions establish the rendering contract, but L2-L5 still require a real desktop App and five channels to judge copy, visual craft, timing, and discoverability. Keep the row unfinished and in the manual queue; do not convert missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
