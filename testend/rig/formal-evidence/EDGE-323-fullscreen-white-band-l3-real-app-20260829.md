# EDGE-323 · 进全屏白带：L3 真实 App 逐帧证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-230609`
- data: `/tmp/anselm-data-edge323-live-20260829`
- workspace: `ws_92491c0f9c37d075`
- law: `B2`
- verdict: `pass` for L3; L4/L5 `na`

## Product path

在真实 macOS App 中先观察窗口态，再执行原生全屏进入，确认内容保持可读且没有白色工具栏带或黑屏，再执行原生全屏退出并确认窗口装饰和内容恢复。动作通过 Computer Use 完成：点击窗口控制项进入全屏，使用 `ctrl+super+f` 退出；进入和退出后的 AX 状态均为正常 App 内容，退出后窗口控制项恢复。

## Frame evidence

正式窗口绑定录像为 `screen.mov`，时长 `59.525000s`，尺寸 `3104x1844`。稳定帧已封存：

- `evidence/EDGE-323-window-stable-before.png`
- `evidence/EDGE-323-window-stable-fullscreen.png`
- `evidence/EDGE-323-window-stable-after.png`

独立整屏录像为 `evidence/display-screen.mov`，时长 `38.333333s`，尺寸 `2880x1800`。它覆盖原生 Space/window transition 的用户可见屏幕；`ffmpeg blackdetect=d=0.1:pix_th=0.10` 未发现黑段。代表帧为：

- `evidence/EDGE-323-display-fullscreen-before-exit.png`
- `evidence/EDGE-323-display-windowed-after-exit.png`

窗口绑定录像的同一检测命令报告唯一黑段 `35.083333–35.75`，持续 `0.666667s`。该黑段只存在于按旧 window ID（`6696`）裁取的 instrument 录像；对应整屏录像连续显示 App/菜单栏的原生全屏切换，没有黑屏、白带或内容丢失。原始窗口录像不被删除、不被改写，因此这个仪器盲区是可复核事实，而不是被隐去的失败。

结论是：产品可见画面通过 B2；窗口 ID 在原生切换瞬间的采集盲区作为仪器问题单独记录，不修改 Flutter 全屏实现，也不把它计作产品闪烁。进入全屏后的稳定帧、退出后的稳定帧和 Computer Use 复查均正常，未观察到 toolbar 白带、内容重排、窗口溢出或退出后卡死。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 已启动；进入和退出全屏后的 AX 状态正常；整屏录像无黑段，稳定帧已封存。
- **backend**: `backend.log` 为 `112` 行；本 session 无应用级 `WARN`、`ERROR`、`panic` 或 `fatal`。
- **SSE**: `sse.jsonl` 连接 notifications/entities/messages 三流并在收台时 EOF；本格只改变窗口状态，不应产生业务 durable 帧。
- **frontend console**: `frontend.log` 为 `4` 行；唯一宿主诊断为 `IMKCFRunLoopWakeUpReliable`，无 Flutter/Dart、RenderFlex、RenderBox、Unhandled、Exception 或 overflow 红线。
- **LLM wire**: `llm.jsonl` 仅有台架生命周期记录；本格不触发模型调用，不伪造 completion 证据。
- **rig lifecycle**: startup gate、两次 `rig-check` 和 `rig-down.sh` 均通过；backend PID `62253`、ssetap PID `62280`、llmtap PID `62229`、App PID `62598` 和 recorder PID `62647` 均有 manifest 归属，无外部 overlay。

## Judgment boundary

L3 只判断全屏进入/退出的动态收敛、稳定性和用户可见画面连续性，因此 `pass (B2)`。L4/L5 在本格不宣称视觉 craft 或从零发现性结论，保持 `na`。
