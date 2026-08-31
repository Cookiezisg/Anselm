# EDGE-202 · real App audio playback lease expiry

## Result

GREEN for the product path: a real audio attachment is playable in the real macOS App through a
short-lived bearerless playback lease; an expired lease is rejected with `404`; returning to the
conversation and pressing the real Play control obtains a fresh lease and resumes playback. The
expired URL is intentionally not treated as a UI error because the App owns lease minting and the
native player caches the small WAV after its initial read.

Formal session:
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-091019`

Real upstream: `https://api.anselm.website`; workspace `ws_f3b00064fe5c13f7`; conversation
`cv_9f4714cae260cded`; attachment `att_1792f840a55a8a73` (`edge202-voice.wav`, WAV, 176,478
bytes, 2 seconds).

## Real App sequence

1. The attachment was uploaded and attached to a real conversation. The model honestly reported
   that the current managed model has no native audio input; this is independent of playback.
2. Computer Use clicked the visible `Play audio` control. The backend recorded a lease mint at
   `09:12:59.697`, then the native player issued `Range bytes=0-1` (`206`) and loaded the full WAV
   (`206`, `176,478` bytes). The card changed from `–:––` to `0:02` and showed `Pause audio`.
3. With `ANSELM_RIG_PLAYBACK_LEASE_TTL_MS=1500`, a separately recorded lease expired after the
   bounded wait. Fetching that exact opaque URL returned `404` at `09:13:58.161`; the raw token
   was redacted in backend logs. Action record:
   `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-091019/edge202-actions.txt`.
4. Computer Use switched away and back to the conversation, resetting the native player. Clicking
   the visible Play control at `09:14:44` minted a new lease and again produced range/full reads
   (`206`). The final frame `/private/tmp/edge202-final.png` shows the playable `0:02` card with
   the progress line and Play affordance after completion.

## Five-channel evidence

- **Frame**: `screen.mov` is finalized (`213.765000s`). The real App shows a dedicated audio card,
  Play/Pause affordance, duration, progress line, and a normal completed state; no raw lease,
  bearer, or backend error is exposed.
- **Backend**: `backend.log` records lease mint, native Range probe/full reads, the expired fetch
  as `404`, and a new lease followed by successful `206` reads. There is no ERROR or panic.
- **SSE**: `sse.jsonl` contains the conversation's durable message stream and all three streams
  were connected by the rig. Playback is local attachment activity and does not create a chat
  mutation.
- **Frontend console**: `frontend.log` contains no Flutter/Dart application exception; only the
  known macOS IMK diagnostic is present.
- **LLM wire**: `llm.jsonl` records the real managed install/models handshake and a successful
  chat completion (`200`). The player lease itself is local loopback and does not falsely add a
  model or gateway billing call.

## Measurement and judgement

`measure:edge202-attachment-audio-playback-token-expiry` records the `1500ms` rig TTL, the
successful first `206` playback sequence, the post-expiry `404`, and the fresh-lease `206`
sequence. L3 therefore judges the bounded token lifetime and recovery path, not an invented
player cache miss.

The visible audio card is a coherent, non-jumping surface with a duration and progress affordance,
so L4 uses `C4`. The Play action is directly discoverable from the audio card without knowing the
lease protocol, so L5 uses `G1`.
