# EDGE-254 · 账本 / 警报复核

L2 真实 App 复验已通过后，`alarms.py check` 按设计打开 `discovery-collapse`：近 50 条 live judgment 的 fail 占比为 2.0%，低于 5% 初始地板。该警报不是被忽略，而是本轮完成锚点校准后重新检查了正式 session、红现场和修复 session：

- 红现场明确记录了真实产品缺陷，未写成 pass。
- 修复 session `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-200325` 由五通道台架独立观察，backend/SSE/frontend/LLM 证据均可追溯。
- 本次 pass 只写入已完成的 L2，未提前批量盖章；后续各 level 仍逐级执行。

结论：当前低 fail-share 来自先前已经清理过的一段现有队列，不能证明“没有问题”；本轮保持锚点状态有效，警报在该 journal 水位销账后解除，若新增证据再次触发则重新停拍。
