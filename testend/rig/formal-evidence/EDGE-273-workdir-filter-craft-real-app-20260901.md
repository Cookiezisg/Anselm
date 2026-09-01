# EDGE-273 L4 · `?workDir=` 三态 presence · 真实 App 视觉 craft

## 观察范围

- Session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-093314`
- Stable real-App state: named group `anselm-edge273-real-group-20260901` with count `2`, and
  `Recents` with count `3`.

## Craft review

The rail communicates hierarchy cleanly: the named folder group is distinct from `Recents`, each
header keeps its count next to its label, and the child rows sit consistently beneath the correct
header. The stable view has no clipped labels, overlapping rows, unexplained empty gap, stale
membership, or spinner. The unmounted conversations appear under `Recents` rather than visually
pretending to belong to the named folder, which preserves the product's grouping semantics.

This judgment is based on the sealed recording and live Computer Use screenshots from the real
App, not on a synthetic mock. The companion L3 document owns transition behavior; this document
only judges hierarchy, spacing, legibility, and absence of visual residue.

## Judgment

`C4` pass: the three-state filter result is visually legible and well-separated, with stable
header/row geometry and no mixed-scope or residual UI artifacts.
