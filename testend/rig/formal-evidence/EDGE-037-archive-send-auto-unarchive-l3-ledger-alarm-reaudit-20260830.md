# EDGE-037 L3 · 账本告警独立复审

## 复审结论

本次 `gap-too-fast` 与 `discovery-collapse` 是账本统计护栏的真实提示，不是产品证据。复审者重新读取了本次正式 session 的原始五通道文件、60fps 局部帧和裁决命令：证据链完整，未发现橡皮章裁决或阈值被绕过。告警按原阈值逐条销账；不修改算法、法典、锚点或顺序门。

## 逐项核验

- `gap-too-fast`: 触发原因是本轮裁决写入时间集中，不能用它推断本格未观察。独立核对了 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-154644` 的 `screen.mov`、`backend.log`、`sse.jsonl`、`frontend.log`、`llm.jsonl`，并确认 `rig-down` 已封口且进程组归零。
- `discovery-collapse`: 近期窗口缺少 fail 只说明统计窗口偏干净，不能抬升产品结论。复审确认 L3 使用了真实 60fps 帧和 `measure latency`，并且明确保留 L4/L5 未完成；没有把低阈值即时反馈测量写成美学或发现性通过。
- L3 裁决法条仍为 `B2`；证据文件为 `EDGE-037-archive-send-auto-unarchive-l3-20260830.md`，目标 session 与 manifest 身份一致。
- 告警水位绑定本次最新 journal 行；后续新裁决会按 `alarms.py check` 重新计算，不继承本次 ack。
