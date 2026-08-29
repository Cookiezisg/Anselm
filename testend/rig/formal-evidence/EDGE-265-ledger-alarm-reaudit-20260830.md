# EDGE-265 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/conversation -run '^TestUpdate_WorkDir(MountSwitchUnmount|NoopsAndAbsentKey)$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/conversation -run '^TestUpdate_WorkDir(MountSwitchUnmount|NoopsAndAbsentKey)$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDir_MidThreadSwitchLeavesADurableMarker$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDir_MidThreadSwitchLeavesADurableMarker$'` passed.
- The service and black-box checks confirm a mid-thread residency switch records the `from` and `to` paths in the durable workdir marker and keeps the persisted residency aligned with the projection.

## Applicability and scheduling

`EDGE-265` is a user-visible history marker. The remaining L2-L5 claims require a real desktop App and the five observation channels to judge how a reader sees the marker while reviewing the thread, including its visual treatment and discoverability. They remain unfinished rather than being converted to `na` or `pass`, and the row is placed in the explicit manual queue under the user's instruction to defer forced interaction until the autonomous frontier is exhausted.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
