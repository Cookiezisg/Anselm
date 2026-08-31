# EDGE-210 · quota exhaustion copy red run

## Finding

The first real-App quota-fault sessions exposed a product defect. The transcript rendered
`LLM_QUOTA_EXHAUSTED · llm: free-tier quota exhausted (402)` and the stream variant appended the
raw gateway message. This contradicted the chat renderer's rule that provider diagnostics stay in
the durable diagnostic record rather than the primary transcript.

The defect was visible in the final frames of sessions
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-141123` (HTTP 402) and
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-141321` (stream
`BUDGET_EXHAUSTED`). Neither red run is acceptance evidence.

## Stop-and-fix

`chat_transcript.dart` now maps `LLM_QUOTA_EXHAUSTED` to localized user copy. English and Chinese
copy both explain that the monthly free-tier allowance is used up, offer waiting for reset, and
point to `Settings → Models & keys` for an alternative model or key. The internal code, HTTP status,
and provider prose remain available only in the durable diagnostic fields.

The mapping is covered by the chat transcript widget regression and regenerated slang output.
