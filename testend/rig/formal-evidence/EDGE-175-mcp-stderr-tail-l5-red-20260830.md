# EDGE-175 · MCP 失败附 stderr 尾 · real App L5 red

## Failure

Fresh session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-203143` used the real
App and the deterministic `edge175/crash_with_stderr` MCP fixture. The first user turn created a
real failed MCP call. The follow-up then explicitly asked for the full failed-call details,
including the server stderr tail and the caveat that it may predate the call.

The model did not run the tool again, but the frontend's new default failure projection treated the
assistant's requested technical vocabulary as another transport-failure repetition and replaced
the answer with the generic handoff sentence. The user therefore could not receive the requested
history/detail explanation. The default collapsed failure face itself was correct; this red finding
is specifically the explicit-diagnostics escape hatch.

## Five-channel integrity

The real App, backend, three SSE witnesses, frontend console, and managed LLM tap belonged to this
session; `rig-check.sh` passed and `rig-down.sh` finalized `screen.mov` at `159.521667s` with no
owned processes left. The failed call and assistant response are present in the session journals.
No pass judgment was written for L5. This red evidence is retained after the fix and is not
overwritten by the replacement session.

## Stop-and-fix

`assistantMcpFailureProjection` now preserves an assistant response when it explicitly describes
technical details, a full detail view, an stderr tail, or the server-level `may predate this call`
caveat. Focused tests cover this escape hatch. A fresh real-App session is required before L5 can
be reconsidered.
