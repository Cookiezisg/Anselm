# EDGE-007 stop-and-fix · loop terminal error UX

## Red finding

Static inspection of the real Chat transcript terminal banner found that only
`LLM_PROVIDER_ERROR` was mapped to user copy. `TOOL_ERROR_STORM` and
`CONTEXT_INPUT_TOO_LARGE` would otherwise render their durable error code and internal provider
message directly in the main transcript, violating CODEX E1's three-part human error rule.

## Fix

The transcript now maps both loop terminal codes to localized, actionable copy:

- `TOOL_ERROR_STORM`: explains that the reply was paused after repeated tool failures and tells the
  user to check inputs and retry.
- `CONTEXT_INPUT_TOO_LARGE`: explains that the content is too large for one model request and tells
  the user to split the newest attachment or content and retry.

English and Chinese slang resources and generated locale files are synchronized. No internal code
or raw error detail is shown in the primary transcript line.

## Verification

Focused widget regression:

```text
cd frontend && mise exec -- flutter test test/features/chat/ui/chat_transcript_test.dart \
  --plain-name 'loop terminal boundaries use actionable copy instead of internal codes'
→ PASS
```

`make -C frontend analyze` → `No issues found`.

The existing loop regressions for `TOOL_ERROR_STORM` and `CONTEXT_INPUT_TOO_LARGE` also pass. The
prior EDGE-005 L4 `na` classification is explicitly revalidated with `judge.py --revalidate` after
this fix; the old `na` pointer remains in the evidence field as history and the new pass pointer
records the corrected product surface.
