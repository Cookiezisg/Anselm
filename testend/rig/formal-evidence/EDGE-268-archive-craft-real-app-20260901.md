# EDGE-268 L4 · 驻地分组批量归档重跑 · 真实 App 视觉 craft

## 观察范围

- Session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-235910`
- Recording: `screen.mov`, `3104x1844`, `60fps`, `112.430s`
- Stable frames: `frames-l3/f00220.png` (confirmation state) and `frames-l3/f00228.png`
  (settled Recents state)
- Action: the real App's group menu opened the confirmation dialog for two conversations;
  Computer Use clicked the explicit `Archive all` action.

## Craft review

The confirmation frame is visually self-contained: the dialog has a clear title, a single
explanation block, and a separated action row. The copy exposes the affected count (`2`), the
destination (archive), reversibility, and the pinned-thread exception before the destructive
action. `Cancel` is visually distinct from the red `Archive all` commit action, and neither label
is clipped or ambiguous at the recorded desktop scale.

The settled frame has a stable left rail, keeps the unrelated Recents conversation visible, and
does not leave an empty group header, duplicate row, stale count, spinner, or orphaned modal. The
confirmation-to-settled transition is one coherent state change initiated by the user; the
separate L3 evidence records its timing and excludes it from unrequested-content movement.

## Evidence integrity

The frames were taken from the same sealed recording used for the L2/L3 judgment, not from a
synthetic screenshot or a different session. Five-channel collection passed for the session;
backend, SSE, and frontend journal results are recorded in the companion L3 evidence. This
document makes only the visual craft judgment and does not reuse the L3 latency measurement as a
visual pass.

## Judgment

`C4` pass. The user-facing confirmation and settled states are legible, hierarchically clear,
balanced, and free of clipping, overlap, stale content, or unexplained visual residue.
