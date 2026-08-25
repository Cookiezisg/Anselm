# EDGE-008 ledger/alarm re-audit · 2026-08-25

## Trigger

The five EDGE-008 judgments opened `gap-too-fast`, `pass-burst`, and
`discovery-collapse`. The detector was not bypassed and no threshold, law, anchor, or sequence
policy changed.

## Evidence review

- Re-read `EDGE-008-max-steps-ux-stop-fix-20260825.md`. The red finding was a real transcript-path
  defect: `MAX_STEPS_REACHED` was being concatenated into the user-facing line with internal loop
  detail.
- Re-ran the focused Flutter widget regression, which now covers all three loop terminal boundaries;
  it passed and asserts that localized actionable copy is present while raw code/detail is absent.
- Re-ran `make analyze` and the backend `TestRun_MaxStepsReached`/`TestRun_ToolErrorStorm` focused
  suite; both passed.
- L1 and L4 are supported by the corrected product behavior and regression. L2/L3/L5 are explicit
  `na`: no stable real gateway input manufactures this cap, no stream timing was recorded, and the
  state is not a user-navigable feature.
- Coverage, CODEX, anchors, alarm thresholds, and sequence rules remained unchanged.

## Resolution

This is a reviewed stop-and-fix, not an unexamined green burst. Acknowledge the three alarms for
this interval only and leave every detector active for the next edge.
