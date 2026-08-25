# EDGE-225 能力工具诚实缺席

- 日期：2026-08-26
- 判定：L1 `pass`；L2-L5 `na`
- 法条：`measure:edge225-image-capability-honest-absence`

## 目标

没有任何能出图的 key 时，`generate_image` 必须从逐请求能力工具集中缺席；若一个已经
开始的旧回合仍直接调用它，必须返回结构化 `IMAGE_NO_ROUTE`，不能偷偷换路由或让模型
看见一个必然失败的工具。

## 可复核命令与结果

```text
cd backend
mise exec -- go test ./internal/app/tool/generate \
  -run 'Test(ImageCapability_HonestAbsenceAndDirectRace|Route_FiveBatteries)$' \
  -count=1 -race -v
```

结果：`TestRoute_FiveBatteries` 的五种路由电池和新增的
`TestImageCapability_HonestAbsenceAndDirectRace` 均 `PASS`。

新增测试同时验证：空 key/probe 集合下 `generate_image` 的 availability 为 false，
以及直接调用返回 `ErrNoImageRoute`，其错误码为 `IMAGE_NO_ROUTE`。

## 未声称的等级

本格本轮没有启动真实 App、真实工具回合、Computer Use 录屏、独立 SSE witness、frontend
console 或 LLM wire session，因此 L2（五通道真相）、L3（顺滑）、L4（craft）、L5（可发现性）
均明确为 `na`。
