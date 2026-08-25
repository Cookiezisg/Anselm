# EDGE-037 · 归档对话发消息自动解档

## Verification

The chat service regression sends to an archived conversation and verifies `Unarchive` is
attempted before the turn proceeds. It covers both a successful flag flip and the soft-failure
case: even when unarchive returns an error, the user message and assistant turn still complete and
emit their terminal close. A failed archive-flag write therefore does not make the thread
unusable.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestSendArchivedConversationUnarchivesAndContinues' -count=1       PASS
go test -race ./internal/app/chat -run 'TestSendArchivedConversationUnarchivesAndContinues' -count=1 PASS
```

## Five-level applicability

- L1 `pass`: archived Send attempts unarchive and continues even when the flag update fails; measurement law `measure:edge037-archived-send-unarchive`.
- L2 `na`: this round did not start a separate managed-gateway five-channel session for archived-thread recovery.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this is conversation state/recovery behavior, with no independent visual geometry, motion, or layout surface.
- L5 `na`: auto-unarchive is an implicit chat behavior, not a distinct navigation entry; archive visibility is covered by conversation-list journeys.
