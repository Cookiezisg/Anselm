# EDGE-166 OAuth refresh 失效

- 结论：`pass`（L1 revoked-refresh error contract）；L2-L5 按当前台架边界记 `na`。
- 预期：授权服务器吊销 refresh token 后，MCP 调用不能带着死 token 静默继续；refresh 失败必须
  映射为 `MCP_OAUTH_REAUTH_REQUIRED`，明确指向重新授权。

## revoked refresh focused regression

```text
gofmt -w backend/internal/app/mcp/oauth_flow_test.go
cd backend && mise exec -- go test ./internal/app/mcp \
  -run '^TestTokenSource_(RefreshesAndPersists|ReauthWhenNoRefresh|ReauthWhenRefreshRevoked)$' \
  -count=1 -race -v
=== RUN   TestTokenSource_RefreshesAndPersists
--- PASS: TestTokenSource_RefreshesAndPersists (0.00s)
=== RUN   TestTokenSource_ReauthWhenNoRefresh
--- PASS: TestTokenSource_ReauthWhenNoRefresh (0.00s)
=== RUN   TestTokenSource_ReauthWhenRefreshRevoked
--- PASS: TestTokenSource_ReauthWhenRefreshRevoked (0.00s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/mcp 1.906s
```

新增的 revoked server 返回 HTTP 401 + `invalid_grant`，并确认 token source 返回
`ErrOAuthReauthRequired`；不发送无认证 fallback、不改写旧 grant 成假成功。相邻回归同时确认正常
refresh 会轮换并持久化 token，以及没有 refresh token 时同样需要重新授权。

## contract boundary

`oauth_flow.go` 的运行时 token source 将 refresh 网络失败统一包成 `ErrOAuthReauthRequired`，
上层 MCP 调用因此能显示重新授权方向，而不是泄漏上游散文或继续调用。该格没有额外真实第三方
账号或独立 App Computer Use session，避免把受控 token endpoint 冒充真实 gateway 证据。

## 判定边界

```text
L2 na: 本格为受控 revoked token endpoint 与 service contract，没有独立 App/managed MCP session
L3 na: 没有本格独立的浏览器/设置页逐帧与错误反馈时序测量
L4 na: 没有本格独立的 OAuth 失败视觉成品与 craft 比对
L5 na: 没有本格独立的用户重新授权入口 discoverability session
```
