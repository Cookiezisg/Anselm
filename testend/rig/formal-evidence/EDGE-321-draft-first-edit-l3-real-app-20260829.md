# EDGE-321 · 草稿文档首次编辑：L3 真实 App 逐帧证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-135745`
- data: `/tmp/anselm-data-edge321-physical-20260829-r1`
- workspace: `ws_d2bed7a5fd1f05d3`
- recording: `screen.mov`, `145.613333s`, `2784x1808`, `60fps`
- L2 foundation: `testend/rig/formal-evidence/EDGE-321-draft-first-edit-real-app-20260829.md`
- stable frames: `EDGE-321-l3-empty-draft-stable.png`, `EDGE-321-l3-first-edit-stable.png`, `EDGE-321-l3-claimed-and-reopened-stable.png`, `EDGE-321-l3-final-stable.png`

## Product path

从真实 Library 的无选区态进入空 `Untitled` 草稿，先离开再返回确认空稿不被偷偷创建；随后在正文区域输入 `EDGE321 body probe`，在同一编辑器继续输入 ` + continued`，等待认领和防抖保存，再切换到 Chat 后返回 Library，观察编辑器、侧栏和属性面板是否连续。

## Frame review and measurement

对 `screen.mov` 抽取全程 `1fps`，用 `threshold=0.0005` 对内容 ROI `760,250,1500,950` 复核。代表性变化为：

- `000023→000024=0.03887`、`000028→000029=0.03889` 是空稿进入和离开/返回的用户导航窗口；
- `000064→000065=0.00431` 是首次正文输入，`000065→000066=0.02125` 是创建后界面认领同一文档的收敛窗口；
- `000098→000099=0.03491`、`000103→000104=0.03486` 是切回 Library 的用户导航窗口；
- `000104` 到 `000145` 的约 41 秒稳定段无 ROI 变化输出。稳定帧显示侧栏只有一个 `Untitled`，正文为 `EDGE321 body probe + continued`，右侧属性为 `30 B`，没有清空、重复创建、光标跳回草稿或晚到重挂。

本格 L3 判断首次编辑从被动草稿到已认领文档时的动态连续性和收敛，不把用户主动切换页面造成的整面变化算作产品跳变。L2 已证明创建一次、后续同 ID PATCH 和重开后的 REST 真相；L4/L5 不在本格结论内。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 录屏覆盖空稿、首次输入、继续输入、认领后和返回 Library；四张稳定帧已封存。
- **backend**: journal `240` 行；空稿离开无创建，首次输入仅一个 `POST /documents` `201`，后续同 ID 更新；无应用级 `WARN`、`ERROR`、`panic` 或 `fatal`。
- **SSE**: messages/entities/notifications 三流均连接；notifications durable `seq=16..17` 单调，对应一次 `document.created` 和一次 `document.updated`，无第二个创建信号。
- **frontend console**: `4` 行；无 Flutter/Dart、RenderFlex、RenderBox、Unhandled 或 Exception 应用级红线；仅有已分类 macOS IMK 宿主诊断。
- **LLM wire**: llmtap proof challenge/install/models 全部 HTTP `200`；本格是本地 Library 编辑路径，不伪造 completion 调用。
- **rig lifecycle**: startup gate、`rig-check` 和 `rig-down.sh` 收台通过，App、backend、ssetap、llmtap、录屏归属一致，无残留。

## Judgment boundary

- **L3 `pass (B2)`**：空稿首次输入后编辑器连续认领新 ID，后续输入不丢失，离开/返回不重挂，稳定态无晚到覆盖。
- L4/L5：`na`。本证据不宣称空稿视觉 craft 已完成，也不宣称首次用户无需引导即可理解“输入即创建”的语义。
