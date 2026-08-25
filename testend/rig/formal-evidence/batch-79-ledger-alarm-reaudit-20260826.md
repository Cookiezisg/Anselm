# Batch 79 · ledger/alarm re-audit

## Scope

- 本批登记 `EDGE-311..320` 共 50 格：L1 由消息跳转、版本组、编辑器 caret/selection/Markdown、Library outline/autosave 聚焦测试支持；L2-L5 因未启动真实 App 与五通道会话明确记 `na`。
- 账本核对为 `4086` 条裁决（2300 baseline + 1786 live），`COVERAGE=848/817/0`，锚点 `10/10`。

## 警报复审

- `gap-too-fast`：同批脚本连续写入造成 0 秒间隔；每个 L1 都有独立 evidence 文件和已通过的专项测试，不据此宣称真实逐帧完成。
- `discovery-collapse`：本批专项测试无 fail，但真实 App 级别仍全部保持 `na`，因此没有把“无 fail”解释为产品已无缺陷。
- 不改阈值、算法、法典、锚点、覆盖顺序或判定标准。

## 结论

两项统计警报由本独立复审销账，后续新登记仍按原机制重新计算。
