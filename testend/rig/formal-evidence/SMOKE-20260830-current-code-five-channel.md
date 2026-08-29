# Smoke · current code five-channel real App · 2026-08-30

## Scope

This is a runtime baseline smoke session after the external team's backend and frontend changes.
It is evidence for the next acceptance run, not a COVERAGE judgment and not a substitute for a
formal frontier cell.

## Session

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-000543`
- Data: `/private/tmp/anselm-data-goal-smoke-20260830-r1`
- Real App recording: `screen.mov`, `169.881667s`, H.264, `3104x1844`, no black segment at the
  configured threshold
- `rig-check.sh`: passed before teardown
- `rig-down.sh`: completed; backend, ssetap, llmtap, App and recorder were stopped

## Observed result

- Real App launched against the conductor-owned backend and visited Chat, Entities, Scheduler,
  Library and Settings. The main oceans rendered without a crash, blank shell, or stale workspace
  surface.
- The managed gateway crossed the tap for proof challenge, install and models; both chat completion
  responses returned HTTP 200.
- SSE discovered and connected `messages`, `notifications` and `entities`; the witness recorded 9
  durable message frames with monotonic sequence numbers and clean disconnects at teardown.
- The backend journal had no panic, fatal, exception or application-level error. The frontend journal
  contained only the known macOS IMK host diagnostic.

## Input-bridge boundary

`sky.type_text` with Chinese text left only the final `。` in the composer. The backend, SSE witness,
LLM wire and transcript all agreed on that exact one-character user message, and the model completed
normally. This is a Computer Use/IME injection boundary, not evidence of a product-side data mutation
or stream mismatch.

`sky.set_value` displayed the complete Chinese string in the accessibility tree, but pressing Return
through the same bridge did not submit it. No product code was changed and no formal shortcut/input
cell was marked from this smoke session.

## Verdict

Runtime baseline: **pass for startup, five-channel wiring, gateway handshake, main-ocean navigation,
and one-character chat completion**.

Formal acceptance: **not judged**. EDGE-329 remains at its existing frontier state because this smoke
session does not contain valid physical post-recording shortcut evidence.
