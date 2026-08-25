# EDGE-019 · 危险工具人闸阻塞

## Verification

`dispatchWithGate` 在执行前先验证输入，再计算有效 danger；dangerous 调用在 broker interaction
未明确 approve/approve_always 前阻塞，工具没有副作用。interaction 由 surface 暴露，deny 或非法 action
不执行；静态 `DangerFloorer` 可将模型自报 safe 的真实不可逆/花费操作抬回 dangerous，不能绕过人闸。

Focused verification passed:

```text
go test ./internal/app/loop -run 'TestDispatchWithGate_(BlocksSideEffectUntilApproval|ApprovalUsesResolvedToolAction|StaticDangerFloorCannotBeSelfReportedSafe)' -count=1  PASS
go test -race ./internal/app/loop -run 'TestDispatchWithGate_(BlocksSideEffectUntilApproval|ApprovalUsesResolvedToolAction|StaticDangerFloorCannotBeSelfReportedSafe)' -count=1  PASS
```

新增时序回归先等待 interaction surface，再确认工具未完成且 `ran=false`；只有送出 approve 后才收到
`deployed` 和 `executed=true`。既有回归继续覆盖 resolved tool action、拒绝不执行和静态危险 floor。

## Five-level applicability

- L1 `pass`: dangerous call 在 side effect 前阻塞并只接受显式批准；测量法
  `measure:edge019-danger-gate-blocking`。
- L2 `na`: 本轮未为内部 gate 单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused gate test 无真实 App interaction frame、等待时延或终端数据。
- L4 `na`: 本条验证 gate 时序与风险事实，不含独立视觉几何/动效 surface。
- L5 `na`: 本条是工具执行协议边界，不是用户可导航入口；交互 discoverability 由对应 chat 旅程覆盖。
