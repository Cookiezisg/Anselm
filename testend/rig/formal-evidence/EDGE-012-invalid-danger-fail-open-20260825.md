# EDGE-012 · 非枚举 danger 的 fail-open 与静态 floor

## Verification

标准字段剥离器对缺失或非枚举 `danger`（例如 `none`、`nuclear`）统一回落 `safe`，不会因为未知值
意外打开人闸；这与驻地越界路径的 fail-closed 事实闸是两件事。工具若声明不可绕过的静态危险 floor，
`EffectiveDanger` 仍会把自报 safe/非法值抬回真实 floor，避免把不可逆操作放行。

Focused verification passed:

```text
go test ./internal/app/tool ./internal/app/loop \
  -run 'TestStrip_InvalidDangerFallsBackToSafe|TestDispatchWithGate_StaticDangerFloorCannotBeSelfReportedSafe|TestInject_AddsThreeFieldsAndRequiresSummaryDanger|TestIsValidDanger' -count=1  PASS
go test -race ./internal/app/loop ./internal/app/tool \
  -run 'TestStrip_InvalidDangerFallsBackToSafe|TestDispatchWithGate_StaticDangerFloorCannotBeSelfReportedSafe' -count=1  PASS
```

## Five-level applicability

- L1 `pass`: 非枚举/缺失值回落 safe，静态危险 floor 仍强制 gate；测量法
  `measure:edge012-danger-fail-open`。
- L2 `na`: 本条是标准字段与 danger floor 的确定性 loop/tool 边界，本轮未为其单独启动真实 managed
  gateway 五通道 session。
- L3 `na`: 本轮没有真实 App 录屏或动作到首反馈帧时延数据；focused gate test 不冒充逐帧证据。
- L4 `na`: 本条验证的是内部风险分类和 gate 决策，不含独立视觉几何/动效表面；人闸视觉由对应
  interaction 旅程覆盖。
- L5 `na`: `danger` 是模型工具协议字段，不是用户可导航入口；非法值无需用户自行发现。
