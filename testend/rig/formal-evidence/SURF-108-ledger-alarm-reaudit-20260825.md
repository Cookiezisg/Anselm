# SURF-108 ledger/alarm re-audit

## Evidence set

- primary session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-093437`
- settled frame: `evidence/SURF-108-stage-subagent-settled.png`
- SSE witness: `sse.jsonl` — contains the `Subagent` open/close, nested `subagent:true`, `Bash`, progress, tool_result and terminal output.
- LLM witness: `llm.jsonl` plus `llm-bodies/` and `llm-responses/` — real upstream requests returned HTTP 200.
- backend witness: `backend.log` — no panic/fatal; two non-fatal Grep fallback WARNs are retained as negative-path evidence.
- frontend witness: `frontend.log` — only known macOS IMK platform noise.

## Cross-channel conclusion

`stage/subagent` is green only for the positive `general-purpose` run. The earlier malformed Explore request remains a recorded negative path and is not counted as success. The visual frame shows the settled single-card grammar; the live AX/SSE observations show the execution-phase activity and terminal stream before settle.

## Gate note

The session must be torn down cleanly before L2 so the recorder's `screen.mov` is finalized. No threshold, alarm algorithm, CODEX law, or anchor calibration is changed for this cell.
