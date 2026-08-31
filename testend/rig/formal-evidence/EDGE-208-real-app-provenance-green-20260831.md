# EDGE-208 · real App `origin_tool_call_id` narrowing

## Result

GREEN for the real tool-result media boundary. A function call minted a fresh image attachment
and, in the same JSON result, echoed the ID of an older user-uploaded image. The following
managed-model request contained exactly one native image part: the fresh function artifact. The
foreign attachment ID remained only in the textual tool result and was not expanded into model
input. The App then completed with `EDGE208DONE`; no retry, `inspect_media`, or second function
call was needed.

The preceding `20260831-101345` session is retained as a red discovery record because its
deliberate `1x1` image was rejected by the real vision route. The fresh session below uses a
provider-acceptable `32x32` PNG and is the only session used for the green judgement.

Formal session:
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-101803`

Real upstream: `https://api.anselm.website`; workspace `ws_369e8aee2eb9de9d`.

## Controlled sequence

Before the App turn, the sidecar received a real user-uploaded PNG with attachment ID
`att_49a08512f59f4602`. The acceptance fixture function was edited to emit a valid `32x32`
`own.png` artifact and return both:

```json
{
  "foreign": {"attachmentId": "att_49a08512f59f4602", "mime": "image/png", "source": "user_upload"},
  "own": {"$media": "own.png"}
}
```

Computer Use opened a new Chat, entered the user request, and observed the normal discovery path:
`Searched tools` → `Searched function` → `Ran function edge208_provenance_probe`. The settled App
frame shows the successful answer `EDGE208DONE`, the executed function card, and an available
composer. The copied frame is `evidence/edge208-final-settled.jpeg`.

## Five-channel evidence

- **Frame**: `screen.mov` is finalized (`101.740000s`). The real App visibly completes the
  request, shows one executed function activity, and has no error card, duplicate result, or
  retry residue.
- **Backend**: `backend.log` records the real function run and the completed conversation. No
  application ERROR, panic, or fatal event is present.
- **SSE**: `sse.jsonl` records the user message, search/function/tool-result sequence and final
  message close. Messages durable sequence `1..29` and entities sequence `1..4` are monotonic;
  notifications are also present and all three streams close cleanly at teardown.
- **Frontend console**: `frontend.log` contains no Flutter/Dart application exception, layout
  overflow, or unhandled error. The only matching diagnostic is the known macOS IMK platform
  message.
- **LLM wire**: the fresh post-tool request is
  `llm-bodies/00008_v1_chat_completions.bin`. Its history contains the full tool result with both
  IDs, while the appended media user message contains one text part and one
  `/v1/media/leases/...` image URL. There is no second image URL for the foreign ID. The media
  upload and completion are real managed-gateway requests, all successful; no retry request was
  needed.

## Measurement and judgement

The durable tool result proves both IDs existed in the returned payload; the LLM body proves the
consumption filter selected only the attachment whose `origin_tool_call_id` equals the current
function call. The App answer and the five journals prove the narrow result still permits the
normal user-facing turn to complete.

L2 uses `F2` for REST, SQLite-backed attachment provenance, SSE close, and managed wire agreement.
L3 uses `A4`: the function discovery/execution feedback remains visible through completion with
no retry or duplicate media turn. L4 uses `C4`: the settled success frame has one coherent
activity/result hierarchy and an unobstructed composer. L5 uses `G1`: a user can request the
function in ordinary Chat language; no knowledge of provenance columns or media lease URLs is
needed.
