# EDGE-003 · semantic compaction failure investigation

## Scope

This edge is an intentional fault-injection path inside the shared loop. Both semantic
compactors are forced to fail: the Host-provided utility compactor returns an error, and the
primary checkpoint LLM request returns a non-retryable invalid-request rejection. The loop must
still build a deterministic, explicitly lossy checkpoint and retry the same sampling step.

This is not a managed-gateway product journey. The deterministic checkpoint is an in-memory prompt
projection sent to the model; it is not rendered as a user-facing block, emitted as an SSE event,
or persisted as a database row. The neighboring real App/gateway path is recorded separately by
EDGE-002 and is not reused as false evidence for this injected branch.

## Reproduction and result

Focused regression added at
`backend/internal/app/loop/loop_test.go`:
`TestRun_ContextOverflowFallsBackToDeterministicCheckpointWhenSemanticCompactorsFail`.

The test scripts exactly three `Stream` calls:

1. The original request is rejected with `context_length`.
2. The primary semantic checkpoint request is rejected with `invalid_request`.
3. The same logical step is retried and completes with ordinary text.

Assertions prove all of the following:

- the utility compactor was called once and failed;
- the provider was called exactly three times, with no unbounded retry;
- the final result and durable finalize status are `completed`, with no leaked error code;
- the retry prompt contains the explicit
  `context_checkpoint kind="deterministic-emergency"` marker and the instruction to re-fetch
  omitted durable tool results;
- the newest complete assistant/tool group remains intact, including `new_call`.

Verification:

```text
cd backend && mise exec -- go test ./internal/app/loop ./internal/app/contextcheckpoint ./internal/app/contextmgr -count=1
→ PASS
```

## Five-level applicability

- L1 `pass`: the exact injected branch completes the active turn instead of exploding or exposing
  an intermediate compactor error. Law `H3` applies to the loop's fallback behavior.
- L2 `na`: this injected unit path has no UI, DB write, SSE frame, or real gateway wire. The test
  captures the provider request and loop result directly; using a real session here would combine
  different paths and violate the evidence rule.
- L3 `na`: no user-visible frame or timing surface exists for this prompt-only projection.
- L4 `na`: the checkpoint marker is model-facing protocol text, not a visual product surface.
- L5 `na`: there is no user entry point for deliberately failing both internal compaction providers;
  this is a resilience invariant, not a discoverability journey.

The `na` cells are scope classifications, not relaxed visual or product standards. If a future
product surface exposes this fallback or a real managed route can deterministically inject both
failures, this edge must be reopened with a complete five-channel session.
