# EDGE-306 L4 账本与警报独立复审

## Trigger

Writing the strict L4 pass opened `discovery-collapse`: the last 50 live judgments contained no
`fail`. The alarm is an intentional anti-drift control, not a product verdict. No threshold,
algorithm, anchor, or gate was changed.

## Independent re-audit

- Re-read the retained red evidence `EDGE-306-live-ghost-cleanup-l4-red-20260901.md`; it records the
  stale `Live` transcript and Activity rows after the result-close gap.
- Re-read the fixed evidence `EDGE-306-live-ghost-cleanup-l4-real-app-20260901.md`; it records a
  separate real App run with the same long chain, a window-owned recording, backend journal, three
  SSE streams, frontend journal, LLM wire, and the strict proxy `drop -> 410 -> forward`.
- Confirmed the final AX tree and extracted final frame contain no `Live`, `Creating document...`, or
  `Listening live` row, while the eight documents and the exact read-back body remain visible.
- Confirmed focused `conversation_stream_provider_test.dart` and the existing stage-director resync
  test pass. The new pass cites `C4`, which exists in `CODEX.md`, and its evidence file is non-empty.
- `anchors.py check` remains valid; the gate wrote exactly one new L4 judgment and did not rewrite the
  prior red evidence or alter alarm policy.

## Disposition

The zero-failure window is explained by the campaign's current clean acceptance run plus the retained
independent red observation; it is not evidence that discovery work stopped. The alarm was acknowledged
with this re-audit note. A future failure or an unexplained short judgment interval will reopen the same
alarm automatically.
