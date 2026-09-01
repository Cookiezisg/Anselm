# EDGE-056 · SSE 410 SEQ_TOO_OLD：真实 App 五通道证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-171858`
- workspace: `ws_0c1e286907b105b8`
- App: PID `25632`, window `8105`, recording `screen.mov` (`232.303333s`)
- perturbation: App API proxy dropped the real `messages` stream at `17:21:22.088581` after the
  App had already received the baseline turn and durable cursor `seq=8`.

## Real replay eviction

1. Computer Use sent `Reply exactly EDGE056BASE`; the real App rendered `EDGE056BASE` and the
   independent messages witness recorded durable `seq=1..8` for that turn.
2. During the dropped App connection, the real HTTP product endpoint accepted 80 ordinary message
   turns through `POST /api/v1/conversations/{id}/messages`; the independent messages witness
   recorded durable frames through `seq=392`, exceeding the production replay ring of 256.
3. The App's delayed reconnect reached the conductor proxy, then the conductor forwarded the request
   to the backend. The backend journal records `GET /api/v1/messages/stream` as HTTP `410` at
   `17:22:22.674+0800`; a direct same-session probe captured the exact response:
   `{"error":{"code":"SEQ_TOO_OLD","message":"requested seq too old (evicted from replay buffer)","details":null}}`.
4. After that 410, the real App immediately refetched the selected conversation's messages,
   touchpoints, interactions and todos, and refetched its conversation lists. The stable Computer
   Use state showed the baseline user/assistant pair intact; no stale Live card remained and the App
   stayed usable.

## Five channels

- frames: `screen.mov` is window-owned and ffprobe-readable; the post-resync stable frame shows the
  intact baseline exchange and usable composer.
- backend: `backend.log` contains the real `410` request and no application `WARN`, `ERROR`, panic,
  or `FATAL` line.
- SSE: `sse.jsonl` independently observed the three streams; the messages stream recorded the
  baseline `seq=1..8` and flood through `seq=392`. The app proxy journal records the deliberate drop,
  delayed reconnect, and forwarding; it did not manufacture the `SEQ_TOO_OLD` response.
- frontend: `frontend.log` contains only the expected dropped-stream and injected 503 diagnostics,
  plus the known macOS IMK line; no FlutterError, DartError, RenderFlex, unhandled exception, or
  assertion was observed. The 410 itself is handled as recovery and therefore is not printed as an
  application error.
- LLM: `llm.jsonl` records the managed gateway challenge/install/models and the real baseline/flood
  chat traffic through the wire tap.

## Verdict

- L1 `pass`: an evicted cursor returns HTTP 410 with the stable `SEQ_TOO_OLD` error contract;
  focused stream and HTTP checks remain green.
- L2 `pass`: the real App experienced the actual backend replay eviction, refetched durable REST
  truth after 410, and remained visually usable; all five journals and the sealed recording are
  present in one formally attributed session.
- L3-L5 `na`: this edge validates transport recovery and has no independent product motion, visual
  craft, or discoverability claim. The tilde is applicability, not missing evidence.
