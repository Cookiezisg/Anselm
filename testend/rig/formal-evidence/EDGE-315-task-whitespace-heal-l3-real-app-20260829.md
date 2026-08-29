# EDGE-315 空 task 尾空格腐化：L3 真实 App 逐帧证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-230718`
- data: `/private/tmp/anselm-data-edge315-physical-20260828-r1`
- workspace: `ws_1cebabca5ade9b77`
- recording: `screen.mov`, `113.558333s`, `2784x1808`, `60fps`
- L2 foundation: `sessions/20260828-230718/evidence/EDGE-315-task-whitespace-heal-real-app-20260828.md`
- stable frames: `EDGE-315-l3-three-task-rows-stable.png`, `EDGE-315-l3-empty-middle-caret-stable.png`, `EDGE-315-l3-final-roundtrip-stable.png`

## Product path

真实 App 打开 `EDGE-315 task fixture`，内容为三条任务，其中第二条是空 task。分别两轮执行：点击第二条、输入 `temp`、逐字退格清空，等待 autosave，离开文档后重新打开。每轮都从画面和 AX 树确认空 task 仍是独立的 checkbox 行，没有被序列化成字面 `[ ]`、丢失 bullet 或并入相邻任务。

## Frame review and measurement

录屏以 1fps 抽样，并对正文任务区使用 ROI `760,430,1450,600`，通道容差为 8，阈值为 `0.0005`。全屏和 ROI 的变化均能归因到用户动作或文档进入/离开：

- 打开 fixture 的变化为 `000030→000031`, ROI `changedFrac=0.02118`；这是从 Untitled 进入文档的整块内容首次出现。
- 输入并清空期间的局部 caret/文字变化为 `000043→000044=0.00090`、`000049→000050=0.00074`；变化框只落在中间任务的输入区域。
- 两轮离开/重开对应 `000061→000062=0.02132`、`000066→000067=0.01703`、`000097→000098=0.02135` 和 `000098→000099=0.02120`；每次之后回到相同的三行结构。
- `000040`、`000062`、`000114` 三个稳定帧分别保留初次打开、中间空行 caret 和最终往返后的状态。稳定画面中 checkbox 等高、空行的可编辑位置保留，未观察到历史行漂移、行高跳变、空白行吞并或 caret 逃逸。

因此本格的 L3 判定是“用户动作引起的局部变化允许，静止期既有内容零跳变通过”，不是把输入本身误判为零变化。

## Five-channel cross-check

- **frames / Computer Use**: 真实坐标点击、输入、退格、离开和重开均在连续录屏中；三张稳定帧封存，且两轮空 task 均可见。
- **backend**: journal `212` 行；文档 GET 两次返回精确原文 `- [ ] first task\n- [ ] \n- [ ] last task`，`sizeBytes=39`；除正常 shutdown 外无 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- **SSE**: messages/entities/notifications 三流均连接；notifications durable `seq=16,17,18` 单调，无 gap。收台时的 EOF 是 conductor 关闭连接，不是产品断流。
- **frontend console**: `5` 行；无 Flutter/Dart、RenderFlex/RenderBox、Unhandled 或应用异常。`IMKCFRunLoopWakeUpReliable` 是已分类的 macOS 输入法宿主诊断。
- **LLM wire**: llmtap 的 proof challenge/install/models 均为 HTTP `200`；本格是编辑器本地路径，没有 completion，未伪造模型证据。
- **rig lifecycle**: `startup-gate` 通过屏幕权限、backend health、ssetap 和录屏启动；`rig-down.sh` 完成收台，无残留归属进程。

## Judgment boundary

- **L3 `pass (B2)`**：两轮输入/清空/持久化往返后，空 task 的结构和几何稳定；非用户触发的既有内容位移未发现。
- L3 只覆盖动态稳定性与 zero-jump，不把 checkbox 的视觉 craft 或从零盲走可发现性冒充 L4/L5；L4/L5 仍为 `na`。
