# EDGE-113 sensor 电平触发风暴

- **结论**：pass（条件持续为真时每次 poll 都 fire，非 false→true 边沿触发）
- **验证目标**：sensor 条件在多个 poll 周期持续为真时，每一轮都必须产生 fired activity/firing；产品没有隐式 edge-trigger 或静默去重，workflow 的 concurrency policy 才是风暴治理位置。
- **Focused regression**：`cd backend && mise exec -- go test ./internal/infra/trigger/sensor -run '^TestSensor_SustainedConditionFiresEveryPoll$' -count=1 -race -v`
- **Product path**：`cd testend && mise exec -- go test ./scenarios -run '^TestTrigger_SensorPollsCEL$' -count=1 -v`
- **结果**：精确 regression 连续三轮 sustained-true probe 均报告 fired；真实 HTTP 场景完成 function → sensor poll → workflow run，并在 activation 中保留 probe return value。两条路径均通过。

Levels 2-5 are intentionally `na`: the product path proves backend/user-purpose execution but did not include an independent Computer Use frame, timing capture, visual/beauty review, or discoverability session for this edge.
