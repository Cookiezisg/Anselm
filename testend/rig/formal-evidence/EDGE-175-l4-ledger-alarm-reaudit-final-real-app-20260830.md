# EDGE-175 · MCP 失败附 stderr 尾 · L4 final ledger/alarm re-audit

## Re-audit scope

The L4 pass was not a rubber stamp. It was written only after a new real-App session, a
finalized recording, and the five-channel journals were produced. The prior L4 red finding and
its evidence remain unchanged; this is a separate review of the replacement session.

## Evidence integrity

- Fresh session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-202150`.
- `rig-check.sh` passed with screen recording, backend, independent SSE, frontend console, and
  managed LLM tap physically attached; `rig-down.sh` finalized `screen.mov` at `152.375s` and
  removed the owned processes.
- The default real-App frame has one center failure card, one assistant handoff, and one human
  Activity summary. Raw `tools/call`/`EOF` appears only after the explicit technical disclosure
  is opened.
- The failed MCP tool and server stderr tail are durable in the backend, SSE, and call records;
  `llmtap` retains the corresponding request/response bodies. The frontend journal contains no
  application-level Flutter/Dart/layout/Unhandled error.
- The pass cites existing CODEX law `E1`; the evidence file is non-empty and the session path is
  independently verifiable. No threshold, algorithm, law, anchor, or sequence gate changed.

## Decision

`discovery-collapse` is acknowledged for this judgment because the low recent fail share is a
statistical alarm, not evidence that the product defect was hidden or that the pass was inflated.
The red prior judgment remains preserved, and the replacement pass remains conditional on the
fresh real-App evidence above. The alarm must reopen if later judgments lack fresh evidence or
reintroduce the default-frame protocol leak.
