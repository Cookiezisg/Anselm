# EDGE-287 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestChatR3_SkillScriptGuardSurface$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestChatR3_SkillScriptGuardSurface$'` passed.
- The real chat ReAct scenario submits a missing script and a traversal script; both are returned as bounded `script not found` tool results and neither enters execution.

## Applicability and scheduling

`EDGE-287` is a user-visible tool-input guard. The black-box regression establishes refusal and model feedback, but L2-L5 still require a real desktop App and five channels to judge unsupported-extension copy, blocking feedback, visual craft, and discoverability. Keep the row unfinished and in the manual queue; do not convert missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
