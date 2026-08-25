# EDGE-006 · DeepSeek active reasoning/tool chain boundary

## Scope

DeepSeek-compatible routes carry `reasoning_content` and tool calls in the same assistant
message. Prompt compaction must cut only before a complete assistant/tool group, preserving the
active assistant reasoning, provider signature, tool-call id, and paired tool result.

## Verification

Added regression:
`backend/internal/app/loop/loop_test.go:TestDeterministicCheckpointKeepsDeepSeekReasoningToolGroupIntact`.

It builds an older group plus an active DeepSeek-like group, runs the deterministic emergency
checkpoint with one group retained, and asserts the output is exactly one marker plus the complete
active group. The active assistant keeps `reasoning_content`, `reasoningSignature`, tool name,
arguments and `active_call`; the following tool message remains paired and exact. Existing
DeepSeek build/request/parse/round-trip tests were run in the same focused command.

Verification:

```text
cd backend && mise exec -- go test ./internal/app/loop ./internal/infra/llm \
  -run 'TestDeterministicCheckpointKeepsDeepSeekReasoningToolGroupIntact$|TestDeepSeek.*$|TestRun_ProviderContextOverflowCompactsAndRetriesSameStep$|TestRun_ContextOverflowFallsBackToDeterministicCheckpointWhenSemanticCompactorsFail$|TestRun_ContextOverflowStillTooLargeUsesActionableTerminalCode$' \
  -count=1
→ PASS
```

## Five-level applicability

- L1 `pass`: the active provider protocol remains valid and complete at the compaction boundary.
  Measurement `measure:deepseek-active-tool-group` applies.
- L2 `na`: this is an in-memory prompt protocol regression; it does not emit UI/DB/SSE or use a
  real managed gateway session.
- L3 `na`: no user-visible frame or timing surface exists for the prompt projection.
- L4 `na`: reasoning/tool protocol is model-facing, not a visual product surface.
- L5 `na`: users cannot navigate to a “split active provider protocol” state; this is a provider
  compatibility invariant, not a discoverability journey.

The non-applicable cells are explicit scope decisions. Reopen the edge if a real App route exposes
DeepSeek compaction as a user-visible surface.
