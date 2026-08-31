# EDGE-197 · long ReAct boundary red evidence

- status: `non-qualifying`
- judgment: none; `judge.py` was not called
- session: `/private/tmp/anselm-rig-formal-20260801-10/sessions/20260831-044810`
- observed at: `2026-08-31 05:04:22 +08:00` onward

## What was attempted

The real App attached `edge193-neutral-test.png` and sent a user message through the Flutter
composer using `type_text`. The managed gateway recorded upload create, chunk, complete, and one
chat completion through `llmtap`. The user message body contained both the exact text and the
relative media lease. The model was instructed to run seven sequential `sleep 600` calls in one
ReAct so that the same media lease would cross its one-hour refresh window.

## Red result

The first foreground `sleep 600` reached the Bash hard timeout boundary and was recorded as
`timed out`. The model then attempted an invalid timeout above the permitted maximum, switched
the command to background mode, and polled it. The background polling path was subsequently
suppressed as a duplicate; the model emitted a final explanation before the seven-step ReAct
completed, while the background `sleep` process was still alive. The process was explicitly
terminated after capture. The App showed no completed lease refresh and the session did not cross
the required one-hour window.

This is a failed instrumentation/product execution path, not a pass, waiver, or applicability
decision. The session remains evidence of the failure only. A later retry must use a command below
the 600-second hard timeout (for example `sleep 599`) and must prove all seven calls, the refreshed
upload, byte identity, and the final close across all five journals before any ledger cell can be
written.

## Second attempt

The follow-up user turn attached the same neutral image through the real file picker and supplied a
fresh instruction to run seven foreground `sleep 599` calls with `timeout=599000ms`. The wire again
contained the user text and a newly staged relative media lease. The model did not execute the first
call; it refused the request on the grounds that seven near-ten-minute calls exceeded a reasonable
conversation duration. No lease refresh was observed and no ledger judgment was written.

This second result confirms that the remaining blocker is not composer input or gateway upload. It
is the autonomous long-running ReAct execution path: the current model/tool combination refuses the
required duration instead of keeping the turn alive. The formal frontier therefore remains
`EDGE-197|lease 临期刷新` at `✓~~~~`; forced user-interaction items remain untouched.
