# EDGE-245 · workspace 头缺失

## L1 focused evidence

- `backend/internal/transport/httpapi/middleware/auth_test.go` 覆盖 header/query workspace 解析、非法值丢弃、缺失拒绝；通过。
- `testend/scenarios/contract_platform_test.go:TestContractPlatform_SystemEnvelopes` 真实 HTTP 断言隔离 system route 无 workspace 返回 `401 UNAUTH_NO_WORKSPACE`，带正确 workspace 后返回数据；通过。

## 判定

L1=`F1`：workspace 身份是隔离查询的真门，缺失不会被默认为当前 workspace。L2-L5 本轮无前端清 workspace 的真实 App session，记 `na`。
