# EDGE-142 handler traceback 不被剥

- 结论：`pass`（L1 handler 错误线缆与耐久调用详情）；L2-L5 按当前台架边界记 `na`。
- 预期：method 内的 Python 异常不能被 Go wrapper 压成不透明的 `call failed`；即时 HTTP
  错误面、调用列表和调用详情都应保留可供用户/agent 自纠的异常文本与 traceback。

## focused 错误面回归

```text
cd backend && mise exec -- go test ./internal/infra/handler -run '^TestCallFailedErr_SurfacesTraceback$' -count=1 -race -v
=== RUN   TestCallFailedErr_SurfacesTraceback
--- PASS: TestCallFailedErr_SurfacesTraceback (0.00s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/infra/handler 1.476s
```

该回归断言 `errors.Is` 仍保留 `HANDLER_CLIENT_CALL_FAILED`/`INIT_FAILED` 分类，
`errorspkg.Surface` 同时包含 Python cause 和 traceback，空错误也退化为可读基础消息。

## 真实 HTTP 黑盒

```text
cd testend && mise exec -- go test ./scenarios -run '^TestHandler_ErrorSurfacesTraceback$' -count=1 -v
--- PASS: TestHandler_ErrorSurfacesTraceback (4.16s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 4.734s
```

场景用 HTTP 创建 Handler，方法体真实执行 `raise ValueError('bad amount')`。调用响应为
`502` 且错误码为 `HANDLER_CLIENT_CALL_FAILED`，响应正文同时包含 `ValueError: bad amount`
和 `Traceback`；随后 `GET /handlers/{id}/calls` 的 failed 行以及
`GET /handler-calls/{id}` 的详情同样保留两者。收台时 sandbox 无残留。

## 判定边界

本格证明的是错误信息真实穿过 handler → HTTP → durable audit 的数据链；当前没有为本格
单独捕获完整真实 App 的 Computer Use 五通道 session，也没有独立视觉、时序或 discoverability
证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为 focused 错误面 + 真实 HTTP/审计证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
