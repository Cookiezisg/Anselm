# EDGE-247 · ServeMux 纯文本 404/405 改写

## L1 focused evidence

- `backend/internal/transport/httpapi/router/chain_test.go:TestChain_MuxErrorsEnveloped` 断言未匹配路径变成 `ROUTE_NOT_FOUND` envelope，错误方法保留 `Allow` 语义并映射 `METHOD_NOT_ALLOWED`；通过。
- `TestChain_MatchedHandler404NotClobbered` 锁住真实 handler 的业务 404 不被误改成路由 404；SSE flusher 也通过同一 chain 回归。

## 判定

L1=`E1`：用户看到的是可分类 envelope，不是 net/http 裸文本；业务错误与路由错误仍分开。L2-L5 本轮无真实 App 失误路径 session，记 `na`。
