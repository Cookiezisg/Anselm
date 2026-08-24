# SURF-079 ledger alarm re-audit

- alarm: `gap-too-fast`
- formal RIG: `/private/tmp/anselm-rig-formal-20260801-3`
- evidence session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-001953`
- affected judgments: SURF-079 levels 1–5, `ts=2026-08-24T16:24:21Z`

## Resolution

The alarm is a valid detector hit, not a reason to weaken the detector. The five level cells were
written consecutively after one completed real-app observation because the ledger gate is
level-by-level but the evidence is intentionally one frozen session. Their zero-second journal
spacing is therefore expected batch serialization, not evidence-free rubber-stamping.

Before writing, the same session had passed `rig-check` with all five channels physically
observing. The session was then cleanly closed by `rig-down`. The window-ID recording was
independently decoded and a terminal frame visually checked: it contains only the Anselm About
window, not the Codex host. The evidence file records the actual loading state, GitHub Releases
404/no-published-release result, clipboard value, `Copied` notification, version/engine/font
content, backend redline scan, three SSE connections with clean EOF, frontend redline scan, and
real gateway proof/install/models 200 responses. The old rectangle-recorded session was rejected
and never used for a judgment.

No threshold, algorithm, CODEX law, anchor set, or gate was changed. This re-audit only resolves
the detector's batch-serialization signal after independently rereading the raw session outputs
and final frame evidence.
