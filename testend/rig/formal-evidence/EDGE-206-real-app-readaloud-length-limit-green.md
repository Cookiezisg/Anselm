# EDGE-206 · real App read-aloud length limit

## Result

L2/L3 GREEN for the real read-aloud input boundary. A request containing exactly `4001` CJK
runes reached the real local sidecar behind the acceptance rig and returned HTTP `400` with
`READALOUD_TEXT_TOO_LONG` before synthesis. The backend request elapsed at `0ms`, and the
managed LLM wire recorded no `/v1/audio/speech` request for this rejected input.

Formal session:
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-095420`

## Five-channel evidence

- **Frame**: the conductor launched the real macOS App, bound the Anselm window, and finalized
  `screen.mov` at `155.681667s`. The App reached a stable Chat state with a usable composer.
  The attempted 4001-rune paste remained in the composer and did not submit as a real user turn;
  this is explicitly non-evidence for the UI error surface, not a claimed product pass.
- **Backend**: `backend.log` records `POST /api/v1/read-aloud:read` with status `400` and
  `elapsed_ms=0`; the response body contains `READALOUD_TEXT_TOO_LONG`. No backend ERROR,
  panic, or application WARN was recorded.
- **SSE**: `sse.jsonl` records the App's real chat activity and clean disconnect of all three
  streams. The rejected read-aloud request created no chat turn and no durable read-aloud event.
- **Frontend console**: `frontend.log` has no Flutter/Dart application exception, layout
  overflow, or unhandled error; it contains only the known macOS IMK diagnostic.
- **LLM wire**: `llm.jsonl` records the managed challenge/install/models and the real chat
  completions used while observing the App, but zero `/v1/audio/speech` calls. The rejected
  read-aloud input therefore did not spend a speech request.

## Boundary facts

- `GET /api/v1/read-aloud/availability` returned `available=true`; the capability was not
  falsely hidden while the route was available.
- The rejected payload was generated as `"界" * 4001`, so the boundary is measured in Unicode
  runes rather than bytes or UTF-16 code units.
- The local focused regression independently covers empty input and the same over-limit shape;
  this formal session proves the boundary through the running App-side backend and real managed
  wiring without calling upstream speech.

## Scope of judgement

L2 uses `F4`: the HTTP rejection, backend timing, and absence of an upstream speech request agree
across the backend and LLM-wire channels. L3 uses `A1`: the boundary response is immediate and
does not leave a progress state waiting on synthesis.

L4 and L5 remain open. The 4001-rune payload was not successfully submitted through the real App
composer in this session, so this evidence does not establish the visible error treatment,
copywriting, visual craft, or discoverability of the long-text path.
