# EDGE-174 · MCP 进度关联 · real App L2

## Formal session

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-181342`
- Data directory: `/private/tmp/anselm-data-edge174-20260830`
- Workspace: `ws_bb9fcd595872135d`
- MCP server: `edge174`, tools `progress_alpha` and `progress_beta`
- Fixture: `/private/tmp/anselm-edge174-progress-mcp.py`, deterministic local stdio MCP

## Product path and result

The real App was started by `rig-up.sh`. Through the real App chat surface, one user turn asked
the model to run both dynamic MCP tools with labels `alpha` and `beta`, then return
`EDGE174_CHAT_DONE`. The model first used `search_tools`, then emitted both tool calls with
`execution_group=1`.

The fixture emitted three uniquely labelled progress messages per call and a distinct final
result. The messages stream recorded:

- `progress_alpha` open at durable seq `20`; all three `EDGE174 alpha step` deltas; completed
  close at seq `22`; result `EDGE174 done alpha` at seq `24`.
- `progress_beta` open at durable seq `21`; all three `EDGE174 beta step` deltas; completed
  close at seq `25`; result `EDGE174 done beta` at seq `27`.

The entities stream independently recorded the same two runs under the same MCP server scope:
alpha opened at seq `7`, beta at seq `8`, and each received only its own three progress lines.
No alpha line appeared in beta's block and no beta line appeared in alpha's block. The App
finished with both results visible and the Activity rail showing `1 touched · 1 executed` and
`edge174 Ran x2`.

The model requested both calls in one logical execution group, but this run observed the MCP
server deliveries serially: alpha completed its three progress steps before beta began. This
evidence therefore proves per-call token correlation and absence of cross-talk, not parallel
throughput or overlap timing.

## Five-channel closure

- Channel 1: `screen.mov` is readable, `3104x1844`, `60fps`, `85.225000s`. Sampled frames at
  approximately `33s`, `35s`, `38s`, `42s`, and `50s` show stable composer, thinking, tool-call,
  progress, and completed-result states with no visible clipping, overlap, or layout jump.
- Channel 2: backend PID `31663` was the listener on `:8742`; health passed; backend journal has
  no application-level WARN, ERROR, panic, or FATAL.
- Channel 3: independent `ssetap` recorded messages, entities, and notifications. Durable
  progress and terminal frames are monotonic and remain attributable to the same workspace.
- Channel 4: the conductor-owned rebuilt App completed the turn. Frontend log has no Flutter,
  Dart, RenderFlex, overflow, unhandled, assertion, or application error; only the known macOS
  IMK host diagnostic is present.
- Channel 5: `llmtap` recorded managed challenge, install, models, and four chat-completion
  requests; all upstream responses were HTTP `200`.

`rig-check.sh` passed before the run. `rig-down.sh` finalized the recording and left no owned App,
backend, ssetap, llmtap, recorder, or local MCP process behind.

## Judgment boundary

This evidence proves the product-side progress routing invariant through the real App and all
five channels. It does not establish visual craft of a long-running progress presentation,
parallel execution throughput, or discoverability of an obscure MCP progress edge path. Only L2
is eligible here; L3-L5 remain open.
