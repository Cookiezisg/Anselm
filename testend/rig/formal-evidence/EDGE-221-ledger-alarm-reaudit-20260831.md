# EDGE-221 · ledger / alarm re-audit

- `gap-too-fast` is expected for one atomic row: the four level judgments were written after one
  completed real-App session, not four independent product sessions. The formal evidence contains
  the session path, five-channel journal references, exact four `404 API_KEY_NOT_FOUND` responses,
  and the no-dangling-reference database check. The threshold is not changed.
- `discovery-collapse` is reviewed against the actual result, not waived: L2 has a real App and
  sidecar session; L3-L5 are explicit applicability `na` because this write-time seam has no
  independent user-visible wait state, visual artifact, or discoverable invalid-key entry. The
  API contract is still tested and the `na` boundary names the condition that would require a
  rerun if the product later exposes such an entry.
- The real App fresh session is
  `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-122143`; `rig-check` and `rig-down`
  passed, managed challenge/install/models traffic crossed llmtap, and the frontend diagnostic
  was only the known macOS IMK message. No threshold, CODEX law, anchor, or sequence policy changed.
- `anchors.py check` is `10/10`; after this note is acknowledged, `alarms.py check` must be clean
  before the next judgment. `gen_coverage.py --check` must remain
  `848 rows, 848 carried judgments, 0 tombstones`.
