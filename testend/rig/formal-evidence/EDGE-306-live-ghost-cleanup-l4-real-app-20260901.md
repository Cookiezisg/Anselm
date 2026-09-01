# EDGE-306 导演器清 Live 幽灵：L4 真实 App 修复证据

## Formal session

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-170822`
- data: `/private/tmp/anselm-data-edge306-l4-real-20260901-fix4`
- workspace: `ws_cf98aab86d95ac34`
- recording: `screen.mov`, `121.523333s`
- final frame: `evidence/EDGE-306-final.png`
- injection: messages SSE connection dropped after 60s; the next connection returned HTTP `410`, then
  forwarded normally

## Product path

The real macOS App sent one ordinary user request: create eight separate documents named
`EDGE306-FIX4-01` through `EDGE306-FIX4-08`, put each matching name in its body, then read back
`EDGE306-FIX4-08`. The chain generated eight real `create_document` tool calls and one real
`read_document` call. The returned body was exactly `EDGE306-FIX4-08`.

The injected drop occurred while the tool chain was still active. The proxy journal records the
initial stream at `09:09:17.041820Z`, the drop at `09:10:17.044167Z`, HTTP 410 at `09:10:17.544062Z`,
and a fresh forwarded stream at `09:10:17.548060Z`. The App immediately re-read the conversation
messages, interactions, touchpoints, and todos after the 410.

## Visual result

The final Computer Use frame and AX tree show the complete assistant response, eight settled document
rows, and an Activity side-stage with eight entries (`Viewed` for the final read and `Created` for the
other seven). Neither the transcript nor Activity contains a `Live`, `Creating document...`, or
`Listening live` residue. The composer is back in its normal send state. The final frame is kept at
`evidence/EDGE-306-final.png` and the complete visual sequence remains in `screen.mov`.

The fix is deliberately narrow: when an assistant terminal root close arrives and its tree still has
a tool call without a closed result, `ConversationStreamProvider` performs the same REST rehydrate
used by a stream resync. Ordinary terminal turns take the existing single-pass path, so the repair
does not add a fetch or visual flicker to healthy turns. The focused regression test covers the exact
lost-result shape.

## Five-channel cross-check

- Channel 1 frames: window-owned macOS recording and final frame show no stale Live rows.
- Channel 2 backend: PID `37245` owned `:8743`; backend journal has no application `WARN`, `ERROR`,
  `panic`, or `FATAL` line.
- Channel 3 SSE: `ssetap` PID `37325` connected to all three streams; messages durable sequence
  `1..57` is monotonic, with the tool chain before the gap and final close frames after reconnect.
- Channel 4 frontend: direct App PID `37769`; the only runtime error is the expected injected
  `Connection closed while receiving data`; no Flutter, Dart, RenderFlex, RenderBox, Unhandled, or
  Exception application error is present. The macOS IMK line is host noise.
- Channel 5 LLM wire: `llmtap` PID `37221`; managed proof/install/models and chat completion calls
  returned HTTP `200`.
- Rig: `rig-check` passed all five physical observers before close; `rig-down` finalized the recording
  and left no managed process running.

## Judgment input

This evidence supports L4 `C4`: the repaired product state is visually coherent after a real stream
gap, with no stale Live residue, no competing duplicate execution state, stable settled geometry, and
an immediately usable composer. It does not claim L5 discovery beyond the ordinary request path.
