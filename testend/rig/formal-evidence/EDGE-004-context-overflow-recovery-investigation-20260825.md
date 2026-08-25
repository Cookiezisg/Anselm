# EDGE-004 · authoritative context-length recovery investigation

## Scope

This edge covers the provider-authoritative rejection branch where no assistant block has been
emitted yet and the provider returns a structured `context_length` rejection. The loop must compact
the prompt, retry the same logical sampling step, and hide the recovery from the user.

## Verification

The existing focused regression
`backend/internal/app/loop/loop_test.go:TestRun_ProviderContextOverflowCompactsAndRetriesSameStep`
passed as part of:

```text
cd backend && mise exec -- go test ./internal/app/loop ./internal/app/contextcheckpoint ./internal/app/contextmgr -count=1
→ PASS
```

It asserts the exact zero-block rejection, an isolated checkpoint request with tools removed, a
smaller retry prompt containing a continuation checkpoint, exactly three provider calls, and a
completed final result with no leaked provider error.

The production HTTP/SSE path also passed:

```text
cd testend && mise exec -- go test ./scenarios \
  -run 'TestChat_CompactionWatermark$|TestPromptR6_PostCompactionView$' \
  -count=1 -parallel 1 -timeout 10m
→ PASS (5.197s)
```

Those scenarios prove the learned overflow budget, same-step recovery, durable rolling summary and
watermark, post-compaction model view, and complete recent protocol groups through the real server
HTTP/SSE boundary. The repository's real managed-gateway EDGE-002 session returned a 504 before this
branch; that observation remains red and is not reused as EDGE-004 evidence.

## Five-level applicability

- L1 `pass`: transparent same-step recovery completes without exposing the rejection. Law `H3`.
- L2 `na`: the exact injected provider rejection is exercised by the deterministic loop/testend
  harness, not by the real managed gateway; no five-channel App session can honestly be claimed for
  this forced branch.
- L3 `na`: the internal recovery has no distinct user-visible frame to measure.
- L4 `na`: checkpoint text is model-facing prompt protocol, not a visual product surface.
- L5 `na`: users cannot directly enter a state that forces both provider recovery internals; this is
  a resilience invariant rather than a discoverability journey.

These are explicit scope classifications, not relaxed acceptance thresholds. Reopen the edge if a
future controllable provider fault fixture is wired into the real App rig.
