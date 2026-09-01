# EDGE-175 · L3 ledger alarm re-audit · real App

## Scope

This re-audit covers the new `EDGE|MCP 失败附 stderr 尾` L3 judgment for formal session
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-182257`.

## Independent checks

- The L3 evidence is a non-empty file inside the same manifest-bound session and cites the
  existing `B2` law; it does not reuse the L2 judgment as a smoothness claim.
- The evidence contains an actual `ffprobe`-readable 60fps recording, a measured early feedback
  sample, and a separately measured `t=66..75s` stable tail. The earlier `t=55..62s` content
  settling change is disclosed and excluded from the stable window rather than hidden.
- Backend, three SSE streams, frontend console, managed LLM wire, and recording all belong to
  the same session. The App error state is visible and the final stable content has no measured
  non-user displacement in the declared ROI.
- The judge accepted `B2` only after anchor calibration passed. The coverage row is now
  `✓✓✓~~`; L4 and L5 remain open and are not implied by this re-audit.

## Alarm disposition

`discovery-collapse` opened because the trailing 50 live judgments contain a `2.0%` fail share,
below the unchanged `5%` floor. This is an expected anti-rubber-stamp signal after a valid pass,
not evidence that the EDGE-175 product path was invalid. The review found no threshold, law,
anchor, evidence, or sequence-policy change. The alarm is acknowledged with this note and will
reopen only when new evidence crosses the existing watermark.
