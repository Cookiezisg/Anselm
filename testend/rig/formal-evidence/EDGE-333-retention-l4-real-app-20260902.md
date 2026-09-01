# EDGE-333 · 保留面板无客户端默认 · L4

## 判定

`C4` 通过：the retention control, machine scope badge, explanatory copy and dropdown menu form a stable, coherent visual group. The menu exposes four clear choices without clipping, overlap or inconsistent corner treatment.

## Product and visual evidence

- real App recording: `/private/tmp/anselm-rig-formal-20260902-02/sessions/20260902-001814/screen.mov`
- stable frame: `evidence/frames-2fps/0027.png`
- open-menu frame: `evidence/frames-2fps/0088.png`
- post-selection frame: `evidence/frames-2fps/0097.png`
- restored-menu frame: `evidence/frames-2fps/0108.png`
- the visible menu contains `30 days`, `90 days`, `180 days` and `Keep forever`; the selected row is visibly marked
- `This machine` scope badge sits with the retention section, not as a misleading page-level claim
- the explanatory sentence remains stable while the value changes; no content jump or clipping was visible in the 60fps recording

## Measurements and five channels

- `measure diff` on 2fps frames reported only local settings/dropdown changes during the interaction windows
- `measure latency` local change boxes were `(2072,842)-(2551,950)` and `(2098,844)-(2524,944)`
- representative body text sample measured `5.33:1` against white; heading sample measured `18.10:1`, both meeting `D1` AA thresholds
- backend, SSE, frontend-console and LLM-wire evidence is recorded in the same complete session; no channel was substituted with a fixture-only assertion
