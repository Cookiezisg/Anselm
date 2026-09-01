# EDGE-247 · ServeMux 纯文本 404/405 改写 · 真实 App 五通道证据

## Session

- Formal session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-191204`
- Manifest: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-191204/manifest.json`
- Recording: `screen.mov`, `3104x1844`, `60fps`, `51.513333s`
- Backend: PID `48223`; App proxy: PID `48259`; SSE witness: PID `48292`; LLM tap: PID `48199`
- App: real macOS build, PID `48712`, window `11767`; App was pointed at the proxy, not a test HTTP client.

## Controlled perturbation

The proxy was configured with finite, single-use rewrites and recorded both the original and
forwarded request:

- `GET /api/v1/conversations` → `GET /api/v1/rig-unknown` produced the unmatched-route path.
- `GET /api/v1/conversations` → `PUT /api/v1/conversations` produced the matched-path,
  wrong-method path.
- After the two single-use rewrites, the proxy was transparent again; no later request was
  perturbed.

The app-proxy journal proves the injection was applied only to the intended first requests:

```text
2026-08-31T11:12:43.068461Z path_rewritten GET /api/v1/conversations -> /api/v1/rig-unknown
2026-08-31T11:12:43.073867Z method_rewritten GET /api/v1/conversations -> PUT
```

The backend journal proves the real ServeMux saw both cases:

```text
GET /api/v1/rig-unknown       status 404 bytes 76
PUT /api/v1/conversations     status 405 bytes 108
GET /api/v1/conversations     status 200 bytes 321
GET /api/v1/conversations     status 200 bytes 28
```

The focused contract test additionally verifies the response bodies are N1 JSON envelopes with
`ROUTE_NOT_FOUND` and `METHOD_NOT_ALLOWED`, preserves `Allow`, leaves a matched handler's own
404 untouched, and forwards `http.Flusher` for SSE. See
`backend/internal/transport/httpapi/router/chain_test.go:44-117` and
`backend/internal/transport/httpapi/router/chain.go:79-144`.

## Product observation

Computer Use observed the real App in the negative state:

- The left rail showed `Couldn't load conversations`.
- The explanation said `The local engine didn't return the conversation list.`.
- A visible `Try again` action was available; no raw HTTP status, route, stack trace, or
  `404 page not found` text leaked into the surface.
- Activating `Try again` after the finite perturbation budget was consumed recovered the normal
  Chat surface. The subsequent accessibility tree and stable recording frames showed `Recents 1`,
  `演示对话`, `演示工作台`, and the normal Composer.

Representative extracted frames from the recording:

- `/private/tmp/anselm-edge247-frames/frame-001.png`: stable error surface with explanation and
  Retry action.
- `/private/tmp/anselm-edge247-frames/frame-030.png`: error surface remains stable while waiting;
  no autonomous layout jump.
- `/private/tmp/anselm-edge247-frames/frame-060.png`: recovered Chat rail with one recent
  conversation; the later sort-menu appearance is a separate accidental Computer Use click and
  is not used as product evidence.
- `/private/tmp/anselm-edge247-frames/frame-103.png`: recovered normal Composer and recent item.

The first attempted perturbation used `GET → POST` on `/api/v1/conversations`. That endpoint is a
valid create route and correctly returned a business `400`, so that attempt is explicitly not part
of this evidence. The formal session above uses `GET → PUT`, which is the qualifying 405 case.

## Five-channel cross-check

1. **Frames / Computer Use:** real error copy and Retry are visible; Retry returns to a usable
   Chat surface. Stable frames show no flicker, clipping, or autonomous reflow.
2. **Backend journal:** the controlled unknown route is `404`, the controlled wrong method is
   `405`, and the unperturbed recovery requests are `200`.
3. **SSE witness:** `sse.jsonl` connects independently to notifications, messages, and entities;
   all three disconnect with clean EOF during rig shutdown. No fabricated durable message frame is
   claimed for this route-error journey.
4. **Frontend console:** no Flutter, Dart, `Unhandled`, `RenderFlex`, `ApiException`, `ERROR`,
   `FATAL`, or `panic` red flag occurred. The only remaining line is the macOS input-method
   framework message `error messaging the mach port for IMKCFRunLoopWakeUpReliable`, which is an
   OS-level input-method diagnostic, not an App/Flutter exception.
5. **LLM wire:** the same manifest records managed gateway challenge/install/models probes all
   returning `200`. This journey does not execute a model turn, so no completion or model response
   is claimed.

`rig-check` passed screen permission, D1 attribution, backend health, all three SSE connections,
LLM-tap wiring, proxy attribution, direct App/window attribution, external-overlay absence, and
recorder lifecycle bracketing. `rig-down` finalized the recording and left no testend, Flutter,
llama, appproxy, ssetap, or llmtap process behind.

## Five-level verdict basis

- **L1 / E1:** the contract tests and real error surface establish the three error elements:
  what happened, the local-engine state, and the next action.
- **L2 / F2:** the backend status sequence, three-stream SSE journal, and clean shutdown are
  bound to the same formal manifest; no durable SSE inconsistency is present.
- **L3 / A4:** the >1s negative load state remains visibly actionable with Retry; the recording
  shows a stable wait/error surface rather than a dead or silent UI.
- **L4 / C4:** the error and recovered surfaces retain their layout geometry, action placement,
  and readable hierarchy through the transition; extracted frames show no clipping, overlap, or
  autonomous jump. This is the applicable geometry check for this route-error surface, not a claim
  that unrelated document-selection geometry was tested here.
- **L5 / G1:** a user need not know the API route, method, envelope, or proxy: the visible message
  and `Try again` affordance expose both the state and recovery path.

This evidence does not waive the full campaign: the remaining coverage rows, forced interaction
queue, and phase-2 400+ Journey expansion remain governed by WRK-087.
