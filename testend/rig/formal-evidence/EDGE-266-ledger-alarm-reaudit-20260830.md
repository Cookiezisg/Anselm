# EDGE-266 ledger and alarm re-audit

Date: 2026-08-30

## Regression evidence

- `mise exec -- go test -count=1 ./internal/app/conversation -run '^TestUpdate_WorkDirNoopsAndAbsentKey$'` passed.
- `mise exec -- go test -race -count=1 ./internal/app/conversation -run '^TestUpdate_WorkDirNoopsAndAbsentKey$'` passed.
- `mise exec -- go test -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDir_MidThreadSwitchLeavesADurableMarker$'` passed.
- `mise exec -- go test -race -count=1 -timeout 5m ./scenarios -run '^TestChatWorkDir_MidThreadSwitchLeavesADurableMarker$'` passed.
- The service and black-box checks confirm a first mount on a silent thread and a repeated PATCH of the same path produce no marker or lifecycle action, while the later mid-thread switch still does.

## Applicability and scheduling

`EDGE-266` is a user-visible no-op boundary. The remaining L2-L5 claims require a real desktop App and the five observation channels to judge whether the absence of a marker and feedback for a no-op is clear, stable, visually correct, and discoverable. They remain unfinished rather than being converted to `na` or `pass`, and the row is placed in the explicit manual queue under the user's instruction to defer forced interaction until the autonomous frontier is exhausted.

The alarm ledger was not used to waive this row. Existing alarm rules, thresholds, anchor set, sequence gate, five-level standard, and evidence requirements remain unchanged. The next autonomous frontier is determined by the sequence gate after this queue entry.
