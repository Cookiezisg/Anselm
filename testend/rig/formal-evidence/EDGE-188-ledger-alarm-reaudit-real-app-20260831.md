# EDGE-188 ledger alarm re-audit · 2026-08-31

本次 `discovery-collapse` 是机制预期内的阻断，不被当作噪声跳过。近 50 条 live judgment
中有 2 条真实 `fail`：`EDGE|首用下载途中关停 L3` 与 `EDGE|cosineFloor 噪声闸 L2`；
fail share 为 `2/50=4.0%`，低于 5% 只说明当前尾窗的红场比例很低，不能证明产品已经没有缺陷。

独立复审本次新增的三项 `EDGE-188` 裁决：

- L2 绑定真实 App session `20260830-235206`，五通道、密文零命中、公开字段正控均有原始证据。
- L3 绑定新 session `20260831-000912`，有录屏测量和 A4 法条；明确只判定长操作有 `thinking`
  进行态，不把首个文字 token 冒充 A1 的 100ms 反馈。
- L4 绑定同一新 session 的稳定尾帧，独立检查结果层级、表格几何、换行、Composer 和残留 loading；
  没有把 L2 的后端正确性重复当作视觉 craft 证据。

复审还确认：

- 两个历史 fail 均仍保留在 journal 和 evidence 中，没有被 pass 覆盖或删除。
- 当前新增绿格均有对应 CODEX 法条、真实 evidence 文件和正确 session 归属；没有发现“无证据
  橡皮章”或通过率暴冲掩盖红场的情况。
- `anchor-check.json` 仍为 `10/10`，时间在四小时校准窗口内，anchor hash 与锚点集一致。
- 不修改发现率阈值、算法、CODEX、锚点、五级标准或顺序 gate；本 alarm 按原机制 ack，后续
  `alarms.py check` 将继续从新增 judgment 重新计算。
