# EDGE-300 账本警报复审（2026-09-01）

本复审只销本次写入触发的两条警报，不改变算法、阈值、锚点、CODEX、五级标准或验收顺序。

## gap-too-fast

- 警报原因是近 50 次裁决间隔中位数 `21s < 25s`，不是证据缺失。
- 本格 L2 写入前已完成正式 session 收台，`rig-check` 五通道通过，`rig-down` 正常 finalized；不是连续盲写。
- 本格证据包含真实 App AX 逐步操作、两个公平周期、关键帧、backend journal、三条 SSE 记录和实现对照；证据不是单测或 demo。
- 该警报反映批量验收节奏，保留阈值并以本复审确认此次证据确实被读过。

## discovery-collapse

- 警报原因是近 50 次裁决 fail 占比 `0.0% < 5%`，要求核对是否错误地把缺陷写成通过。
- 本格没有把首轮相同 workflow 的去重干扰写绿；该场景明确废弃，并用 12 个唯一 workflow 重跑。
- 本格保留并解释了刻意漏掉 approval input 映射的负向 probe，不把它混入成功路径；approval current 不自动消失也按人在环产品语义判定为正确行为。
- 公平性结论仅在真实 App 观察到 `unique-2 -> unique-3 -> unique-4 -> normal-0` 和 `unique-5 -> unique-6 -> unique-7 -> normal-1` 后成立，且与 `priorityBurstLimit=3` 的实现和前端单测一致。
- 因此本格不是无条件全绿；它有明确的负向构造、去重干扰排除和五通道交叉证据。警报可以 ack，阈值继续保留。

复审结论：两条警报均按原机制销账，不能作为后续批次的永久豁免。
