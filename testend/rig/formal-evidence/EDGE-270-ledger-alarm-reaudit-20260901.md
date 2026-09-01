# EDGE-270 · 账本警报独立复审

## 复审范围

- 触发裁决：`EDGE|空 workDir 批量动作` L2=`E1`。
- 真实证据：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-091029/evidence/EDGE-270-empty-workdir-real-app.md`。
- 锚点：同一 RIG_HOME 于本次写账前重新 quiz/check，`10/10` 通过；未改阈值、法典、顺序门或五级标准。

## 两条告警

- `gap-too-fast`：近 50 条 live judgment 的间隔中位数为 `18s`，低于 `25s` 阈值。复审了本次证据的 session manifest、backend/sse/frontend/llm journals、录屏终态和 rig-down 回执；本次 L2 是短时、无破坏性拒绝请求，快不是跳过现场观察的证据，且没有用该速度调整阈值。
- `discovery-collapse`：近 50 条 live judgment 的 fail 占比为 `0.0%`，低于 `5%` 阈值。复审了当前完整 `COVERAGE` 行和本次真实 App 证据；本项是已知的 fail-closed 正向边界，未把其它未测试路径当成通过，也未删除 fail 证据或放宽判定。

## 结论

两条告警均已按原规则独立复审，保留统计曲线与原始证据，随后按 `gap-too-fast`、`discovery-collapse` 顺序串行 ack。下一格只有在 `alarms.py check` 清洁后才可写入。

## L3 复审

L3 写入的是明确适用性 `na`，理由是该输入保护没有独立的前端交互、反馈时延或动效；没有把缺少现场验证写成适用性结论。L3 写账后同样出现两条统计告警，复审结论不变：不改 `25s`/`5%` 阈值，不抹除任何 fail 记录，按 `gap-too-fast`、`discovery-collapse` 顺序再次串行 ack。

## L4 复审

L4 写入的是明确适用性 `na`，因为空值输入保护本身不产生视觉对象；上层驻地批量操作的确认框和落地状态才是视觉 craft 的承载面。两条告警再次出现，已复审本项证据和适用性边界，仍按原阈值串行 ack，不把 API 保护伪装成视觉通过。

## L5 复审

L5 写入的是明确适用性 `na`，因为隐藏 API 的输入保护没有独立的用户发现入口；其可发现性由驻地批量操作菜单和确认框承载。两条告警再次出现，复审确认没有把 API 边界误当成用户入口，也没有改变阈值或清除原始判断。
