# EDGE-005 ledger/alarm re-audit · 2026-08-25

## Trigger

The five EDGE-005 judgments opened `gap-too-fast`, `pass-burst`, and `discovery-collapse`. The
alarm engine was not bypassed and no threshold or algorithm changed.

## Evidence review

- Re-read `EDGE-005-context-too-large-investigation-20260825.md`.
- Re-ran the focused loop/LLM regression set; it passed, including the exact four-call bounded
  recovery protocol and `CONTEXT_INPUT_TOO_LARGE` actionable terminal message.
- L1 is a mechanism-level pass under E1. L2-L5 are explicit `na` because the repeated rejection is
  harness-injected, has no separate visual frame, and has no user-controlled entry point.
- EDGE-001 remains the evidence for the rendered provider-error surface; EDGE-002's managed 504 is
  deliberately not relabeled as this terminal branch.
- No coverage row, carried judgment, CODEX law, anchor, sequence policy, or gate requirement was
  rewritten. `gen_coverage.py --check` and `alarms.py check` are the post-review checks.

## Resolution

The burst is explained by one reviewed internal-boundary slice, not rubber-stamping. Acknowledge
the three alarms for this evidence interval only; leave the detectors unchanged for the next edge.
