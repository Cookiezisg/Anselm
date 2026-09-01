# EDGE-218 · ledger/alarm independent re-audit

## Scope

The four EDGE-218 judgments were written only after the fixed real-App frame,
authoritative workspace state, and all five channel journals were independently
reviewed. The settings-only scope is explicit; no chat completion is inferred.

## Evidence audit

- Formal session:
  `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-113541-edge218`.
- The session contains the finalized recording, fresh frontend/backend/SSE/LLM
  journals, the seed-defaults frame, and a passed `rig-check`/`rig-down` lifecycle.
- REST and SQLite agree that the explicit Dialogue `gpt-4o` selection survived
  provisioning while the other five unset scenario slots were filled with managed
  `anselm-auto`.
- The local provider was disposable test infrastructure only. The managed gateway
  wire remained the source for challenge/install/models/quota and no secret was
  recorded.

## Resolution

The expected `gap-too-fast` and `discovery-collapse` alarms from the four sequential
level writes were acknowledged with this independent re-audit. The thresholds,
CODEX laws, anchor set, five-channel standard, and scheduling policy were unchanged.
`alarms.py check` was run after the acknowledgements and must remain clean before the
next judgment.
