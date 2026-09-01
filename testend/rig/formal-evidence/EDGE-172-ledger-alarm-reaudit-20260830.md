# EDGE-172 ledger alarm re-audit

- 触发：本次只新增一条 L2 适用性裁决，`gap-too-fast` 与 `discovery-collapse` 按账本规则重新打开；这是统计保护，不是产品缺陷结论。
- 复审对象：`testend/rig/formal-evidence/EDGE-172-mcp-media-no-uploader-20260825.md` 与其 L2 `na` 账本记录。
- 复审结果：L1 的 focused service 回归证明 `uploader=nil` 时 MCP 调用成功、占位叙事保留且无 attachment receipt；L2 新说明确认目标是内部未注入端口的装配，正式桌面 composition root 始终注入 attachment service，产品没有用户动作或支持的运行时配置能产生该状态。因此该 L2 是明确不适用，不是缺少真实 App 证据。
- 复审范围：Edge172 的 L3-L5 原有明确不适用裁决未被改写；没有把 service 装配证据扩张成真实 App、顺滑、视觉 craft 或 discoverability 证据。未修改告警阈值、算法、法典、锚点或顺序门。
- 复审后门禁：`anchors.py check`=`10/10`；`gen_coverage.py --check`=`848/848/0`；本次新增后 live judgments=`2120`，baseline 排除=`2300`。两条告警仅按本复审记录逐条 ack。
