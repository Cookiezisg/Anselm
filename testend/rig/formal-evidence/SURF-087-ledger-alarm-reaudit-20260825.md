# SURF-087 · ledger/alarm independent re-audit

- source session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-024808`
- scope: five SURF-087 judgments; no threshold, law, anchor, or gate changes.

The session used a fresh App process and a fresh data directory, exercised the real Scheduler overview and
failed-run dossier, caught and fixed two product copy defects, rebuilt the App, and repeated the same path. The
first defect was the English generic execution fallback in the Chinese dossier; the second was the mixed-language
replay confirmation `重放这个 run?`. The final frame, frontend journal, backend journal, SSE witness, llmtap, and
SQLite checks were re-read after the fixes.

The three SSE streams connected and closed normally. The deterministic seeded run records predated the witness and
the final path deliberately cancelled the replay confirmation, so the absence of a business durable frame is
explicitly honest rather than a missing observation. The final frontend journal contains startup only and no
unknown tooling or runtime pattern.

Conclusion: the five judgments are admissible. Any `gap-too-fast` signal from serial ledger writes is to be reviewed
against this record without changing its algorithm or threshold.
