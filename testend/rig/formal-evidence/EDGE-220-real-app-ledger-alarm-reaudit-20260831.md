# EDGE-220 · ledger / alarm re-audit

- `gap-too-fast` is expected for one atomic row: the four level judgments were written after one
  completed real-App session, not four independent product sessions. The evidence file contains the
  full five-channel observation and the stop-and-fix history; the alarm does not justify changing its
  threshold.
- `discovery-collapse` is reviewed against the actual result, not waived: L2-L4 have independent
  session evidence, while L5 is an explicit applicability `na` because the current picker exposes only
  probe-OK capability rows and has no custom unprobed model-id entry. The raw durable failure remains
  visible in backend/SSE journals, and the user-facing transcript now hides only infrastructure detail,
  not the failure itself.
- The real App fresh session is
  `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-121247`; `rig-check` and `rig-down`
  passed, managed challenge/title traffic crossed llmtap, and the frontend diagnostic was only the
  known macOS IMK message. No threshold, CODEX law, anchor, or sequence policy changed.
- `anchors.py check` remains `10/10`; after these notes are acknowledged, `alarms.py check` must be
  clean before the next judgment. `gen_coverage.py --check` must remain `848 rows, 848 carried
  judgments, 0 tombstones`.
