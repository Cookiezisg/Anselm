# SURF-081 ledger alarm re-audit

- alarm: `gap-too-fast`
- formal RIG: `/private/tmp/anselm-rig-formal-20260801-3`
- evidence session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-010531`
- affected judgments: `SURF|i18n/chat` levels 1-5

## Resolution

The detector correctly opened on the five consecutive level writes. They were serialized only
after a complete real-App observation and a stop-and-fix cycle; this is batch ledger mechanics,
not evidence-free stamping. The red pre-fix session was explicitly excluded, and the green
session was rebuilt from the corrected source before the final observation.

The green session passed `rig-check` with all five channels physically observing and was closed by
`rig-down`. Its frame journal, final H.264 frame, backend journal, three SSE streams, frontend
console, and LLM wire were independently reread. The live stream visibly showed `思考中`, then
settled to `思考`; the English and Chinese rail/composer/action surfaces were both exercised. The
only frontend log match is the known macOS IMK host line; there are no application redlines.

No threshold, algorithm, CODEX law, anchor set, or gate was changed. This note resolves only the
expected batch-serialization signal after the raw evidence and the source regression were
independently checked.
