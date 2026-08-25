# EDGE-005 · CONTEXT_INPUT_TOO_LARGE terminal boundary

## Scope

This edge covers the honest terminal state after automatic context recovery still cannot make the
newest indivisible input fit. The loop must stop with `CONTEXT_INPUT_TOO_LARGE`, preserve the
provider cause, and tell the user to split the newest attachment/content rather than claiming a
successful answer or exposing a generic stream error.

## Verification

Added regression:
`backend/internal/app/loop/loop_test.go:TestRun_ContextOverflowStillTooLargeUsesActionableTerminalCode`.

The deterministic stream is:

1. original sampling receives a structured `context_length` rejection;
2. checkpoint generation succeeds;
3. the same-step retry receives `context_length` again;
4. the bounded second recovery check runs and the loop terminates.

The test proves the actual four-call bounded protocol, terminal `error` status, matching result and
finalize error code `CONTEXT_INPUT_TOO_LARGE`, and a non-empty message containing both the
indivisible-input explanation and split guidance.

Verification:

```text
cd backend && mise exec -- go test ./internal/app/loop ./internal/infra/llm \
  -run 'TestRun_ContextOverflowStillTooLargeUsesActionableTerminalCode$|TestRun_ProviderContextOverflowCompactsAndRetriesSameStep$|TestRun_ContextOverflowFallsBackToDeterministicCheckpointWhenSemanticCompactorsFail$|TestAnselmInStreamContextRejectedIsRecoverable$' \
  -count=1
→ PASS
```

## Five-level applicability

- L1 `pass`: the user-facing outcome is an honest, actionable terminal boundary rather than a fake
  success. Law `E1` applies to the required explanation and next action.
- L2 `na`: the exact repeated rejection is deterministic harness injection; no real managed-gateway
  five-channel session can be claimed for it.
- L3 `na`: this internal terminal classification has no distinct frame/timing surface in the test.
- L4 `na`: the regression asserts the durable error contract, not a rendered UI frame; the real
  provider-error visual surface is covered by EDGE-001.
- L5 `na`: users cannot directly choose an indivisible provider rejection state; it is a resilience
  boundary, not a discoverability journey.

These `na` cells preserve the acceptance standard by refusing to invent visual evidence. Reopen the
edge if a controllable real-provider fault fixture becomes part of the App rig.

## Revalidation after EDGE-007 stop-and-fix

The initial L4 `na` was correct for the original wire-only evidence, but a later product review
found that the real transcript banner would expose this durable code if the path reached the App.
EDGE-007 fixed that leak with localized actionable copy and a focused widget regression. The old L4
classification was revalidated with `judge.py --revalidate --law E1` against
`EDGE-007-loop-terminal-error-ux-stop-fix-20260825.md`; the current row is
`L1=pass,L2=na,L3=na,L4=pass,L5=na`.
