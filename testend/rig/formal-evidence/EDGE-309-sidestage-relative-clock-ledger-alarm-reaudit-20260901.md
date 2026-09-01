# EDGE-309 · discovery-collapse ledger/alarm re-audit

The `discovery-collapse` alarm opened after the L4 judgment because the trailing 50 live
judgments contain no `fail`. This is a required drift signal, not a reason to lower the bar.

Independent review completed against the sealed session
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-190217` and the fixed component
test. The review confirms:

- The prior real-App one-frame structural replacement remains preserved as a red finding and was
  not counted as a pass.
- The fixed session used the real macOS App and five-channel rig. Only opening the existing
  conversation and Activity side panel was performed; the observation window thereafter was
  passive.
- The baseline and terminal screenshots show the intended two-tier to one-tier result, while the
  30fps ROI journal contains six consecutive changed pairs during the header collapse rather than
  one replacement frame.
- Backend, three SSE streams, frontend console, LLM tap, `rig-check`, and `rig-down` were reviewed;
  no application error was hidden. The no-new-LLM-call fact is explicitly recorded rather than
  treated as evidence for this UI behavior.
- The deterministic widget test advances an injected clock by two minutes and verifies both rows
  survive the `AnMotion.mid` transition while all group headers disappear.
- L5 was reviewed separately and recorded as an applicability `na`, not a missing-evidence waiver:
  passive re-bucketing has no independent user action or discovery path. The visible time labels
  are part of the Activity ledger already covered by the L4 product frame; inventing a discovery
  pass for an implementation detail would lower, rather than preserve, the product standard.

No threshold, CODEX law, anchor, gate algorithm, or required five-level standard changed. The
zero fail-share is explained only for this independently reviewed repaired UI boundary and is not
generalized to the product. The alarm may be acknowledged against the current journal watermark;
it must reopen automatically if new evidence makes the condition applicable again.
