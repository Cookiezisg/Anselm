# EDGE-321 · 草稿文档首次编辑 · 真实 App L2

## 结论

`L2=pass`。真实 Flutter App 在正式五通道台架中验证了被动 Library 草稿的完整转正路径：空稿离开不创建；第一次正文输入创建一个文档并认领新 id；创建返回后继续输入仍留在同一个编辑器；切出再回到 Library 后正文保持一致。没有发现需要停线修复的产品问题。

本次不把 L3（动作反馈/等待舒适度）、L4（视觉 craft）或 L5（从零可发现性）冒充通过，三者仍由账本保留为 `na`。

## Session

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-135745`
- data: `/private/tmp/anselm-data-edge321-physical-20260829-r1`
- workspace: `ws_d2bed7a5fd1f05d3`
- App PID/window: `26895` / `5998`
- backend PID: `26380`; ssetap PID: `26429`; llmtap PID: `26357`
- recording: `screen.mov`, `145.613333s`; fixed frame: `evidence/EDGE-321-reopened-document.jpeg`

## Product path

1. 从已播种 Library 进入无选区态，画面显示 `Untitled` 草稿和正文引导 `Start writing, or press / for commands`。
2. 不输入，切换到 Chat 再回 Library；前后两次 `GET /documents/tree` 都是 2 条，只有 `上手指南`、`运营手册`，没有幽灵文档。
3. 在真实 App 正文区域输入 `EDGE321 body probe`。backend journal 只出现一次本次创建对应的 `POST /api/v1/documents`，返回 `201`，id 为 `doc_0c0e4971321227f6`，名称按空标题规则为 `Untitled`。
4. 创建完成后继续输入 ` + continued`。AX 树仍显示同一正文连续为 `EDGE321 body probe + continued`，侧栏出现单一 `Untitled` 行；没有清空、重复、跳回草稿或新增第二行。
5. 防抖保存后 `GET /api/v1/documents/doc_0c0e4971321227f6` 返回正文 `EDGE321 body probe + continued`，`sizeBytes=30`。对应后续写入是同一 id 的 `PATCH`，不是第二次创建。
6. 切换到 Chat 再回 Library，真实 App 重新渲染该文档，正文仍为 `EDGE321 body probe + continued`，右侧显示 `30 B`；固定帧已保存。

## 五通道证据

- **Channel 1 · Computer Use/帧**：使用 `@oai/sky` 读取空态、首次输入、认领后侧栏和重开后的 AX 树；重开固定帧显示正文、单一侧栏行和右侧 `30 B`。
- **Channel 2 · backend journal**：健康检查为 `200`；本格创建只有一条 `POST /documents` `201`，后续为同 id 的 `PATCH`；无 `WARN`、`ERROR`、`panic`、`FATAL`。
- **Channel 3 · SSE witness**：ssetap 连接 `notifications`、`messages`、`entities` 三流；本格观察到单调 durable `seq=16` 的 `document.created` 和 `seq=17` 的 `document.updated`，没有第二个创建信号。
- **Channel 4 · frontend console**：rig-check 归属真实 App/window；无 Flutter、Dart、RenderFlex、Unhandled 或应用异常。仅有已知 macOS IMK 宿主诊断 `IMKCFRunLoopWakeUpReliable`。
- **Channel 5 · managed LLM wire**：llmtap 归属通过；`/v1/proof/challenge`、`/v1/install`、`/v1/models` 均为 `200`，真实 App 没有绕过 recording tap。

## 收台与回归

- `rig-check.sh`：五通道全部通过，录制区域无外部遮挡。
- `rig-down.sh`：录屏正常结束，App/backend/ssetap/llmtap 均停止，无残留。
- `mise exec -- flutter test test/features/library/library_test.dart`：`57 tests passed`。
- `anchors.py check`：`10 anchors` passed。
- `git diff --check`：通过。

## 判定映射

- L1: `G1`，既有 focused evidence 保留。
- L2: `F1`，本文件及同 session 五通道证据。
- L3-L5: `na`，本次没有独立动作到首反馈测量、ROI craft 测量或盲走可发现性实验。
