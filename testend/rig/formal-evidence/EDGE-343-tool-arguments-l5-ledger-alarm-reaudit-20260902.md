# EDGE-343 · 工具参数双线缆形 · L5 账本与警报独立复审

## 复审范围

- 复审本格 `L5=na` 的适用性记录：provider 的 object/string tool-arguments 线缆形状是
  内部兼容性行为，没有独立用户入口、用户动作或可发现能力；这不是缺少验证后的临时
  占位。Chat 工具执行、状态反馈和错误引导的用户可发现性由其它产品旅程覆盖。
- L3/L4 已由真实 App 五通道证据覆盖；L5 不重复把同一 wire 兼容性证据声明成 discoverability
  通过。formal ledger root=`/private/tmp/anselm-rig-formal-20260801-3`。
- `anchors.py check` 的最近结果为 `10/10`。未修改警报阈值、算法、CODEX、锚点答案、
  五级标准或顺序门。

## 警报处置

写入该适用性结论后，`alarms.py check` 按原 `5%` 发现率下限打开
`discovery-collapse`。该统计信号只要求检查裁决质量，不能把 `na` 转成 pass，也不能
通过改阈值消除。复审确认本次 L5 有明确的产品边界理由，且本格 L3/L4 的真实 App
证据已独立存在；随后仅用 `alarms.py ack discovery-collapse` 销账并绑定当前 journal
水位。未来新证据仍须重新经过同一警报门。
