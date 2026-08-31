# EDGE-206 · ledger/alarm re-audit after UI fix

## Scope

This re-audit closes the `gap-too-fast` alarm opened after the post-fix L4/L5 judgments for
`朗读长度上限`. It does not erase the earlier red observation: the first real App session
showed a generic `Read-aloud failed` surface. The later judgments were written only after the
rebuilt App was reopened and the same boundary was observed again.

## Independent checks

- Re-read the post-fix AX snapshot from session
  `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-100536`: the over-limit action
  is labeled `Too long to read aloud in one go (maximum 4,000 characters)`.
- Re-read the finalized `screen.mov` and the emitted screenshot: the message actions remain
  aligned, the explanatory state is visible, and no failure toast appears after the click
  attempt.
- Re-read `backend.log`, `sse.jsonl`, `frontend.log`, and `llm.jsonl`: the sidecar is healthy,
  all three SSE streams connect and close cleanly, no Flutter/Dart application exception is
  present, and no `/v1/audio/speech` request is emitted by the disabled action.
- Re-ran the focused widget suite before the real-App recheck; all `35` tests passed,
  including the `4001`-rune disabled-and-explained case.

The short inter-judgment interval is therefore a ledger-review timing signal, not evidence that
the UI was rubber-stamped. The historical failure, implementation diff, focused regression, and
fresh five-channel session are all retained and cross-checkable.
