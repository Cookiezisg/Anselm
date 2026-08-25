# EDGE-246 · DNS rebinding 防护

## L1 focused evidence

- `backend/internal/transport/httpapi/middleware/host_test.go:TestRequireLoopbackHost` 锁住 loopback allowlist。
- `testend/scenarios/contract_platform_test.go:TestContractPlatform_LoopbackDoors` 真实 HTTP 以 `evil.example.com` Host 访问，断言始终 `403 FORBIDDEN_BAD_HOST`，正确 Host 恢复；通过。

## 判定

L1=`E1`：Host 门独立于 bearer/workspace 门常开，DNS rebinding 不进入业务路由。L2-L5 本轮无真实 App 五通道 session，记 `na`。
