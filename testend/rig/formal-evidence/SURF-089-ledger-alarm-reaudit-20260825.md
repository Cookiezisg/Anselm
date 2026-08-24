# SURF-089 ledger alarm re-audit

Date: 2026-08-25

## Findings

- `gap-too-fast` opened after the five SURF-089 cells were serialized. The five judgments all point to one sealed real session (`20260825-040519`) and one non-empty formal evidence file; the zero/near-zero write intervals are ledger serialization after the real observation, not five unobserved product decisions.
- `discovery-collapse` opened because the latest window contains no fail verdict. This is not accepted as evidence that the product is defect-free by itself. The preceding SURF-089 history contains two excluded red sessions, including the native role regression (`unknown`), and the final green session was rebuilt after that stop-and-fix.
- Independent reread covered the final screen recording and frame, backend journal, three SSE connection records, frontend journal, six managed LLM probe statuses, SQLite integrity checks, source diff, focused `86/86` Flutter suite, and successful macOS Debug build.
- The fixed anchor calibration was rerun: `anchors.py check` passed `10/10`; the anchor set, thresholds, CODEX, and gate were not changed.

## Resolution

These are statistical signals from a legitimate five-cell ledger write, not evidence of missing observation or a weakened judgment standard. Ack both alarms with this file. Do not alter the alarm thresholds, algorithm, anchor set, or ledger gate.
