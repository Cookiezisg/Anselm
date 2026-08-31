# EDGE-212 · ledger/alarm independent re-audit

## Scope

The `gap-too-fast` alarm opened after the four EDGE-212 cells were written within one
same-session review window. This re-audit treats the alarm as a control signal and does
not alter its threshold, the CODEX laws, the sequence gate, or any verdict.

## Independent evidence check

- The formal session is `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-103415`.
- Its recording is finalized, `rig-check` passed all five physical observers, and `rig-down`
  left no backend, App, ssetap, or llmtap process running.
- `edge212-quota-error-after-rebuild.png` visibly contains the injected transient error and
  retry-preserving copy. `edge212-quota-recovered-after-repair.png` visibly contains the
  recovered quota meter and the same masked managed install.
- `llm.jsonl` independently records exactly one injected `GET /v1/quota -> 429`, followed by
  `GET /v1/models -> 200` and `GET /v1/quota -> 200`; no `/v1/install` request exists.
- `backend.log` independently records quota `429`, repair provision `200`, and quota `200`,
  with no panic, ERROR, or fatal application event.
- `sse.jsonl` contains all three workspace stream connections and clean teardown; this
  settings-only scenario has no message event that could be fabricated.
- `frontend.log` contains no Flutter/Dart exception or layout overflow.
- The corrective frontend contract and widget tests pass, including transient 429/5xx copy
  and the unchanged 401 revoked-install copy.

## Resolution

The short inter-judgement gaps reflect four level writes after one deliberate real-App
review, not four unobserved guesses. The alarm is therefore resolved by this independent
evidence re-audit at the current journal watermark. The alarm threshold remains 25 seconds;
future fast judgment clusters must open a new review event.
