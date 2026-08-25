# EDGE-244 · bearer token 缺失

## L1 focused evidence

- `backend/internal/transport/httpapi/middleware/bearer_test.go` 覆盖缺失/错误 token、health 非豁免、OPTIONS/webhook/playback 豁免边界；通过。
- `testend/scenarios/contract_platform_test.go:TestContractPlatform_LoopbackDoors` 真实 HTTP 断言缺失/错误 token 返回 `401 UNAUTH_BAD_TOKEN`，正确 token 恢复，且不清 workspace；通过。

## 判定

L1=`E1`：认证失败返回可分类的人话错误码，前端可据此走“重启后端”而不是抹 workspace。L2-L5 本轮未建立真实 App 五通道 session，记 `na`。
