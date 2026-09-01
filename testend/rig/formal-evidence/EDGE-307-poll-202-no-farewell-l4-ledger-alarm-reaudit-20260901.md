# EDGE-307 poll 型 202 不谢幕：ledger/alarm re-audit

- live judgment: `EDGE|poll 型 202 不谢幕|L4=pass|C4`
- formal evidence: `testend/rig/formal-evidence/EDGE-307-poll-202-no-farewell-l4-real-app-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-172700`
- journal: `/private/tmp/anselm-rig-formal-20260831-11/judgments.jsonl`

The judgment was accepted only after the evidence path existed and the five-channel session was
sealed. The evidence contains the window-owned 60fps recording, backend journal, independent SSE
witness, frontend console, managed LLM wire journal, and SQLite durable truth for the same run.

`alarms.py check` opened `discovery-collapse` because the unchanged trailing-50 fail-share rule
observed `0.0% < 5%`. This was reviewed as a statistical drift signal rather than suppressed: the
formal session is a fresh real-App green run, no evidence was downgraded to `na`, and no threshold,
anchor, CODEX law, or gate algorithm changed. The alarm was acknowledged with that resolution note;
the final check was clean with `317` live judgments and `4240` baseline judgments excluded from the
drift curves.
