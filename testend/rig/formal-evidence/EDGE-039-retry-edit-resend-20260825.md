# EDGE-039 · `:retry` 编辑重发分支

## Verification

The non-empty retry payload supersedes both the original user turn and its assistant answer,
lands one edited user turn carrying the original attachment ids, and generates the replacement
answer. Durable history keeps all versions while the LLM projection contains only the edited round;
the edited user turn intentionally does not inherit the old @-mention snapshot.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestRetry_EditResendReplacesBothHalves' -count=1       PASS
go test -race ./internal/app/chat -run 'TestRetry_EditResendReplacesBothHalves' -count=1 PASS
```

## Five-level applicability

- L1 `pass`: edit-resend replaces both halves, preserves attachment identity, and projects only the edited round to the model; measurement law `measure:edge039-retry-edit-resend`.
- L2 `na`: this round did not start a separate managed-gateway five-channel session for edit-resend.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this is versioned chat/attachment persistence, with no independent visual geometry, motion, or layout surface.
- L5 `na`: edit-resend is a chat action rather than a distinct navigation entry; version/attachment feedback is covered by chat journeys.
