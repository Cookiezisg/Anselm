# EDGE-002 ledger re-audit · 2026-08-25

## Scope

This review keeps the real managed-gateway boundary and the local checkpoint proof separate. The
real App session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-115619` is the
five-channel witness for the user-facing route; its final 504 is not relabeled as a semantic
checkpoint pass. The production loop/context-manager and black-box checkpoint behavior are covered
by the focused Go and `testend` runs recorded in the session evidence.

## Independent checks

- Evidence file exists and is non-empty:
  `sessions/20260825-115619/evidence/EDGE-002-five-channel.md`.
- The real fixture was created and deleted through the workspace API; the independent SSE witness
  recorded four correctly paired Function call/result groups.
- The real fifth request returned gateway `504` before compaction. No `compaction_mode` or
  `cleared_tool_bytes` is claimed for that request.
- `TestChat_CompactionWatermark` and `TestChatFork_SummaryTwoBranches` passed against the same
  production HTTP/SSE harness; package tests for loop, context manager, and checkpoint passed.
- The frontend provider-error correction is independently covered by the focused transcript test
  (`32/32` in the EDGE-001 stop-and-fix record).
- No alarm threshold, algorithm, CODEX law, anchor set, or sequence policy was changed.

## Resolution

The five ledger cells are based on the layered evidence above. Future real-gateway reruns must
retain the 504 as a provider-boundary result and only replace it when the managed route reaches the
semantic checkpoint branch with an independently captured `compaction_mode` and checkpoint marker.
