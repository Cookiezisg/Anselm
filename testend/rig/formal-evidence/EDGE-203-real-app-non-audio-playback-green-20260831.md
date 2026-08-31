# EDGE-203 · real App non-audio playback honesty

## Result

GREEN for the honest capability boundary. A real image attachment appears in the real macOS App
as an image card and does not expose an audio playback affordance. Calling the playback-lease
endpoint against that image is rejected explicitly with `415 ATTACHMENT_PLAYBACK_UNSUPPORTED`;
the product does not pretend that every attachment is playable audio.

Formal session:
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-091904`

Real upstream: `https://api.anselm.website`; workspace `ws_b18eb1c41bae537a`; conversation
`cv_5a730eb937b0b8f2`; attachment `att_6dafbde93e263470` (`edge171-r2.png`, image/png, 317
bytes, preparation ready at 64x64).

## Real App sequence

1. A real PNG was uploaded through the running sidecar and prepared successfully. The turn was
   sent in the real conversation with that attachment and the managed model completed with the
   requested exact acknowledgement `IMAGE_RECEIVED`.
2. Computer Use opened the conversation. The final frame `/private/tmp/edge203-final.jpeg` shows
   the image thumbnail, original user prompt, completed assistant answer, and an available
   composer. There is no `Play audio`, duration, timeline, or audio control on the image card.
3. The deliberate impossible control path `POST /api/v1/attachments/att_6dafbde93e263470/playback-lease`
   returned HTTP `415` with code `ATTACHMENT_PLAYBACK_UNSUPPORTED` and message `attachment is not
   playable audio`. No lease or playback URL was minted.

## Five-channel evidence

- **Frame**: `recording.mov` is finalized (`94.216667s`). The real App displays the image as an
  image attachment with no misleading audio affordance; the conversation completes normally and
  the composer remains usable.
- **Backend**: `backend.log` records the controlled playback request as HTTP `415` with
  `ATTACHMENT_PLAYBACK_UNSUPPORTED`; there is no ERROR or panic. Attachment metadata records
  `kind=image` and `mimeType=image/png`.
- **SSE**: `sse.jsonl` records all three stream connections and the complete conversation sequence:
  user open/close, assistant reasoning open/close, assistant text open/delta/close, and completed
  message close seq `9`. The durable stream contains no playback lease mutation.
- **Frontend console**: `frontend.log` contains no Flutter/Dart application exception; only the
  known macOS IMK diagnostic is present.
- **LLM wire**: `llm.jsonl` records the managed gateway handshake, real media upload create/PUT/
  complete (`200/200/201`), and chat completion (`200`). The image crossed the managed media
  path, while the impossible playback request never reached the gateway.

## Measurement and judgement

`measure:edge203-non-audio-playback-honesty` records the image kind, the absence of audio controls
in the final App frame, and the exact `415 ATTACHMENT_PLAYBACK_UNSUPPORTED` response. L3 therefore
judges the end-to-end capability boundary rather than only a handler unit test.

The image card, prompt, answer, and composer form a clean completed state without a misleading
control, so L4 uses `C4`. The user can understand the attachment type from the visible image card
and is not offered an impossible action; no knowledge of playback leases or MIME rules is needed,
so L5 uses `G1`.
