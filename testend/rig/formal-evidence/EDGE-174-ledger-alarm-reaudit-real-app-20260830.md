# EDGE-174 · 账本与告警独立复审 · real App L2

## Re-audit scope

This re-audit covers the new `EDGE|MCP 进度关联` L2 judgment recorded after the formal session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-181342`.

The judgment cites the existing CODEX law `measure:edge174-mcp-progress-correlation` and a
non-empty evidence file physically copied into that session's `evidence/` directory. The evidence
contains the real App recording, independent messages/entities/notifications SSE capture, managed
LLM wire capture, backend journal, frontend log, rig checks, and clean shutdown result. The two
per-call progress streams are independently labelled and contain no cross-talk. The evidence is
explicit that delivery was observed serially, so it makes no unsupported parallel-throughput
claim.

## Alarm resolution

The ledger write opened `gap-too-fast` and `discovery-collapse`. This is expected interlock
behavior: the new judgment was not accepted as proof that the alarms were harmless.

- `gap-too-fast`: re-audit inspected the full new session and the cited evidence. The short ledger
  interval is an automation-time artifact after a completed, previously reviewed formal session;
  it does not replace the required five-channel evidence or permit an uncited pass.
- `discovery-collapse`: the current pass is a narrow MCP routing invariant, not a claim that the
  product has no failures. The evidence boundary leaves visual craft, parallel throughput, and
  discoverability open, and the coverage row retains those open cells.

The anchor set remains unchanged and passes `10/10`. No alarm threshold, algorithm, CODEX law,
coverage row, or formal sequence was modified. Both alarms are acknowledged only through the
`alarms.py ack` command with this re-audit as the resolution note.
