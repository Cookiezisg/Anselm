# SURF-086 · ledger/alarm independent re-audit

- source session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-022809`
- scope: five SURF-086 judgments; no threshold, law, anchor, or gate changes.

The session was rebuilt on a fresh workspace and the notification tray was exercised through localized listing,
single read, unread-only filtering, group mark-all-read, group mark-all-unread, search, collapse/expand, and hover
mark-read. REST count/list, SQLite integrity, final frame, backend journal, and the frontend console were re-read.

The frontend AXTree bridge lines are the exact allowlisted stale-node pattern and have a required session review at
`sessions/20260825-022809/evidence/frontend-ax-review.md`; no unknown bridge or runtime pattern is present. The
three SSE streams connected and closed normally; seeded deterministic notification rows predate the witness, so the
absence of a business durable frame is explicitly honest rather than a missing observation.

Conclusion: the five judgments are admissible. Any `gap-too-fast` signal from serial ledger writes is to be reviewed
against this record without changing its algorithm or threshold.
