# EDGE-352 账本与警报复审

- EDGE-352 的 live session 在 formal rig 收台后才进入裁决；录屏、backend、SSE、frontend、LLM 五通道证据均已封存。
- `judge.py` 只写入 L2，L3-L5 以 `na` 保持诚实；没有用 fixture 夹具校正过程或静态回归替代真实 App 证据。
- `gen_coverage.py --check`=`clean (848 rows, 848 carried judgments, 0 tombstones)`。
- `anchors.py check`=`10/10`；本次裁决后的 `alarms.py check` 产生 `gap-too-fast`、`pass-burst`、`discovery-collapse` 三项统计信号，按既有阈值复审并 ack，不修改算法、阈值、法典或锚点。
- 三项信号都来自同一批次的脚本裁决时刻，而不是产品 session 的执行时长；EDGE-352 的 L2 仍有完整录屏和收台后的五通道证据，L3-L5 明确为 `na`，没有用快写账掩盖未判层级。
- 本复审只记录本格的证据归属和曲线影响，不把警报销账本身当作产品通过。
