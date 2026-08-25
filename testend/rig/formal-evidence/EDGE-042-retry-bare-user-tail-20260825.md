# EDGE-042 · retry 尾巴是无回答的 user 行

## Verification

The real chat service and real messages store were seeded with the crash shape where the process
died after the user row was committed but before an assistant row existed. Boot reconciliation ran,
then an empty retry payload produced the missing answer through the normal queue. The transcript
kept exactly one user and one assistant, the assistant had no fabricated `retryOf`, and the LLM
projection contained both the original question and recovered answer.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestRetry_(BareUserTailProducesTheMissingAnswer|Targets_PicksTheCurrentTailOnly|RegenerateSupersedesTheAnswerAndKeepsItReadable)$' -count=1 PASS
go test -race ./internal/app/chat -run 'TestRetry_BareUserTailProducesTheMissingAnswer' -count=1 PASS
go test ./internal/app/chat -count=1 PASS
```

## Five-level applicability

- L1 `pass`: a user-only crash tail naturally degrades retry into producing the missing answer without duplicate user/version metadata; measurement law `measure:edge042-retry-bare-user-tail`.
- L2 `na`: this round did not start a separate managed-gateway five-channel session for the crash-before-assistant branch.
- L3 `na`: focused/race verification has no independent App frame, SSE tap, backend journal, or frontend console observation.
- L4 `na`: this is crash recovery and transcript semantics, with no independent visual geometry, motion, or layout surface.
- L5 `na`: recovery is an existing retry action rather than a new navigation entry; its user-facing affordance is covered by chat/recovery journeys.
