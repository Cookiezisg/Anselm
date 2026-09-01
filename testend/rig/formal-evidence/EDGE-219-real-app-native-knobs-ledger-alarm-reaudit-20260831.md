# EDGE-219 · ledger/alarm independent re-audit

## Scope

The four EDGE-219 judgments were written only after the final real-App picker frame,
exact backend responses, durable default, and five channel journals were reviewed.
The Computer Use punctuation limitation is explicitly excluded from the error-code
claim; exact JSON sent by `curl` against the same sealed backend proves that claim.

## Evidence audit

- Formal session:
  `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-115738-edge219`.
- The session contains the finalized window recording, fresh frontend/backend/SSE/LLM
  journals, the native-knobs frame, and a passed `rig-check`/`rig-down` lifecycle.
- The managed gateway lifecycle is present in `llm.jsonl`; the local provider is
  clearly identified as disposable BYOK test infrastructure.
- `MODEL_OPTION_UNSUPPORTED` and `MODEL_OPTION_VALUE_INVALID` were observed as
  separate exact responses, and the valid two-option selection was read back from
  the workspace after persistence.

## Resolution

The expected `gap-too-fast` and `discovery-collapse` alarms from the four sequential
level writes were acknowledged with this independent re-audit. Thresholds, CODEX
laws, anchor set, five-channel requirements, and the formal sequence were unchanged.
