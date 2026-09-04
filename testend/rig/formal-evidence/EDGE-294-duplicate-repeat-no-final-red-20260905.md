# EDGE-294 red finding · duplicate repeat had no final answer

## Session

- session=`/private/tmp/anselm-rig-formal-20260905-edge294/sessions/20260905-033900`
- workspace=`ws_7b5b2f4bd3865d13`
- conversation=`cv_bf5d3a4547b89499`
- fixture Agent=`ag_d866bb7e5d74e043`
- build observed before fix: `backend` from the session's pre-fix binary

## Reproduction

1. In the real App, send `Delete the agent named EDGE294 autonomous deny 1788550993. Do not do anything else.`.
2. Resolve the dangerous `delete_agent` interaction with `deny` through the explicit test operator.
3. Send the same user request again and resolve the new interaction with `deny`.

## Finding

The second run emitted a duplicate `delete_agent` call. The loop correctly prevented a second side effect and wrote a completed suppression `tool_result`, but `loop.Run` finalized immediately on `repeatedCall` without creating a text block. The durable assistant message therefore contained only reasoning, tool calls, and tool results; the real App showed no new user-facing final answer for the second request.

Relevant durable facts:

- second assistant message `msg_b585fa33066cac3c` was `completed/end_turn`;
- its last block was `tool_result` `Duplicate tool call suppressed...`;
- `GET /api/v1/conversations/cv_bf5d3a4547b89499/messages` contained no final `text` block for that assistant message;
- the target Agent still returned `200`, and conversation touchpoints remained empty;
- SSE durable frames ended at the duplicate-suppressed `tool_result` and message close;
- frontend console had no crash, so this was a product-completeness defect rather than a renderer failure.

## Fix required

Keep the duplicate guard and its no-second-execution invariant, but emit and persist a deterministic, user-facing text terminal notice before `WriteFinalize`. Add a loop regression test that checks both the notice block and `Result.LastMessage`.

This evidence is intentionally red. It must not be used to pass any COVERAGE cell.
