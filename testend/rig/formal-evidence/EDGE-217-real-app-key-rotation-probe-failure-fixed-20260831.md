# EDGE-217 · real App key rotation survives a failed probe

## Result

GREEN for the required boundary: a user key rotation is persisted even when the
post-rotation connectivity probe fails, and the UI tells the user that these are two
different facts. The original UI only showed the backend sentence `api key probe failed`,
which made a successful rotation look like a failed save. The stop-and-fix added the
explicit sentence `The key was saved, but its connectivity probe failed. Check the key or
Base URL and try again.` while preserving the backend's actual error below it.

Formal session:
`/private/tmp/anselm-rig-edge217-20260831-r2/sessions/20260831-112438`

Workspace: `ws_037211614666900d` (`EDGE217 clean rotation`). The managed gateway path was
started through the real Anselm gateway and completed challenge/install/models/quota
successfully before the BYOK failure injection. The BYOK key and its failing probe were
deliberately controlled test data; no real user secret was used.

## Controlled sequence

The conductor started a fresh data directory with `RIG_SEED=0` and a real App. Computer
Use created the workspace and opened Settings → Models & keys. A disposable OpenAI-shaped
key was created against a local health endpoint so the row existed with a known initial
mask. Computer Use then opened that row's edit form, entered the disposable rotated key,
changed the user-supplied endpoint to an unreachable test address, and pressed `Save &
test`.

The Computer Use text transport does not preserve every URL punctuation character on this
host; the final persisted endpoint was the invalid-but-controlled `http//127.0.0.111`,
which failed before any external request with `unsupported protocol scheme`. This is still
a valid probe-failure boundary, but this evidence deliberately does **not** claim a TCP
connection-refused or a specific closed-port response.

## Five-channel evidence

- **Frame**: finalized frame=`evidence/edge217-rotation-probe-failed-fixed.png`. It shows
  the edited key form, the rotated-key warning, the explicit saved-but-probe-failed copy,
  the backend's `api key probe failed` sentence, and an unclipped actionable `Save & test`
  retry. There is no modal dead end or layout overlap.
- **Backend**: the authoritative REST read after the UI action shows the same row with
  `keyMasked=sk-...dead`, the new endpoint, `testStatus=error`, and a durable
  `testError` describing the probe failure. The backend journal contains no panic,
  application ERROR, or FATAL.
- **SSE**: `sse.jsonl` records all three resident streams connected for the current
  workspace. The settings-only operation produced no fabricated chat/entity run frame.
- **Frontend console**: `frontend.log` contains no Flutter, Dart, RenderFlex, or unhandled
  application error. The only host diagnostics are the known macOS IMK messages.
- **LLM wire**: `llm.jsonl` records the real gateway challenge/install/models/quota
  exchange used by the managed route. No BYOK secret is logged, and the malformed test
  endpoint generated no external BYOK request. `rig-check` passed all five observers and
  `rig-down` finalized a `108.678333s` recording and stopped all owned processes.

## Judgement

L2 uses `F2`: the final frame, the durable key row, the backend journal, the three-stream
observer, frontend console, and managed wire observer agree on the split state: rotation
persisted, probe failed.

L3 uses `A4`: the repaired form gives an immediate, human-readable next action and keeps
the retry button available instead of implying that the key was discarded.

L4 uses `C4`: the warning, saved-state explanation, backend error, and retry action remain
visually ordered without overlap or clipping in the finalized frame.

L5 uses `G1`: a new user can understand that the new key is already stored and that either
the key or Base URL should be checked; no knowledge of `testStatus`, API routes, or probe
internals is required.
