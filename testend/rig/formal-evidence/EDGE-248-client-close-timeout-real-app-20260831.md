# EDGE-248 · 客户端断连与请求超时 · 真实 App 边界证据

## Session

- Formal session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-192329`
- Manifest: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-192329/manifest.json`
- Recording: `screen.mov`, `3104x1844`, `60fps`, `50.706667s`
- App: real macOS build, PID `49928`; proxy: `49453`; backend: `49405`; SSE witness: `49493`;
  managed LLM tap: `49373`.

## Real App cancellation

The proxy delayed the exact `GET /api/v1/workspaces` response path by `15000ms`. Computer Use
observed the real App in the stable state `Setting up your workspace...`. The App was then
terminated while that client request was still pending. The proxy journal records:

```text
request  GET /api/v1/workspaces  delayMs=15000
canceled GET /api/v1/workspaces  delayMs=15000  canceled=true
```

The recording's first thirteen 1fps contact-sheet frames show the same readable setup state; the
last frame shows the normal Chat surface after an earlier retry completed. There was no blank
window, stack trace, or frontend crash before shutdown. The frontend journal contains only the
normal Flutter VM line; no Flutter/Dart/RenderFlex/Unhandled/Exception application red flag.

This is intentionally not claimed as a backend `CLIENT_CLOSED` response. The cancellation happened
inside the recording proxy's pre-forward delay, so that particular request never reached the
backend. The backend journal contains the earlier transparent workspace retries as `200`, and no
false `499` is inferred. The server-side mapping itself remains covered by the focused tests in
`backend/internal/transport/httpapi/response/errmap_test.go:83-103`:

- `context.Canceled` → HTTP `499`, code `CLIENT_CLOSED`.
- `context.DeadlineExceeded` → HTTP `504`, code `REQUEST_TIMEOUT`.
- wrapped/unknown errors retain typed mapping or suppress internal details.

## Channel and lifecycle evidence

- **Frames / Computer Use:** real loading copy remained visible while the delayed client request
  was pending; the client was closed without the App becoming unresponsive or showing a raw
  exception.
- **Backend:** manifest-bound journal remained healthy and records only the requests that actually
  reached the server; no panic or unexplained application error was introduced.
- **SSE:** `sse.jsonl` records independent connections to messages, entities, and notifications;
  all three closed cleanly during rig shutdown.
- **Frontend console:** no application-level red line. The session was stopped intentionally while
  the client was pending, so no post-disconnect UI terminal state is invented.
- **LLM wire:** managed challenge/install/models probes are recorded; this cancellation path does
  not execute a model turn, so no completion is claimed.

`rig-down` finalized the recording and stopped the App, proxy, backend, SSE witness and LLM tap.
The only process found outside this session was an older stale screen recorder from session
`20260831-170435`; it was terminated separately by PID after verifying its command line and no
current rig process remained.

## Five-level boundary

- **L1 / E1:** focused transport tests establish both typed mappings and non-leaking fallback.
- **L2 / F2:** the real App initiated the delayed request, the client-side cancellation was
  journaled, the three SSE channels and the managed bootstrap channel were present, and shutdown
  left no active process or fabricated server result.
- **L3 / A4:** not independently applicable to this transport mapping. The operation's visible
  waiting feedback belongs to the owning bootstrap/feature surface; this session records it as
  evidence but does not claim the server mapping itself has a separate progress contract.
- **L4 / C4:** not independently applicable. `CLIENT_CLOSED`/`REQUEST_TIMEOUT` are response
  taxonomy seams and create no independent visual component; their error-card geometry belongs to
  the feature that owns the timed operation.
- **L5 / G1:** not independently applicable. A disconnected client cannot discover or activate a
  response it will never receive; discoverability belongs to the owning feature's retry/cancel
  entry point.

The real App cancellation limitation is preserved here rather than hidden. A future feature-level
timeout journey may revalidate the relevant visual levels with that feature's own visible error
surface; it must not reuse this transport-only evidence as a shortcut.
