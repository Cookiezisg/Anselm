# EDGE-006 ledger/alarm re-audit · 2026-08-25

## Trigger

The five EDGE-006 judgments opened `gap-too-fast`, `pass-burst`, and `discovery-collapse`.
The detector was not bypassed and no threshold or gate rule changed.

## Evidence review

- Re-read `EDGE-006-deepseek-tool-chain-investigation-20260825.md`.
- Re-ran the focused loop and DeepSeek provider suites; all passed.
- The single pass is a measured provider-protocol invariant. L2-L5 are explicit `na`: the active
  group is an in-memory model projection with no UI/DB/SSE/session surface or user entry point.
- No real gateway session was borrowed, and no visual standard was downgraded.
- Coverage, law, anchor, sequence, and alarm logic were unchanged.

## Resolution

This is a reviewed internal compatibility slice, not an unexamined green burst. Acknowledge the
three alarms for this interval only and leave the detectors active.
