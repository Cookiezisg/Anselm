# EDGE-213 · real App hides quota until free tier is provisioned

## Result

GREEN for the honest not-provisioned state. A fresh real App workspace was created while
the managed gateway path was deliberately unavailable. The sidecar kept onboarding usable,
did not create a phantom managed key or zero-valued quota, and the Models & keys surface
offered the explicit `Enable free tier` action.

Formal session:
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-104036`

Workspace: `ws_14b1f64c5fc80802` (`EDGE213 no-provision`). The LLM tap was bound to the
closed loopback upstream `http://127.0.0.1:1/v1` only to preserve a real wire observer for
the intentionally absent managed route; no managed gateway success is claimed by this
scenario.

## Controlled sequence

The conductor started with `RIG_SEED=0`, so no workspace or managed row existed. Computer
Use created one ordinary workspace and opened Settings → Models & keys. The settled frame
`evidence/edge213-not-provisioned-settings.png` shows:

- `Anselm Free · Auto multimodal` with the honest explanation `Registers this machine's
  anonymous fingerprint with the Anselm gateway for a quota`;
- a visible `Enable free tier` CTA rather than a quota gauge or fake `0 / limit` value;
- `No model keys yet` with the BYOK explanation;
- `Not set` scenario defaults, including no invented dialogue model.

## Five-channel evidence

- **Frame**: the fresh Settings frame is stable, unclipped, and contains the explicit enable
  action. No zero quota, stale managed row, or misleading “unavailable” state is shown.
- **Backend**: `backend.log` records workspace creation, two best-effort install failures
  against the deliberately closed upstream, `POST /api/v1/freetier:provision -> 200` with
  `provisioned=false`, and `GET /api/v1/freetier/quota -> 404` with the typed
  `FREETIER_NOT_PROVISIONED` contract. No panic or application ERROR/FATAL occurred.
- **SSE**: `sse.jsonl` records `messages`, `notifications`, and `entities` connected for
  `ws_14b1f64c5fc80802`; the settings-only path emits no fabricated business frame.
- **Frontend console**: `frontend.log` contains no Flutter/Dart exception, RenderFlex
  overflow, or unhandled application error. The only diagnostic is the known macOS IMK
  host message.
- **LLM wire**: `llm.jsonl` records only the two real proof-challenge attempts made by the
  failed provisioning hook; there is no successful install, no quota response, and no
  invented model request. `rig-check` verified the tap and all five observers before
  teardown; `rig-down` finalized the recording and stopped all conductor-owned processes.

## Judgement

L2 uses `F2`: the UI, typed REST 404, backend journal, SSE connections, and wire observer
agree that the workspace has no provisioned free tier.

L3 uses `A4`: the product provides an immediately understandable next action without
  trapping the user in a loading state or exposing an implementation error.

L4 uses `C4`: the free-tier card, CTA, empty key state, and `Not set` defaults form a stable
  hierarchy with no phantom meter or layout residue.

L5 uses `G1`: a new user can discover how to enable the free tier from the visible card;
  no knowledge of `FREETIER_NOT_PROVISIONED`, install IDs, or gateway internals is needed.
