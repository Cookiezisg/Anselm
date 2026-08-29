# EDGE-353 账本/警报复审

- `EDGE-353` 的五格按序写入：L1 有 workflow/store/flowrun/HTTP focused 与两个 testend 契约场景；L2-L5 明确 `na`，无真实 App + 五通道 session。
- `gen_coverage.py --check` 为 `848 rows / 848 carried judgments / 0 tombstones`。
- `alarms.py check` 打开 `gap-too-fast` 与 `discovery-collapse`，原因是最近窗口包含 Batch 82 的集中写账；不是本格证据缺失，也没有修改阈值或绕过序列策略。
- 复审后 ack 两项，下一阶段转向真实 App/五通道 `~` 格扫描；本次 ack 不继承到下一窗口。
