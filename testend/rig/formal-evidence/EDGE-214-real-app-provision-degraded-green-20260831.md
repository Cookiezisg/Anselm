# EDGE-214 · real App keeps boot usable when free-tier provisioning degrades

## Result

GREEN for the degraded provisioning boundary. A fresh real App was started with an empty data
directory and a deliberately closed loopback gateway. The managed install therefore failed, but
the App did not hang in onboarding or expose a phantom free-tier state: after creating a workspace,
it released the user into the normal Chat shell with the main navigation and Composer available.
The no-machine-fingerprint and persistence-failure branches are covered separately by the focused
and race Go tests named below; this session does not claim a successful managed gateway install.

Formal session:
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-110713`

Workspace: `ws_6c8ae439074bc64a` (`EDGE214 degraded boot`). The tap upstream was
`http://127.0.0.1:1/v1`, used only to make the real install failure deterministic while retaining a
real wire observer.

## Controlled sequence

The conductor started with `RIG_SEED=0`, so no workspace or managed row existed. The real App
showed the onboarding form, Computer Use created the workspace, and the App transitioned to the
normal Chat shell. The final frame is
`evidence/edge214-chat-released.png`; it shows `Chat`, `Entities`, `Scheduler`, `Library`, `New
chat`, `Settings`, the workspace name, and an active Composer. No onboarding spinner, dead-end
error, or fake quota gauge remained.

The application-level focused/race coverage for the other degraded branches is:

- `backend/internal/app/freetier/freetier_test.go`: `TestEnsure_DegradesWithoutFingerprint`,
  `TestEnsure_DegradesOnInstallError`, and `TestEnsure_DisplayNameConflictIsIdempotent`.
- `backend/internal/app/freetier/freetier_test.go`: concurrent provisioning and cancellation
  tests prove a failed or stopped flight cannot persist a managed row after the workspace lifecycle
  has ended.

## Five-channel evidence

- **Frame**: `screen.mov` is finalized (`33.421667s`) and the stable tail frame shows the normal
  Chat shell after onboarding, with no provisioning dead-end or layout residue.
- **Backend**: `backend.log` records the workspace creation and two best-effort install failures
  against the deliberately closed upstream. No application panic, `ERROR`, or `FATAL` occurred;
  graceful shutdown completed with zero sandbox handles left.
- **SSE**: `sse.jsonl` records all three resident streams connected for `ws_6c8ae439074bc64a`.
  The streams disconnect cleanly at teardown; no fabricated business event is emitted for the
  failed provisioning attempt.
- **Frontend console**: `frontend.log` contains the normal App launch and no Flutter/Dart,
  RenderFlex, or unhandled application exception. The sole matching diagnostic is the known macOS
  IMK host message.
- **LLM wire**: `llm.jsonl` contains the recorder-ready event and two real proof-challenge
  attempts. There is no successful install, quota response, model request, or invented managed
  success. `rig-check` passed all five channels before teardown and `rig-down` finalized the MOV
  and stopped every conductor-owned process.

## Judgement

L2 uses `F2`: the real App frame, backend install-failure journal, three SSE connections, and
closed-upstream wire evidence agree on a degraded but usable startup.

L3 uses `A4`: the transition from onboarding to the local shell completes without an unbounded
  wait; the user can immediately continue with local app surfaces or configure another model.

L4 uses `C4`: the final shell has a coherent navigation rail, workspace footer, centered empty-chat
  state, and Composer with no orphaned loading/error surface.

L5 uses `G1`: the user does not need to know provisioning internals, install IDs, or error codes to
  reach a usable App. The free-tier failure remains an absence rather than a dead onboarding path.
