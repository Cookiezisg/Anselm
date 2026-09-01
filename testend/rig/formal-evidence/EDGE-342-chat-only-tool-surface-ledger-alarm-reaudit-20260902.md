# EDGE-342 · ledger/alarm independent re-audit

## Scope

- Re-audited the three new judgments for `chat-only 模型的工具面`:
  `L3=pass (A1)`, `L4=pass (C4)`, `L5=pass (G1)`.
- Source session=`/private/tmp/anselm-rig-formal-20260902-06/sessions/20260902-015651`;
  formal ledger root=`/private/tmp/anselm-rig-formal-20260801-3`.
- Anchor calibration was freshly rerun and passed `10/10` before the judgments.
  No alarm threshold, algorithm, CODEX law, anchor answer, five-level standard or
  formal sequence was changed.

## Evidence review

- The same finalized real-App session contains `screen.mov`, `backend.log`,
  `sse.jsonl`, `frontend.log`, `llm.jsonl` and the conductor manifest. `rig-check`
  and `rig-down` both passed; the session's three SSE streams and managed recorder
  were attributed to the conductor.
- The first real path exposed a product defect: an Anselm Auto initial selection was
  passed into the external-model picker and left the model stage empty. The picker
  was fixed to accept an initial value only when it belongs to the external catalog;
  the repaired path then selected the local chat-only model and completed two chat
  turns.
- Backend context samples recorded `tool_schema_bytes=0` for both turns. The
  independent fixture wire journal recorded `model=edge342-chat-only`; the UI badge,
  backend prompt, SSE transcript and provider request therefore agree on the model's
  chat-only boundary.
- The L3 review covers the visible transition and two completed sends; L4 covers
  stable menu/form geometry and the explicit capability copy; L5 covers an ordinary
  user path from model selection to usable chat. No level was inferred from focused
  tests or from the existence of the code change alone.

## Alarm disposition

`discovery-collapse` opened because the trailing 50 live judgments had a `4.0%` fail
share under the unchanged `5%` floor. This is a statistical drift signal, not a
product pass and not a reason to waive discovery. The fresh anchor calibration,
the three separate law-bound judgments, the full five-channel evidence file and this
independent re-audit establish that this cell was actually inspected. The alarm is
acknowledged for this evidence watermark only; future new evidence must be checked
again by `alarms.py`.
