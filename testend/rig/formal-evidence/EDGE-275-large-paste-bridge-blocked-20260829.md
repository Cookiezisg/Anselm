# EDGE-275 · 文档超 1MB · Computer Use 大载荷桥阻塞复验

本次不计入账本、不推进批次。真实 App 已由 conductor 启动并进入 Library 的 `Untitled` 草稿；尝试通过 Computer Use clipboard bridge 粘贴约 1 MiB 以及 100 KiB 分块时，桥接层均在 App 读取剪贴板前超时。随后读取 App 状态，正文仍为空，未触发文档创建、保存或后端 413，因此本次不能对产品的 `DOCUMENT_CONTENT_TOO_LARGE` UI 行为下结论。

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-142230`
- workspace: `ws_73d4149bc2083c04`
- App/window: `31115` / `6074`
- 现场：Library `Untitled` 草稿保持空白；无伪造内容、无 judge、无 COVERAGE 变更。
- `rig-check.sh` / `rig-down.sh`：均通过；录屏最终为 `screen.mov` `196.525000s`，五通道证据仅证明现场归属，不证明超限产品行为。

结论：这是 Computer Use clipboard bridge 的测试仪器限制，不是产品通过或失败。后续须使用可承载大载荷的分块输入/专用 fixture，在真实 App 中观察明确的 413 文案、草稿保留与无半成品文档后，才可写入 L2。
