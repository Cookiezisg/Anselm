# EDGE-001 ledger alarm re-audit · 2026-08-25

## Scope

This review covers the two alarms opened after the five EDGE-001 judgments were appended to the
formal ledger under `/private/tmp/anselm-rig-formal-20260801-3`:

- `gap-too-fast`: the five writes were intentionally serialized in one controlled command after
  the same sealed session and focused regression had been inspected.
- `discovery-collapse`: the last 50-row window contains no new `fail` verdict because this edge was
  a successful mechanism path; the real 504/provider boundary was retained as a red finding in the
  evidence rather than incorrectly turned into a coverage fail for the marker mechanism.

## Independent checks

- Evidence file exists and is non-empty:
  `sessions/20260825-113116/evidence/EDGE-001-five-channel.md`.
- The evidence names one sealed session and all five channels; `judge.py --level 2` independently
  validated `manifest.json`, `backend.log`, `sse.jsonl`, `frontend.log`, `llm.jsonl`, finalized
  `screen.mov`, ffprobe readability, and all three SSE connections.
- Backend threshold records show two actual `cleared_tool_bytes` edits at the 80% prediction gate.
- LLM body files contain prompt-only omission markers; the durable REST check contains zero omission
  markers and retains the full fixture output.
- The raw 504 UI frame remains explicitly red. The stop-and-fix changed only the primary provider
  error copy, added bilingual strings, and passed the focused transcript test (`32/32`).
- No alarm threshold, algorithm, CODEX law, anchor set, or sequence policy was changed.

## Resolution

These are statistical review signals, not hidden product passes. Ack them only after this review is
read and retained beside the formal evidence. The next cell remains sequence-gated at `EDGE-002` and
must create fresh evidence before any further judgment.
