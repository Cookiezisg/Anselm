# EDGE-174 · MCP 进度关联 · L5 ledger/alarm re-audit

## Scope

This independent re-audit covers the fresh stop-and-fix session used for the L5 pass. It does not
change the alarm thresholds, algorithms, CODEX laws, anchors, or sequence policy.

## Evidence reviewed

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-190430`
- Pass evidence: `testend/rig/formal-evidence/EDGE-174-mcp-progress-correlation-l5-real-app-20260830.md`
- Focused Go regression: `internal/app/chat`, `internal/app/tool/blocks`, `internal/app/tool/mcp`,
  and `internal/app/mcp` all passed after the routing and name/id fixes.
- The real App first executed `progress_alpha` through `search_tools`, displayed its live
  progress and result, and then used the catalog name `edge174` in `search_mcp_calls` without
  rerunning the progress tool. The returned one successful call agrees with the same session's
  backend journal, messages/entities SSE, and managed LLM wire.
- The final Computer Use frame shows the verified call record and Activity rail. The session was
  closed by `rig-down.sh`; all owned processes were collected and the recording is readable.

## Alarm disposition

The `discovery-collapse` alarm was opened by the low fail share in the trailing window. Review of
the actual red finding and the repaired green session confirms this was not rubber-stamping: the
earlier product failure was real, was preserved as red evidence, required two code fixes and two
fresh App reruns, and only then received the pass. Acknowledging the alarm records that review;
future new evidence remains subject to the same threshold.
