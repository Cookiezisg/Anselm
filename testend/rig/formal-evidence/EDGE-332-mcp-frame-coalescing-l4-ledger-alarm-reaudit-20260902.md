# EDGE-332 L4 账本警报独立复审

- alarm: `discovery-collapse`
- formal ledger: `/private/tmp/anselm-rig-formal-20260831-11/judgments.jsonl`
- product session: `/private/tmp/anselm-rig-formal-20260902-01/sessions/20260902-000524`
- judgment under review: `EDGE|MCP 面板帧不可信|L4|pass|C4`

## Independent checks

- 本次 L4 使用修复后的第二次真实 App 录像，不复用旧的 L2 证据；失败卡主文案已从裸异常改为 danger callout，技术详情默认折叠。
- 代表帧与 `measure diff` 均显示状态变更局限在中心面板；卡片、按钮、callout 和 disclosure 没有重叠、截断、白闪或残留容器。正文对比抽样 `6.61:1`，满足 AA。
- 五通道 session 完整：`rig-check`/`rig-down` 通过，backend `282` 行无应用红线，Flutter console 无布局/运行时红线，三路 SSE 真实收发，managed LLM challenge/install/models 均 `200`。
- 警报只反映统计窗口的 fail-share，不是对本格 craft 证据的反证；没有修改 C4、阈值、法典或顺序门。

## Resolution

L4 证据可由 session、代表帧、测量输出和源代码测试独立复核，允许按原规则 ack。统计报警保持原机制，后续新 fail 仍会触发复核。
