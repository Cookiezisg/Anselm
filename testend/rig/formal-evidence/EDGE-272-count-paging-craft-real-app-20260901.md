# EDGE-272 L4 · 分组计数跨翻页不漂移 · 真实 App 视觉 craft

## 观察范围

- Session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-091811`
- Recording: `screen.mov`, `3104x1844`, `60fps`, `138.343s`
- Stable states: the expanded group before scrolling and the later group rows after scrolling;
  extracted inspection frames `f0078`, `f0098`, `f0099` in `/private/tmp/edge272-frames-1fps/`.

## Craft review

The group header keeps the total active count `31` in a stable, readable position while rows are
loaded below it. Row spacing remains consistent from the first visible page through the later
pages; there is no clipped label, overlapping row, empty placeholder, duplicated member, stale
count, or accidental spinner left in the rail. The pinned thread remains visibly separate from
the workdir group, which keeps the grouping hierarchy legible rather than visually mixing two
different scopes.

The judgment is based on the sealed real-App recording and live Computer Use views, not on a
synthetic screenshot. The companion L3 document owns transition behavior; this document only
judges the stable visual hierarchy, spacing, legibility, and absence of residue.

## Judgment

`C4` pass: the paginated group remains visually coherent and legible, with a stable total and
consistent row geometry across the observed list.
