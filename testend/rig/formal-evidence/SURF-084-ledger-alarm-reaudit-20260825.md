# SURF-084 ledger alarm re-audit

- formal RIG: `/private/tmp/anselm-rig-formal-20260801-3`
- evidence session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-014850`
- affected judgments: `SURF|i18n/scheduler` levels 1-5

## Resolution

This batch was judged only after a real red stop-and-fix cycle and a rebuilt green session. The
red session exposed raw Python traceback text in the scheduler failed-run projection; the source
projection and focused Flutter tests were corrected before the green session. The repaired App was
then re-observed through the frame recording, backend journal, all three SSE streams, frontend
console, and managed gateway wire.

The independent raw SSE journal intentionally retains the complete backend traceback as diagnostic
evidence. The user-facing peek card and run dossier intentionally show only the concise terminal
reason. This is the required separation between debugging truth and product copy, not a suppression
of backend evidence.

If `gap-too-fast` opens during the five serialized level writes, it is expected ledger mechanics,
not evidence-free stamping: the full scheduler purpose, approval resolution, replay path, final
frame, and all five channels were reviewed before the writes. This note records an independent
re-audit of that exact sealed session. No threshold, alarm algorithm, CODEX law, anchor set, or
ledger gate was changed.
