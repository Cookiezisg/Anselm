# EDGE-204 · real App read-aloud cache hit

## Result

GREEN for the zero-upstream-repeat path. The real App exposes read-aloud only when the workspace
has a speech route. The first click on a settled assistant turn performs one real speech synthesis,
obtains a first-class WAV attachment, and plays it. The second click on the same turn reuses that
attachment directly in the local player; it does not call the backend again. The backend cache
contract was also exercised with the same text and voice: `cached=false` followed by `cached=true`,
the same attachment ID, and exactly one real speech upstream request.

Formal session:
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-092531`

Real upstream: `https://api.anselm.website`; workspace `ws_596ef0896576237a`; conversation
`cv_7d1a1b46ce10febb`.

## Controlled sequence

1. The real workspace reported `GET /api/v1/read-aloud/availability` as `available=true`.
2. Before the UI walk, two identical real API requests for
   `EDGE204 cache sentinel. This sentence should be synthesized exactly once.` returned:
   `cached=false`, then `cached=true`; both returned attachment ID `att_8cfdd5c62a061cc3`.
   The LLM tap recorded one `/v1/audio/speech` request for this pair.
3. A separate real conversation turn was opened in the macOS App. The assistant response was
   settled, and the visible speaker affordance was present. Computer Use clicked it once. The
   backend recorded one UI `POST /api/v1/read-aloud:read` ending `200`, one real
   `/v1/audio/speech` request ending `200`, then a playback lease and range/full `206` reads.
4. The first click's preparation state was visible as a disabled/busy action before playback. After
   playback became available, clicking the same visible action again reused the in-memory attachment
   and did not create another `read-aloud:read` or `audio/speech` request. It toggled the same local
   player control, preserving the no-repeat-cost behavior.

## Five-channel evidence

- **Frame**: `recording.mov` is finalized (`166.938333s`). The real App shows a settled assistant
  answer, a discoverable speaker action, a busy/preparation transition on the first click, and a
  normal playable/completed control state. No internal cache key or provider detail is exposed.
  Captures include `/private/tmp/edge204-before-read.jpeg`,
  `/private/tmp/edge204-after-first.jpeg`, `/private/tmp/edge204-after-first-complete.jpeg`, and
  `/private/tmp/edge204-after-second.jpeg`.
- **Backend**: `backend.log` records availability, the two identical API reads (`200` then immediate
  `200`), the UI read (`200`, with the 16.708s synthesis wait), the playback lease, and range/full
  reads. There is no ERROR or panic.
- **SSE**: `sse.jsonl` records all three stream connections and the complete conversation turn,
  including assistant reasoning/text deltas and completed message close seq `8`. Read-aloud is a
  zero-token media action and correctly adds no chat message or fake SSE turn.
- **Frontend console**: `frontend.log` contains no Flutter/Dart application exception; only the
  known macOS IMK diagnostic is present.
- **LLM wire**: `llm.jsonl` records the real managed handshake, one speech request for the API cache
  pair, one speech request for the real UI first click, and successful `200` responses. There is no
  second speech request after the second UI click. Playback leases are local and do not add model
  calls.

## Measurement and judgement

`measure:edge204-readaloud-cache-hit` records `cached=false → true` for identical text/voice,
stable attachment ID, one upstream speech call for the cache pair, and zero additional upstream
speech calls for the second real UI click. The UI first-click busy interval is bounded by the
recorded backend request and the subsequent playback lease; the second click is local reuse rather
than a hidden network round trip.

The action stays in its original geometry, communicates preparation through the existing busy state,
and ends in the same compact audio control language as attachment playback, so L4 uses `C4`. The
speaker action is visible on the settled answer and does not require knowledge of the HTTP endpoint
or cache, so L5 uses `G1`.
