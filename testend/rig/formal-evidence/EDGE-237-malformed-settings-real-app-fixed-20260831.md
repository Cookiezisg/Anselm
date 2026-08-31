# EDGE-237 · 坏 settings.json · 真实 App 修复后复验

## 结论

`settings.json` 损坏时 backend 必须拒绝启动，App 必须快速展示可理解的启动失败态；修复文件后，用户点击一次 `Retry` 必须恢复到可用 App。该行为已用真实 macOS App、App-owned sidecar、真实编译产物和 Computer Use 复验。

## Formal session

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-154826`
- data: `/Users/sunweilin/Library/Containers/website.anselm.app/Data/.anselm-edge237-20260831-formal`
- app: `/Users/sunweilin/Developer/Anselm/frontend/build/macos/Build/Products/Debug/anselm.app`
- recording: `49.346667s`, `3104x1844`, `60fps`
- startup probe: `RIG_APP_OWNS_BACKEND=1 RIG_EXPECT_BACKEND_FAILURE=1`

## Failure path

1. `settings.json` was set to `{not json` before launch.
2. The App-owned sidecar emitted `settings: parse ... invalid character 'n' looking for beginning of object key string` and exited before binding a loopback listener.
3. `frontend.log` contains no `FlutterError`, Dart exception, `RenderFlex`, or other unexplained runtime redline.
4. Computer Use saw `Can't reach the local engine`, the human-readable startup guidance, and a visible `Retry` button. The failure frame is `evidence/frames/edge237-failure.jpg`; the first recorded frame already shows the failure state after the sidecar fatal line.
5. The old implementation waited for the full health-poll budget after the child had already exited. Stop-and-fix added `_awaitHealthOrExit`, so the deterministic child exit now transitions immediately instead of leaving a motionless connecting screen for about 20 seconds.

## Recovery path

1. The file was restored to valid `{}` without changing the database.
2. Computer Use clicked the visible `Retry` button once.
3. The App spawned a new sidecar, which reached health `200` on `127.0.0.1:55001`; the App returned to the `Create a workspace` landing state. The recovered frame is `evidence/frames/edge237-recovered-final.jpg`.
4. `rig-down.sh` stopped the App and llmtap, finalized the recording, and the post-run process audit found no `anselm`, `anselm-server`, `llmtap`, or `screencapture` survivor.

## Five-channel truth

- Channel 1: window-bound `screen.mov`, plus failure and recovery frames.
- Channel 2: `backend.log` contains the exact malformed-settings fatal line and the later healthy retry sidecar lines.
- Channel 3: `sse.jsonl` contains one explicit `not_applicable` record for each of `messages`, `entities`, and `notifications`; no HTTP listener existed during the failure, so no SSE connection is claimed.
- Channel 4: `frontend.log` contains the real App launch, the sidecar fatal output, the successful retry health request, and no unexplained Flutter runtime error.
- Channel 5: `llm.jsonl` contains llmtap `ready` plus an explicit `not_applicable` record; no LLM request was possible before the backend started.
- `rig-check.sh` passed in the live session; `rig-down.sh` and `ffprobe` passed after capture.

## Judgment boundary

- L1: `E1`, focused settings tests and malformed-vs-absent semantics.
- L2: `F6`, the negative startup probe and the same-session Retry recovery are cross-checked across all five channels; unavailable SSE/LLM paths are explicit, not empty-file waivers.
- L3: `A1`, immediate child-exit feedback is locked by the focused supervisor test and the first recorded failure frame; no long blank connecting interval remains after the fatal line.
- L4: `C4`, the failure state is centered, readable, consistently spaced, and has one clear primary action; no visual redline was found in the Computer Use frame review.
- L5: `G1`, the visible `Retry` affordance is directly discoverable in the failure state; the App recovery landing state is also reachable without hidden controls.
