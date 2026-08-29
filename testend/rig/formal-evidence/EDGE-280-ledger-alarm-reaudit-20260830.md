# EDGE-280 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/agent -run '^(TestCreateEdit_RejectsDanglingMounts|TestMountHealth_CoversKnowledge)$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/agent -run '^(TestCreateEdit_RejectsDanglingMounts|TestMountHealth_CoversKnowledge)$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestAgentR2_DeletedKnowledgeFailsFast$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestAgentR2_DeletedKnowledgeFailsFast$'` passed.
- The black-box test creates an agent with a valid knowledge document, deletes that document, then invokes the agent; the invocation is `failed` with explicit missing-document information and consumes zero agent-model requests.

## Applicability and scheduling

`EDGE-280` is a user-visible agent failure path. Service and HTTP regressions establish the fail-fast and no-LLM-request contract, but L2-L5 still require a real desktop App and five channels to judge the error feedback, copy, visual craft, and discoverability. Keep the row unfinished and in the manual queue; do not convert missing product observation into `na` or `pass`.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
