# EDGE-208 · real App provenance probe red observation

## Discovery result

The first real App probe reached the intended product path: the managed model discovered
`edge208_provenance_probe`, executed it exactly once, and the function returned both a newly
minted `function_artifact` attachment and a pre-existing `user_upload` attachment ID. The
following model request contained one native media part, so the `origin_tool_call_id` filter did
not widen the pre-existing attachment into the prompt.

The session nevertheless ended in `Something went wrong · LLM_BAD_REQUEST`: the probe's own
generated PNG was a valid but deliberately minimal `1x1` image. The managed vision route
rejected that image during the follow-up request with `invalid_request`. This is a red discovery
observation, not a green provenance verdict and not evidence that the 1x1 fixture is a supported
production image. The probe is being corrected to use a real `32x32` PNG before any ledger pass.

Formal session:
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-101345`

## Five-channel facts

- **Frame**: the real App showed the user prompt, `Searched function`, `Ran function`, and the
  final `Something went wrong · LLM_BAD_REQUEST` card. This is retained as the stop-and-fix
  frame; it is not a product pass.
- **Backend**: the sidecar recorded the function run and a multimodal follow-up. The provider
  rejected that follow-up; no backend panic occurred.
- **SSE**: `messages` durable seq `2..17` records the user turn, search, run, tool result, and
  error close; `entities` records the function run; all three streams connected and closed
  cleanly.
- **Frontend console**: no Flutter/Dart application exception was recorded; only the known macOS
  IMK diagnostic appears.
- **LLM wire**: the first post-tool request contains one `/v1/media/uploads`-backed native image
  part at `/v1/media/leases/...`; the `foreign` attachment ID is present only inside the textual
  tool result. The gateway returned HTTP `400` for that follow-up.

## Stop-and-fix boundary

The image-size limitation is a property of this acceptance fixture, not a reason to lower the
provenance standard. The next fresh session must use a provider-acceptable PNG and still prove
that the newly minted attachment is expanded while the foreign attachment remains text-only.
No L2-L5 judgment was written from this red session.
