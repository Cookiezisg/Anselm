# EDGE-008 stop-and-fix · MAX_STEPS terminal UX

## Red finding

The loop already finalized an honest `MAX_STEPS_REACHED` error, but the Chat transcript's generic
terminal path appended the durable code and internal English detail after the amber label. The
result was diagnostic output instead of a clear answer to the user's next question: what can I do
now?

## Fix

The transcript now maps `MAX_STEPS_REACHED` to localized actionable copy. It explains that the
reply paused at the step limit and tells the user to send a follow-up or simplify the task. English
and Chinese resources are synchronized and generated. The primary transcript no longer exposes the
internal code or raw loop detail for this boundary.

## Verification

Focused widget regression:

```text
cd frontend && mise exec -- flutter test test/features/chat/ui/chat_transcript_test.dart \
  --plain-name 'loop terminal boundaries use actionable copy instead of internal codes'
→ PASS
```

The regression now covers `MAX_STEPS_REACHED`, `TOOL_ERROR_STORM`, and
`CONTEXT_INPUT_TOO_LARGE`; each asserts localized copy is present and the raw code/detail is absent.

```text
cd frontend && make analyze
→ No issues found

cd backend && mise exec -- go test ./internal/app/loop \
  -run 'TestRun_MaxStepsReached$|TestRun_ToolErrorStorm$' -count=1
→ PASS
```

## Five-level applicability

- L1 `pass`: the loop remains an honest non-success terminal and the user receives a concrete next
  action. Law `E1` applies.
- L2 `na`: this is a deterministic max-step harness boundary; no real five-channel App/gateway
  session is claimed for an artificially capped loop.
- L3 `na`: no real streaming session was injected, so there is no frame/timing record for this
  boundary.
- L4 `pass`: the actual transcript rendering path was fixed and locked by a focused widget
  regression. Law `E1` applies.
- L5 `na`: users do not navigate to a max-step state as a feature; it is a resilience boundary.
