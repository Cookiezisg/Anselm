# EDGE-307 poll 型 202 不谢幕：L5 ledger/alarm re-audit

- live judgment: `EDGE|poll 型 202 不谢幕|L5=pass|G1`
- formal evidence: `testend/rig/formal-evidence/EDGE-307-poll-202-no-farewell-l5-real-app-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-173833`
- journal: `/private/tmp/anselm-rig-formal-20260831-11/judgments.jsonl`

The ledger accepted the L5 judgment only after the blind real-App session was sealed. The same
session supplies the window recording, backend journal, independent SSE witness, frontend console,
managed LLM wire journal, and SQLite durable completion for the user-visible result.

The unchanged `discovery-collapse` alarm opened because the trailing-50 fail-share rule observed
`0.0% < 5%`. Review found a fresh, independent green L5 session rather than missing or downgraded
evidence: the user goal was outcome-oriented, the workflow was found by ordinary language, and the
final result was visible without internal knowledge. No threshold, anchor, CODEX law, or gate
algorithm changed. The alarm was acknowledged with this resolution note; the final check was clean
with `318` live judgments and `4240` baseline judgments excluded from the drift curves.
