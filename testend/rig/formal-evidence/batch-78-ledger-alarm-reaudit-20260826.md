# Batch 78 · ledger/alarm re-audit

## Scope

- 本批登记 `EDGE-301..310` 共 50 格：L1 分别由通知顶带、OS 路由、sidestage、stage director、transcript jump 的聚焦测试证据支持；L2-L5 因未启动真实 App 与五通道会话明确记 `na`。
- 账本核对为 `4036` 条裁决（2300 baseline + 1736 live），`COVERAGE=848/807/0`，锚点 `10/10`。

## 警报复审

- `gap-too-fast`：本批由同一台架脚本连续登记，0 秒间隔是登记方式，不是跳过证据；十个 L1 各自有文件和聚焦测试指针。
- `discovery-collapse`：本批聚焦测试没有 fail，因此不把“无 fail”解释为真实产品变干净；真实 App 级别仍保持 `na`，不降低后续门槛。
- 复审不修改阈值、算法、法典、锚点或覆盖范围；下一批仍重新运行统计检查。

## 结论

两项警报由本独立复审销账；任何后续新证据仍会重新触发同一机制。
