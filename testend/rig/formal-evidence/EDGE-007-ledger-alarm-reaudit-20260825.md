# EDGE-007 ledger/alarm re-audit · 2026-08-25

## Trigger

The EDGE-007 stop-and-fix slice opened `gap-too-fast`, `pass-burst`, and
`discovery-collapse`. The detector was not bypassed and no threshold, CODEX law, anchor, or
sequence rule changed.

## Evidence review

- Re-read `EDGE-007-loop-terminal-error-ux-stop-fix-20260825.md` and the EDGE-005 revalidation
  note. The red finding came from the real transcript rendering path: two durable loop codes were
  being shown instead of human copy.
- Re-ran the focused Flutter widget regression and `make -C frontend analyze`; both passed. The
  regression asserts both localized actionable messages are present and both internal codes/raw
  details are absent.
- Re-ran the loop regressions for `TOOL_ERROR_STORM` and `CONTEXT_INPUT_TOO_LARGE`; both passed.
- The two pass judgments are supported by the actual corrected product surface and its regression;
  the three `na` judgments explicitly refuse to invent a real five-channel injected storm session.
- EDGE-005 L4 was revalidated through the dedicated `--revalidate` path. This lifts a settled prior
  classification only because a later stop-and-fix changed the applicable product surface; it does
  not create a second original sequence slot.

## Resolution

This was a genuine product defect caught before advancing the frontier, followed by a bounded
focused verification. Acknowledge the three alarms for this interval only and leave all detectors
active for the next edge.
