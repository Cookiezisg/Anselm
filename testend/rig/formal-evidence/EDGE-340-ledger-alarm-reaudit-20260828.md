# EDGE-340 · ledger/alarm independent re-audit

## Scope

- Re-audited the single new `L2=pass` judgment for `Vertex service-account 文件校验`.
- Source session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-035055`.
- Anchor calibration remains `10/10`; no alarm threshold, algorithm, law, or
  anchor changed.

## Evidence review

- The clean session contains a finalized `screen.mov` (`85.241667s`), manifest,
  recording lifecycle, backend/frontend journals, three-stream SSE journal, and
  managed LLM wire journal.
- The App created a fresh workspace, selected Vertex, displayed the
  service-account-specific controls, rejected a non-sensitive JSON object missing
  `type` and `private_key`, and canceled back with the managed row intact.
- `rig-check` confirmed exact App PID/window ownership, all three SSE connections,
  managed key routing through llmtap, and no external overlay. The post-shutdown
  process and listener audit was empty.
- The earlier ambiguous session is preserved as a red instrument finding and was
  not used for the judgment. This is evidence of an enforced stop-and-fix, not a
  reason to lower the five-channel requirement.

## Alarm disposition

- `discovery-collapse`: the no-fail trailing window does not waive discovery or
  convert this edge into a broader Vertex success claim. The judgment is limited
  to the observed invalid-input boundary; L3-L5 remain `na`.
- The alarm was acknowledged with this re-audit. Standards, thresholds, law,
  anchors, and gate remain unchanged.
