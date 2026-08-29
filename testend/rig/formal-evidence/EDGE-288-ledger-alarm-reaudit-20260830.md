# EDGE-288 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/skill -run '^(TestCreate_ForkRequiresAgent|TestCreate_ForkRejectsUnknownAgentType|TestActivate_Fork_NoRunner_Degrades|TestActivate_ForkRejectsLegacyUnknownTypeWithoutApplyingSkill)$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/skill -run '^(TestCreate_ForkRequiresAgent|TestCreate_ForkRejectsUnknownAgentType|TestActivate_Fork_NoRunner_Degrades|TestActivate_ForkRejectsLegacyUnknownTypeWithoutApplyingSkill)$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestContractKnowledge_SkillActivateSurface$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestContractKnowledge_SkillActivateSurface$'` passed.
- The tests cover missing runner, missing agent, unsupported agent type, and activation refusal without applying a partially valid fork skill.

## Applicability and scheduling

`EDGE-288` is a user-visible capability-availability path. Service and HTTP regressions establish explicit failure semantics, but L2-L5 still require a real desktop App and five channels to judge unavailable-capability feedback, copy, visual craft, and discoverability. Keep the row unfinished and in the manual queue; do not convert missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
