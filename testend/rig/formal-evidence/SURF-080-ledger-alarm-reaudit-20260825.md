# SURF-080 ledger alarm re-audit

- alarm: `gap-too-fast`
- formal RIG: `/private/tmp/anselm-rig-formal-20260801-3`
- evidence session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-004915`
- supplementary detail session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-002854`
- affected judgments: `SURF|settings/detail-push` levels 1-5

## Resolution

The alarm is a valid detector hit, not a reason to weaken the detector. The five level cells
were written consecutively after one completed real-App observation because the ledger gate is
level-by-level while the evidence is intentionally one frozen formal session. Their zero-second
journal spacing is therefore expected batch serialization, not evidence-free rubber-stamping.

Before writing, session `20260825-004915` passed `rig-check` with all five channels physically
observing and was closed cleanly by `rig-down`. Its post-fix window-ID recording segment was
independently decoded and visually checked; it contains the Anselm workspace editor, not the
Codex host. The evidence file records the 12 settings detail-push kinds, the expected 15-second
MCP registry loading state settling to the embedded 102-item snapshot, real temporary fixtures,
their REST/UI cleanup, backend/SSE/frontend/LLM journal checks, and the final five-level basis.
The supplementary session records the remaining detail-push paths.

The same-session instrumentation defect was separately fixed and regression-tested: a macOS
window identity change with unchanged geometry now rotates the recorder segment. Static tests
were `37/37`, shell syntax and `git diff --check` passed.

No threshold, algorithm, CODEX law, anchor set, or gate was changed. This re-audit only resolves
the detector's batch-serialization signal after independently rereading the raw session outputs,
the post-fix recording, and the formal evidence.
