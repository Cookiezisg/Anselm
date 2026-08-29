# EDGE-327 · workspace 热切换三拍：L3 真实 App 逐帧证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-231929`
- data: `/tmp/anselm-data-edge327-live-20260829-r1`
- source workspace: `ws_b02491a2789d60b4` (`EDGE327 source`)
- target workspace: `ws_bfa33c59445e0abb` (`EDGE327 target`)
- conversation: `cv_0758205ed0169078` (`EDGE327 deep-link source probe`)
- law: `B2`
- verdict: `pass` for L3; L4/L5 `na`

## Product path

1. 在真实 App 中创建 `EDGE327 source`，创建并完成一条真实网关对话，使源 workspace 有一条可回访的深链。
2. 创建 `EDGE327 target`，再通过底部 workspace 菜单切回源 workspace，打开 `EDGE327 deep-link source probe` 深链。
3. 在深链保持打开时再次打开 workspace 菜单，点击 `EDGE327 target`，观察三拍：旧深链先离开，workspace 名称切换，目标 workspace 的空 Chat landing 再稳定出现。
4. 目标 landing 稳定观察 `6s` 后切回源 workspace，确认源对话仍在列表并可回访，没有旧右岛、旧正文或旧对话残留到目标 workspace。

## Frame evidence

正式窗口录像 `screen.mov` 为 `213.288333s / 3104x1846`，抽取 `101` 个 `1fps` 样本到 `evidence/frames-1fps/`。代表帧：

- `evidence/EDGE-327-switch-menu.png`: workspace 菜单同时列出 source/target，当前项有明确勾选；
- `evidence/EDGE-327-target-landing.png`: 切换后的目标空 Chat landing，目标 workspace 名称已生效；
- `evidence/EDGE-327-source-revisit.png`: 回到 source 后原对话仍保留在 Recents，可继续回访。

Computer Use 的即时 AX 状态确认：源深链包含原始用户消息和完整回答；点击目标后立刻变为 `EDGE327 target` 的空 Chat，目标 composer 和导航完整；等待 `6s` 后仍是同一状态；切回 source 后原对话重新出现在 Recents。`blackdetect=d=0.1:pix_th=0.10` 对全录像没有黑段输出，静止期没有发现 B2 所定义的既有内容非用户跳变。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 完成两个 workspace、真实对话、深链打开、目标切换、稳定等待和源回访；录屏与 AX 均显示三拍收敛。
- **backend**: `backend.log` 为 `368` 行；源 conversation/interactions/messages/workdir/todos 读取均为 `200`，目标 `POST /workspaces/ws_bfa33c59445e0abb:activate` 为 `200`，目标 conversations/workdir-groups 读取为 `200`；无应用级 `WARN`、`ERROR`、`panic` 或 `fatal`。
- **SSE**: `sse.jsonl` 为 `351` 行，覆盖 source/target 两个 workspace；messages durable seq=`1..64`，notifications durable seq=`1..2`，均单调无重复，entities 连接正常且本场景无业务 durable 帧。
- **frontend console**: `frontend.log` 为 `4` 行；唯一 `IMKCFRunLoopWakeUpReliable` 是已知 macOS 宿主诊断，无 Flutter/Dart、RenderFlex、RenderBox、Unhandled、Exception 或 overflow 红线。
- **LLM wire**: `llm.jsonl` 为 `28` 行，其中 challenge/install/models 和真实 chat completion 请求均为 HTTP `200`；深链建立使用真实网关，不伪造完成结果。
- **rig lifecycle**: startup gate、窗口/App/backend/ssetap/llmtap 归属和 `rig-down.sh` 收台均通过，无残留进程。

## Judgment boundary

L3 `pass (B2)` 只判断热切换三拍的可见动态稳定、目标落地和源回访；L2 既有五通道切换正确性证据继续保留。L4 不宣称 workspace 菜单的视觉 craft 已完成，L5 不宣称从零用户发现该入口，因此均为 `na`。
