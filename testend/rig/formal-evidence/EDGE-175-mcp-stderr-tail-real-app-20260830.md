# EDGE-175 · MCP 失败附 stderr 尾 · real App L2

## Formal session

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-182257`
- Data directory: `/private/tmp/anselm-data-edge175-20260830`
- Workspace: `ws_5f21575848c293da`
- MCP server: `edge175`, tool `crash_with_stderr`
- Fixture: `/private/tmp/anselm-edge175-crash-mcp.py`, deterministic local stdio MCP

## Product path and result

The real App was started by `rig-up.sh`. Through the real Chat surface, a user turn asked the
model to invoke `edge175/crash_with_stderr`. The model discovered the dynamic tool through
`search_tools` and invoked it once with `{}`. The fixture wrote 180 diagnostic lines to stderr and
exited with status 42 while the `tools/call` request was in flight.

The real App displayed a failed tool card with the exact transport failure
`mcp tool call failed (reason=calling "tools/call": EOF)`. The Activity rail independently showed
`Run failed · inspect the error below` and the same MCP tool as `Failed`. The assistant then
completed the turn with the EOF failure explained in the transcript; the UI did not render the
failure as a successful tool result.

The persisted call detail was fetched through the real product REST endpoint
`GET /api/v1/mcp-calls/mcl_c24f9dd09e527624`. It returned `status=failed`, the EOF
`errorMessage`, and a `logs` field headed:

```text
--- server stderr tail (server-level, may predate this call) ---
```

The returned tail contained the server diagnostic sequence through line `179`, including the
final line. The list endpoint intentionally omits `logs`; the detail endpoint is the authoritative
inspection path. The raw response is preserved as
`mcp-call-detail.json` in this session.

## Five-channel closure

- Channel 1: `screen.mov` is readable, `3104x1844`, `60fps`, `99.998333s`. The sampled completed
  App state shows the failed tool card, explicit EOF error, and failed Activity row without
  clipping or overlap.
- Channel 2: backend PID `32738` was the listener on `:8742`; health passed. The backend journal
  captured all 180 stderr lines and the expected failed-tool warning; no panic or FATAL occurred.
- Channel 3: independent `ssetap` recorded the dynamic tool call, an entities `run` open followed
  by `close(status=error)`, and the messages `tool_result close(status=error)` for the same
  conversation and tool-call block.
- Channel 4: the conductor-owned rebuilt App completed the error turn. Frontend log has no
  Flutter, Dart, RenderFlex, overflow, unhandled, assertion, or application error; only the known
  macOS IMK host diagnostic is present.
- Channel 5: `llmtap` recorded managed challenge, install, models, and three streamed chat turns;
  all upstream responses were HTTP `200`.

`rig-check.sh` passed before the run. `rig-down.sh` finalized the recording at `99.998333s` and
left no owned App, backend, ssetap, llmtap, recorder, or local MCP process behind.

## Judgment boundary

This evidence proves that a crashing stdio MCP leaves an actionable failed call, preserves the
bounded server-level stderr tail, and explicitly marks that the tail may predate the current call.
It does not prove that the desktop UI exposes the full stderr tail inline, nor visual craft or
new-user discoverability of the detail inspection path. Only L2 is eligible here; L3-L5 remain
open.
