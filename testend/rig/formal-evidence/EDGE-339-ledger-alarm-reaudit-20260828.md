# EDGE-339 · ledger/alarm independent re-audit

## Scope

- Re-audited the single new `L2=pass` judgment for `BYOK base URL 模板未填占位`.
- Source session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-031741`.
- Anchor calibration was independently checked at `10/10`; the anchor set hash and
  all alarm thresholds remain unchanged.

## Evidence review

- The session has a finalized `screen.mov` (`160.780000s`), `backend.log`,
  `frontend.log`, `sse.jsonl`, `llm.jsonl`, manifest, and recording lifecycle.
- The real App path selected Azure, exposed the catalog template hint, then
  canceled without writing a credential or partial provider row.
- Backend, three SSE streams, frontend console, and managed gateway probe logs
  were reviewed. The only frontend `error` text is the known macOS IMK host
  diagnostic; there is no Flutter/Dart assertion, overflow, panic, or unhandled
  application failure.
- The LLM tap contains only managed challenge/install/models/quota probes, all
  successful; no completion or provider-secret claim was made.

## Alarm disposition

- `pass-burst`: the apparent rate change is one audited L2 write after one sealed
  real-App session, not an unobserved batch of green judgments.
- `discovery-collapse`: the latest window has no fail verdict, but this does not
  waive red-path discovery; this cell remains limited to the observed boundary
  and L3-L5 remain `na`.
- Both alarms were acknowledged with this re-audit. No threshold, algorithm,
  law, anchor, or gate was changed.
