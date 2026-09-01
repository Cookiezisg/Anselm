# EDGE-171 ledger alarm re-audit · 2026-08-30

The `gap-too-fast` and `discovery-collapse` alarms opened after the five ledger writes for the
EDGE-171 L2 judgment. They are ledger-discipline signals, not permission to lower the product
standard.

Independent re-audit completed before acknowledgement:

- Re-read the clean formal session `20260830-175550`, including its manifest, readable window-bound
  `screen.mov`, backend journal, three-stream ssetap journal, frontend console, and llmtap journal.
- Re-read the product evidence for the repaired second run. The first run's `1 calls` copy defect
  was explicitly excluded; only the rebuilt binary's `1 call` observation was used.
- Rechecked the real HTTP response: two persisted attachment receipts, one retained oversized-item
  placeholder, `200` call result, and one successful MCP audit row.
- Rechecked the focused implementation test `TestCallTool_MediaUploadBestEffortPerItem` and the
  frontend MCP panel test covering both singular and plural call labels.
- Re-ran `anchors.py check`: `10/10`. No threshold, alarm algorithm, CODEX law, anchor, sequence
  policy, or gate was changed.

The zero-second ledger intervals are explained by the required serialized `judge.py` writes after
the evidence review; they are not evidence-free rubber stamping. The latest 50 live judgments have
no failure verdict, but this single edge is not used to claim product-wide cleanliness. The alarms
were acknowledged with this note and the normal thresholds remain active.
