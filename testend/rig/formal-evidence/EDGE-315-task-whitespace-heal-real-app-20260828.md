# EDGE-315 · 空 task 尾空格腐化真实 App L2

## 台架

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-230718`
- data: `/private/tmp/anselm-data-edge315-physical-20260828-r1`
- App/window: conductor-owned macOS App PID 7538, window 5674, recorded bounds `80,40,1280,792`
- recording: `113.558333s`, finalized by `rig-down.sh`
- fixture: `EDGE-315 task fixture`, content `- [ ] first task\n- [ ] \n- [ ] last task`

## 用户可见动作与结果

1. 真实 App 打开 fixture，画面显示三个连续 checkbox 行；中间行没有文字但 checkbox、行高和间距均保留。
2. 点击中间空 task，输入 `temp`，再逐字退格清空。AX 树从 `temp` 恢复为无文字的中间任务，画面保留 checkbox 和可用输入位置。
3. 等待 autosave 后离开文档并重新打开。第一次重开仍显示三个 checkbox 行，右侧元数据显示 `26 chars`、`39 B`。
4. 第二轮重复输入/清空，等待保存后再次离开并重开。第二次重开仍显示三个 checkbox 行，AX 仍只出现 `first task`、空行和 `last task`，没有字面 `[ ]`、bullet 退化或被吞并的内容。

## 数据真相与五通道

- **Frame / Computer Use**: 每次点击、输入、退格、离开和重开后均重新读取 AX 树；录屏覆盖两轮往返，空 task 的 checkbox 始终可见。
- **Backend**: GET `/documents/doc_878fdcfa1c0e500e` 在两轮保存后都返回精确原文 `- [ ] first task\n- [ ] \n- [ ] last task`，`sizeBytes=39`；没有 `[ ]` 字面退化或额外空白。
- **SSE**: 三路 workspace 流均连接；notifications durable seq `16,17,18` 单调，包含 document.created 和两次 document.updated，无 gap。
- **Frontend console**: 没有 Flutter/Dart exception、RenderFlex/overflow、null-check 或未处理错误；唯一匹配的 `IMKCFRunLoopWakeUpReliable` 是已分类 macOS 输入法宿主提示。
- **LLM wire**: llmtap challenge/install/models 全部 `200`；本格是编辑器本地路径，不伪造模型调用或模型成功。
- **Rig**: `rig-check.sh` 在 App 运行时五通道通过，`rig-down.sh` 完整停止归属进程并封口录屏。

## 判定

- CODEX: `F1`（五通道事实一致性）
- Level 1: 已有 Markdown round-trip 与 heal 单元证据
- Level 2: 本证据支持真实 App 通过
- Level 3-5: 未测首反馈、ROI craft 和从零盲走，保持 `na`

## 复现要点

- 真实 fixture 不是只读预置：空 task 被实际输入和清空两轮，且通过离开/重开触发前端序列化与反序列化。
- 后端持久化原文在两轮之后均为 39 B，和初始内容逐字一致。
