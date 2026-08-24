# SURF-090 ledger and alarm re-audit

Date: 2026-08-25

## Scope

- Five SURF-090 cells were written serially only after the real App stop-and-fix rerun:
  `G1/F1/B2/C4/G1`.
- Green session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-044311`.
- First real AX session states in the same work sequence were not judged until the composer semantics boundary was rebuilt and the AX tree exposed the attachment state/action nodes.

## Alarm findings

- `gap-too-fast`: the five ledger appends are serialization after a 363.483333s real App observation, not five unobserved product decisions. The session contains the window recording, backend journal, SSE tap, frontend journal, and LLM wire; the focused Flutter suite is `36/36`.
- `discovery-collapse`: the trailing 50 judgments contain no fail verdict. This is not accepted as evidence that the product is defect-free: SURF-090 itself includes a real red finding (visible attachment chip absent from native AX), a code fix, three rebuilt App attempts, and a re-audit record. The failed fixture's decode WARNs are intentional expected negative-path evidence, not hidden application failures.
- Anchor calibration was rerun against the frozen set and passed `10/10`. No threshold, curve, CODEX law, anchor answer, or ledger gate was changed.

## Resolution

Ack both alarms with this file. The alarms are statistical signals from legitimate batched ledger serialization and a trailing window with no fail verdict; they do not justify lowering the acceptance standard.
