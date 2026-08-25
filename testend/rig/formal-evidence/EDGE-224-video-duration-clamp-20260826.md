# EDGE-224 不可能的生成组合钳制

- 日期：2026-08-26
- 判定：L1 `pass`；L2-L5 `na`
- 法条：`measure:edge224-video-duration-clamp`

## 目标

清册原始例子写的是“向 Veo 要 15 秒”；当前 main 已按受管网关收敛，Veo 直连不是可用
生成路径。保留并验证同一个产品不变量：请求超过当前路由上限时，必须在花钱/提交前
钳到该路由能做的时长，且 receipt 报实际提交的时长，不回显用户原始请求。

## 可复核命令与结果

```text
cd backend
mise exec -- go test ./internal/app/tool/generate \
  -run 'TestVideo_(ImpossibleLengthIsClampedOnWireAndReceipt|ImpossibleLengthIsClampedNotSpent|ContextTimeoutSaysTheUpstreamMayStillComplete|ManagedTierRoutesVideo)$' \
  -count=1 -race -v
```

结果：4 个测试均 `PASS`。

`TestVideo_ImpossibleLengthIsClampedOnWireAndReceipt` 使用本地 TLS 网关完整走
`GenerateVideo.Execute` 的 submit → poll → fetch → receipt 路径：输入 `seconds=30`，
网关收到 `seconds=15`，最终 receipt 也报告 `seconds=15`。因此同时证明了提交前钳制和
用户可见回执不撒谎；没有真实上游费用。

## 边界说明

当前受管路由的硬上限是 15 秒；代码对不可驱动的直连 provider 返回无上限并由诚实缺席
闸阻止生成，不把旧的 Veo 例子伪装成当前可用能力。相关清册文字保留为历史边界，
本证据按当前 main 的受管实现验证不变量。

## 未声称的等级

本格本轮没有启动真实 App、真实生成、Computer Use 录屏、独立 SSE witness、frontend
console 或 LLM wire session，因此 L2（五通道真相）、L3（顺滑）、L4（craft）、L5（可发现性）
均明确为 `na`。
