# EDGE-228 · ASR sidecar 无受管凭证

## Result

真实 App 的 L2 通过；L3-L5 以明确适用性 `na` 收口。该场景验证的是一个能力门：没有受管
Anselm 凭证时，语音输入入口必须诚实缺席，不能把会返回 `SPEECH_UNAVAILABLE` 的按钮展示给用户。
它不声称已经验证真实 ASR 成功、语音拒绝 taxonomy 或麦克风权限路径；EDGE-227 的真实拒绝场景
仍在强制人工尾队。

Formal session:
`/private/tmp/anselm-rig-formal-20260831-11-edge228/sessions/20260831-125311`

Workspace: `ws_4f8e861ff071beac` (`EDGE228 no managed ASR`). The conductor started with
`RIG_SEED=0` and an empty data directory. Its LLM tap pointed to the deliberately unreachable
`http://127.0.0.1:9`; this was only to make free-tier provisioning fail deterministically and
retain the wire observer. No successful managed gateway install or model call is claimed.

## Observed Product State

Computer Use created the workspace through the real onboarding surface. The settled Chat AX tree
contained `Mention an entity`, `Attach files`, and the text composer, but no microphone/voice input
button. The stable frame is
`sessions/20260831-125311/evidence/edge228-no-asr-entry-final.png`; it shows the same clean state:
Chat navigation, an empty landing prompt, and a composer with only `@`, attachment, and text input
affordances. There is no hidden or disabled ASR affordance competing with the empty Chat state.

The frontend predicate was also reviewed against the running build: `speechInputAvailableProvider`
requires a current capability row whose provider is `anselm` and whose model is `anselm-auto`; with
no managed row, `canVoice` is false and the microphone trailing action is not built.

## Five-Channel Evidence

- **Frame**: `screen.mov` finalized successfully at 60 fps (`3104x1844`), `rig-check` reported no
  external overlay, and the stable screenshot contains no ASR affordance or layout residue.
- **Backend**: `backend.log` records the expected best-effort provision failures with
  `challenge returned HTTP 502`; no application `ERROR`, `FATAL`, panic, Flutter, or layout error
  occurred. The failed provision did not create a managed key.
- **SSE**: `sse.jsonl` records `messages`, `entities`, and `notifications` connections for the
  created workspace and clean teardown. No speech or fabricated business frame was emitted.
- **Frontend console**: `frontend.log` contains no `DartError`, `FlutterError`, `RenderFlex`,
  unhandled exception, or application-level error; only the known macOS IMK host diagnostic is
  present.
- **LLM wire**: `llm.jsonl` contains the recorder-ready event and two failed proof-challenge
  attempts. There is no successful install, quota/model request, or speech WebSocket call.

`rig-check.sh` passed all five physical observer checks before teardown. `rig-down.sh` finalized the
recording and stopped the conductor-owned App, backend, SSE witness, LLM tap, and recorder; no
Anselm/tap process remained afterwards.

## Judgement Basis

- **L2 `F2` pass**: the real App frame/AX tree, backend journal, three SSE connections, frontend
  console, and wire journal agree that no managed credential exists and the ASR entry is absent.
- **L3 `A4` na**: this seam deliberately exposes no speech operation, loading state, or wait/cancel
  interaction; the >1s feedback law has no independent operation to measure here.
- **L4 `C4` na**: the absence gate produces no distinct speech result card, control, or artifact whose
  geometry/radius craft belongs to this item; those surfaces are judged by the enabled speech/audio
  journeys.
- **L5 `G1` na**: when the capability is not configured, there is no valid ASR entry to discover;
  discoverability of enabling/configuring speech belongs to the settings and enabled-route journeys,
  not this absence gate. This is an applicability boundary, not a claim that those journeys are done.

Existing focused evidence remains the source for L1:
`testend/rig/formal-evidence/EDGE-228-asr-no-managed-credential-20260826.md`.
