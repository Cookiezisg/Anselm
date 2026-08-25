# Batch 71 · ledger alarm independent re-audit

本批 `EDGE-231..240` 每个格子只把可重复的 focused regression 写成 L1；没有把本地单测、源代码检查或历史说明写成新的 App 五通道证据，L2-L5 均明确 `na`。每个 L1 证据文件列出可定位的测试名称与通过结果，法条引用来自当前 CODEX；覆盖清册只由 `judge.py` 写入，未手工改五格。

若统计警报因本批裁决时间集中而打开，处理方式是：逐项重新阅读上述十个证据文件，复核测试命令、代码路径、法条和 `na` 边界；不修改阈值、算法、锚点或判定结果，完成独立复审后再 ack。后续继续前必须 `alarms.py check` 为 clean。
