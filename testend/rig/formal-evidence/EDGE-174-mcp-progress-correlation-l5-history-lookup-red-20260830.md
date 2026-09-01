# EDGE-174 · MCP 进度关联 · real App L5 follow-up history lookup red

## Formal session

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-185843`
- Data directory: `/private/tmp/anselm-data-edge174-l5-fix2-20260830`
- Workspace: `ws_32b7445bb2b48dce`
- MCP server: `edge174`, canonical id `mcp_3150212bd7a9a96d`

## Product result

The stop-and-fix prompt change worked for the primary natural-language request. The real App
used `search_tools`, called both `mcp__edge174__progress_alpha` and
`mcp__edge174__progress_beta`, displayed their progress and final results, and the user goal was
achieved.

The same turn then attempted to inspect the call history and sent
`search_mcp_calls({"serverId":"edge174","limit":2})`. The product's schema calls this field
`serverId`, while the model had only the server's human-facing name from the preceding discovery
result. The tool returned an empty history even though the same session's messages/entities SSE
and backend execution path contain two completed MCP calls. The final answer exposed this as
“call history is empty”, which is a confusing product inconsistency for a user asking for
verification.

This is not a failure of MCP execution or the independent observers. It is a tool boundary that
should accept the server name advertised by the product as well as the canonical ID, or otherwise
return an actionable resolution error.

## Five-channel evidence

- Channel 1: the recording shows the two successful MCP results followed by the empty-history
  explanation.
- Channel 2: backend journal records the server and the two successful calls; no application
  panic or fatal error occurred.
- Channel 3: independent SSE records two MCP run lifecycles with progress and completed results.
- Channel 4: frontend log contains no Flutter/Dart/layout/unhandled application error.
- Channel 5: managed LLM wire records the two dynamic MCP calls and the later history lookup.

## Judgment boundary

The primary L5 route is not yet eligible for green because the user-visible verification path is
internally inconsistent. Fix `search_mcp_calls` name/ID resolution and rerun the same fresh real
App journey before writing the L5 pass.
