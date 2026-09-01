# EDGE-174 · MCP 进度关联 · real App L5 discovery red

## Formal session

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-184652`
- Data directory: `/private/tmp/anselm-data-edge174-l5-20260830`
- Workspace: `ws_cd0dd02eda181e7f`
- MCP server: `edge174`, tools `progress_alpha` and `progress_beta`

## Product target and result

The real App was launched by `rig-up.sh`. The second turn used a natural-language product
request without naming either tool:

> Find a connected external tool that reports step-by-step progress. Run it once and explain the
> progress and final result. Do not guess tool names; explain if none is available.

The request was entered successfully through the real App composer. The model used
`search_blocks`, found the two connected MCP tools, and then answered that MCP tools could not be
run directly from the conversation and had to be placed in a workflow. It did not call either
MCP tool, did not emit progress, and did not achieve the user's request. The final answer was
therefore a product failure, not a successful discovery result.

The earlier Chinese attempt in this session was excluded from the judgment: the Computer Use
input bridge visibly corrupted the punctuation before the request reached the product, so it is
not evidence about App behavior.

## Five-channel evidence

- Channel 1: the conductor-owned recording shows the successful ASCII request, the `Searched
  blocks` step, and the final workflow-only refusal; no MCP progress card or result appears.
- Channel 2: backend journal records the chat turn without a corresponding MCP `tools/call`; no
  application panic or fatal error occurred.
- Channel 3: independent SSE witness records the conversation response but no MCP progress
  lifecycle for this request.
- Channel 4: frontend log has no Flutter, Dart, RenderFlex, or unhandled application error; the
  failure is the product's model/tool routing behavior, not a renderer crash.
- Channel 5: managed LLM wire records the discovery/completion requests and HTTP 200 responses;
  no MCP execution request was sent.

## Judgment

This is a genuine L5 failure. `search_blocks` is correctly scoped as a workflow-palette search,
but the system/tool descriptions did not explicitly tell the model that an existing MCP tool is
also directly callable in chat, nor route current-conversation execution to `search_tools`.
Stop-and-fix is required before this cell may become green. The failed judgment is intentionally
not counted as a settled coverage cell.
