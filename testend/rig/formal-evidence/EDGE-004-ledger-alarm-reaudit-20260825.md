# EDGE-004 ledger/alarm re-audit · 2026-08-25

## Trigger

The five EDGE-004 judgments were written after the exact loop and testend recovery checks. The
statistical alarm script opened `gap-too-fast`, `pass-burst`, and `discovery-collapse`. No alarm
threshold, scoring rule, law, anchor, sequence policy, or gate was changed.

## Evidence review

- Re-read `EDGE-004-context-overflow-recovery-investigation-20260825.md`.
- Re-ran the loop/contextcheckpoint/contextmgr focused suite and the two production HTTP/SSE
  compaction scenarios; both passed.
- The sole pass is the mechanism-level L1 recovery. L2-L5 are written `na` with explicit reasons:
  the forced rejection is harness-injected, the recovery has no distinct visual surface, and users
  have no entry point for manufacturing the internal failure.
- The real managed-gateway 504 observed in EDGE-002 remains a red provider boundary and was not
  reused as evidence for this edge.
- `gen_coverage.py --check` remained clean; no carried judgment was rewritten.

## Resolution

This was a legitimate controlled write burst, not silent evidence skipping. The three alarms are
acknowledged only for this reviewed interval; their detection logic remains active for subsequent
judgments. Reopen EDGE-004 if the product gains a controllable real-provider fault fixture.
