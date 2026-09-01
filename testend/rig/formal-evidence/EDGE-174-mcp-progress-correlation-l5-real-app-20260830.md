# EDGE-174 · MCP 进度关联 · real App L5

## Formal session

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-190430`
- Data directory: `/private/tmp/anselm-data-edge174-l5-fix3-20260830`
- Workspace: `ws_2b107b5077adca94`
- MCP server: `edge174`, tools `progress_alpha` and `progress_beta`

## Product journey

This was a fresh real-App journey. The user did not name a tool:

> Find a connected external tool that reports step-by-step progress. Run it once and explain the
> progress and final result. Do not guess tool names; explain if none is available.

The App discovered the connected `edge174` MCP server through `search_tools`, activated the
dynamic callable tool, and called `progress_alpha` once with `label=demo_run`. The MCP server
returned `EDGE174 done demo_run`; its live progress stream reported steps 1/3, 2/3, and 3/3.
The App rendered the connected server, tool call, progress, and final result in the transcript and
Activity rail. The user goal was achieved without requiring a workflow detour.

The user then asked for a verification without rerunning the tool:

> Now verify that the completed MCP call appears in call history. Use the server name shown above,
> do not run the progress tool again, and report the authoritative result.

The App called `search_mcp_calls` with the displayed server name `edge174`. The fixed tool resolved
that name to the canonical server ID and returned one `progress_alpha` call with `status=ok`,
matching input/output, and aggregates `totalCount=1`, `okCount=1`, `failedCount=0`. The transcript
reported the authoritative result and did not execute the progress tool again.

## Five-channel evidence

- Channel 1: the conductor-owned `screen.mov` is readable at `3104x1844 / 60fps / 141.095s`.
  Stable final frames show the progress result, the verified history table, and the Activity rail
  with `1 touched · 1 executed`; no clipping, overlap, or layout jump was observed.
- Channel 2: backend journal records the real MCP connection and call path without application
  panic, FATAL, or unexplained error.
- Channel 3: independent SSE records `search_tools`, the MCP `open → progress → close` lifecycle,
  the completed `progress_alpha` result, and the later history lookup; the call and result remain
  attributable to the same conversation and server.
- Channel 4: frontend journal contains only the known macOS IMK host diagnostic and the normal Dart
  VM line; no Flutter, Dart, RenderFlex, RenderBox, unhandled, assertion, or application error.
- Channel 5: managed LLM wire records challenge/install/models plus the streamed discovery,
  execution, and history-verification turns, all with successful HTTP responses; no gateway
  bypass occurred.

## Judgment

This fresh session proves new-user discoverability and completion of the product goal: a connected
MCP capability can be found from a natural request, executed directly in chat, expose live progress,
and be verified afterward through the product's call history using the displayed server name. The
earlier workflow-only refusal and name/id empty-history result are retained as red evidence and
are superseded only by these explicit stop-and-fix reruns.
