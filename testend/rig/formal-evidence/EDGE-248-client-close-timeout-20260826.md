# EDGE-248 · 客户端断连与请求超时

## L1 focused evidence

- `backend/internal/transport/httpapi/response/errmap_test.go:TestFromDomainErrorContextCanceled` 通过，标准 context canceled/deadline 分别映射 `CLIENT_CLOSED` 与 `REQUEST_TIMEOUT`。
- `backend/internal/transport/httpapi/response/errmap_test.go` 的 wrapped/unknown error 回归确认 typed error 不被吞、未知错误不泄露内部异常；通过。

## 判定

L1=`E1`：断连与超时是可解释、可分流的终态，不把底层异常串直接显示给用户。L2-L5 本轮未做真实断连 App session，记 `na`。
