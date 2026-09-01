# EDGE-175 · 账本与告警独立复审 · real App L2

## Re-audit scope

This re-audit covers the new `EDGE|MCP 失败附 stderr 尾` L2 judgment from formal session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-182257`.

The judgment cites the existing CODEX law `measure:edge175-mcp-stderr-tail` and a non-empty
evidence file copied into the session's `evidence/` directory. The session contains the real App
recording, independent three-stream SSE capture, managed LLM wire capture, backend journal,
frontend log, MCP call list/detail responses, and clean rig shutdown. The call detail independently
proves `status=failed`, the EOF error, and the bounded server-level stderr tail with its explicit
`may predate this call` qualifier. The UI observation is recorded honestly: it shows the actionable
EOF failure but not the full server stderr tail inline, so higher-level UI cells remain open.

## Alarm resolution

The ledger write opened `gap-too-fast` and `discovery-collapse`. This is expected interlock
behavior, not an automatic pass:

- `gap-too-fast`: the new formal session and all five channel artifacts were inspected before the
  judgment; the short write interval is an automation-time property and does not substitute for
  session evidence.
- `discovery-collapse`: this pass is limited to failed-call persistence and server-level stderr
  tail semantics. The UI inline-log limitation, visual craft, and discoverability remain explicitly
  open, so the narrow pass is not evidence that failure discovery has disappeared.

The anchor set remains unchanged and passes `10/10`. No alarm threshold, algorithm, CODEX law,
coverage row, or formal sequence was modified. Both alarms are acknowledged only through
`alarms.py ack` with this re-audit as the resolution note.
