# EDGE-229 · ledger alarm re-audit

- `gap-too-fast` is expected for this focused atomic row: one local WAV/PCM regression pass and
  four explicit `na` entries were written together; this is not five product observations.
- `discovery-collapse` reflects that no real App/TTS/five-channel session was claimed. PCM-level
  joining, chunk limits, metadata walking and mixed-format refusal are covered; UI, upstream wire,
  visual and discoverability evidence remain `na`.
- Focused tests passed under `-race`; anchor calibration remains `10/10` and the sequence gate
  admitted only `EDGE-229`.
- Acknowledge both alarms against this re-audit without changing thresholds or the algorithm.
