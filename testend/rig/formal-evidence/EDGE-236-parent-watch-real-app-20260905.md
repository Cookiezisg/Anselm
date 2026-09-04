# EDGE-236 · 父进程死人开关：真实 App-owned sidecar 复验

## Scope

This evidence covers the production wiring in which the real macOS App launches the copied
`anselm-server` beside the App bundle with `ANSELM_PARENT_WATCH=1`. The test deliberately kills the
real App with `SIGKILL`; it does not call the App's graceful exit hook and does not send a signal to
the sidecar directly.

## Real App session

- Session: `/private/tmp/anselm-rig-formal-20260905-edge236d/sessions/20260905-051920`
- App PID: `65894`; App-owned sidecar PID: `65993`; sidecar listener: `127.0.0.1:53572`
- App-owned data root: `/Users/sunweilin/Library/Containers/website.anselm.app/Data/.anselm-edge236-formal-1788556760`
- `RIG_APP_OWNS_BACKEND=1`, `RIG_SEED=1`, real macOS App build, real window recording
- The repaired seed path authenticated with the App-owned bearer and created a workspace plus the
  standard fixture data. `rig-up` and the five-channel health gate passed before the kill;
  `rig-down` sealed a `3016x1758`, `60fps`, `112.161667s` recording.
- Before the kill, the App was visibly healthy at the onboarding surface:
  `sessions/20260905-051920/evidence/EDGE-236-before-kill.png`.

## Kill and observations

At `2026-09-05 05:21:07.174164Z` the App PID `65894` was killed with `SIGKILL`. The sidecar PID and
its listener were gone by the second 250ms observation; no process under the isolated data root
survived. The independent SSE observer had connected all three streams before the kill and then
recorded connection-refused discovery attempts rather than silently retaining a live subscription.
This proves the real App-to-sidecar stdin pipe closes on App death and that the sidecar does not
remain as an orphan.

Because an App `SIGKILL` also closes the App-owned stderr pipe, the real App session cannot expose
the sidecar's final shutdown lines through the Flutter console. A same-binary, independent parent
control was therefore run to inspect that specific channel without changing the product path:

- Parent PID `63578` held a pipe open to the same `server` binary; child PID `63581` listened on
  `127.0.0.1:8874` with `ANSELM_PARENT_WATCH=1`.
- Killing only parent `63578` caused child `63581` to exit and release the port on the first 100ms
  poll.
- The child log contains, in order, `shutting down gracefully` followed by
  `sandbox shutdown: all handles killed {count: 0}`:
  `/private/tmp/anselm-edge236-parent.dDqBPy/backend.log`.

## Five-channel review

- Channel 1: real App window recording is readable and sealed; the clean seeded App frame is
  preserved before the destructive kill.
- Channel 2: the real sidecar journal is healthy through the kill boundary; the independent control
  log supplies the final shutdown lines that the closed App stderr pipe cannot carry.
- Channel 3: all three SSE streams connected before the kill; after it, the observer records the
  listener disappearing and structured connection refusal, without inventing a terminal product
  frame.
- Channel 4: the frontend journal contains only the known unsigned-build keychain timeout fallback
  and the expected lexical-search fallback because an unsigned App sandbox cannot execute the
  bundled embedder from its container data root; no Flutter exception, render error, panic, or
  unhandled application error was observed.
- Channel 5: the real managed bootstrap tap was connected; this lifecycle-only path issued no model
  completion and claims none.

## Level decision

- L1 remains `F5` from the existing focused wiring evidence.
- L2 is applicable and is judged `F5`: the real App-owned sidecar, listener, independent observer,
  process table, and same-binary shutdown journal agree after a true parent `SIGKILL`.
- L3 is not applicable: parent-death cleanup has no user-operated transition or waiting surface; the
  App is intentionally dead, so there is no product interaction latency to judge.
- L4 is not applicable: this is an invisible process-lifecycle safety mechanism, not a rendered
  product surface.
- L5 is not applicable: users do not discover or invoke the stdin deadman switch; it is an internal
  reliability mechanism.

The first App-owned attempt using `/private/tmp` was rejected by the macOS App sandbox and the
second attempt exposed the rig's unauthed seed call. Both are retained as setup diagnostics only;
neither is used as acceptance evidence.
