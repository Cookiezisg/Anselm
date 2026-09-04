# EDGE-215 · 受管 key 不可变：正式真实 App 证据

- Session: `/private/tmp/anselm-rig-formal-20260905-edge293/sessions/20260905-024959`
- App: real macOS App, window `16776`, PID `68919`; renderer switch `enable-impeller=false` is recorded in the session manifest.
- Scope: the managed `anselm` credential in workspace `ws_9c6defd281bd5957`.

## Product observation

The real Settings → Models & keys page presents one `Anselm Free` model-key row with the always-visible
metadata `Managed · anselm · ins_e64...ec80` and a healthy status dot. The row is not an edit or delete
control. Clicking the row produced no accessibility-tree or visual state change. The page keeps the
managed identity separate from the user-controlled `Add key` action and does not expose a misleading
destructive affordance for an installation credential.

The visual witness is `evidence/EDGE-215-managed-key-settings.png`; it shows the complete settings shell,
free-tier card, managed row, and scenario defaults without clipping of the target row or an unexplained
layout shift.

## Contract probe

`evidence/EDGE-215-managed-key-http.txt` records the same-session black-box probe:

- GET before: HTTP 200; key id `aki_edb2e329ec8d54ff`; provider `anselm`; display name `Anselm Free`;
  base URL points to the local recording tap; `testStatus=ok`.
- PATCH `displayName=EDGE215 must remain immutable`: HTTP 422, `API_KEY_IMMUTABLE`.
- DELETE: HTTP 422, `API_KEY_IMMUTABLE`.
- GET after: HTTP 200 and the managed row is byte-for-byte unchanged in its identity and display fields.

The rejection is deterministic and does not mutate the workspace. This edge has no user-executable
PATCH/DELETE surface, so L3 (action-to-first-feedback timing) is explicitly not applicable rather than
being inferred from an HTTP stopwatch.

## Five-channel witness

- Channel 1: the session recording is finalized and the target settings frame is extracted above.
- Channel 2: `backend.log` contains the two authenticated 422 requests and no application panic/error.
- Channel 3: `sse.jsonl` contains all three stream connections; a rejected key mutation correctly emits no
  entity mutation frame.
- Channel 4: `frontend.log` contains no application-level error or renderer validation error.
- Channel 5: `llm.jsonl` contains the managed gateway bootstrap/wire journal; this deterministic settings
  rejection correctly has no chat completion.

`rig-check.sh` and `rig-down.sh` are the session seal and five-channel checks. No key was changed or
deleted during this probe.
