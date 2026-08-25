# EDGE-162 ledger alarm re-audit

- 触发：本格按协议连续写入五格，统计窗口可能打开 `gap-too-fast`；本格无 fail verdict 时
  也可能打开 `discovery-collapse`。
- 复审对象：`testend/rig/formal-evidence/EDGE-162-subagent-depth-guard-20260825.md`。
- 复审结论：focused filter/recursion 两条断言与真实 HTTP 子树工具列表断言均通过；L1 pass 与
  证据匹配，L2-L5 的 na 是因为没有独立 Computer Use/视觉/可发现性 session，不是漏测或升格。
- 处置：若本格触发统计警报，仅按此记录串行 ack；不改阈值、算法、法典或锚点。
