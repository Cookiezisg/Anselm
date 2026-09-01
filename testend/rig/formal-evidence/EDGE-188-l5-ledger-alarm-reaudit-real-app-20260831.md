# EDGE-188 L5 ledger alarm re-audit · 2026-08-31

`discovery-collapse` 在 EDGE-188 L5 写账后重新打开，原因仍是近 50 条 live judgment 只有
2 条 fail（`4.0%`），而不是因为本格缺少证据。独立复审确认：

- L5 的 `G1` 只依据真实 session `20260831-000912` 的默认 Chat、`New chat`、Composer 和自然语言
  搜索完成路径；没有把工具内部名或测试脚本当作用户入口。
- L2/L3/L4/L5 的 evidence 文件彼此分开，分别覆盖数据真相、等待反馈、稳定视觉和入口发现性；
  没有用同一条后端事实重复填满五级。
- 尾窗中的两条 fail 仍保留在 journal 与证据目录中，低 fail share 没有被解释为产品已无缺陷。
- `anchor-check.json` 仍是 `10/10`，锚点 hash 未变且在四小时窗口内；没有改动阈值、算法、法典、
  五级标准或顺序 gate。

该 alarm 按原机制销账，后续新增 judgment 仍会重新计算三条漂移曲线。
