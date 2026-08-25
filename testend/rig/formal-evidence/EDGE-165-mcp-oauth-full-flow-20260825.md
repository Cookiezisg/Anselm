# EDGE-165 MCP OAuth 全流程

- 结论：`pass`（L1 OAuth protocol/service contract）；L2-L5 按当前台架边界记 `na`。
- 预期：远程 MCP 返回 401 后，Anselm 能完成 RFC 9728/8414 discovery、DCR、PKCE + state、loopback
  callback、authorization-code exchange，并把 access/refresh grant 安全交给后续 client；无 DCR
  且无 BYO client 时必须明确拒绝。

## application OAuth flow

```text
cd backend && mise exec -- go test ./internal/app/mcp \
  -run '^(TestAuthorizeOAuth_|TestTokenSource_)' -count=1 -race -v
=== RUN   TestAuthorizeOAuth_FullFlow
--- PASS: TestAuthorizeOAuth_FullFlow (0.00s)
=== RUN   TestAuthorizeOAuth_BYOClient
--- PASS: TestAuthorizeOAuth_BYOClient (0.00s)
=== RUN   TestAuthorizeOAuth_NoDCRNoClient
--- PASS: TestAuthorizeOAuth_NoDCRNoClient (0.00s)
=== RUN   TestTokenSource_RefreshesAndPersists
--- PASS: TestTokenSource_RefreshesAndPersists (0.00s)
=== RUN   TestTokenSource_ReauthWhenNoRefresh
--- PASS: TestTokenSource_ReauthWhenNoRefresh (0.00s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/mcp 2.000s
```

fake authorization server 真实处理 401/metadata、DCR registration、browser callback code、PKCE
S256/resource、token exchange 和 refresh；BYO client 跳过 DCR；没有 registration endpoint 且没有
用户 client 时返回 `ErrOAuthNotSupported`，不静默连接。

## OAuth transport primitives

```text
cd backend && mise exec -- go test ./internal/infra/mcp/oauth -count=1 -race -v
--- PASS: TestDiscover_HappyPath
--- PASS: TestDiscover_PathAwareWellKnown
--- PASS: TestDiscover_OpenIDConfigurationFallback
--- PASS: TestDiscover_CrossHostPRMResourceIgnored
--- PASS: TestRegister_HappyPath_201
--- PASS: TestNewPKCE
--- PASS: TestAuthorizeURL
--- PASS: TestExchange_HappyPath
--- PASS: TestRefresh_RotatesRefreshTokenWhenPresent
--- PASS: TestPostToken_ErrorTruncatesBody
PASS
ok  github.com/sunweilin/anselm/backend/internal/infra/mcp/oauth 1.671s
```

同时覆盖 path-aware well-known、跨 host PRM 防护、缺 endpoint、200/201 DCR、URL 编码、无/有
client secret、access/refresh token rotation、expiry skew 和 token 错误体截断。

## 判定边界

```text
L2 na: 本格使用受控 OAuth authorization server，不是独立真实 App/第三方账号 Computer Use session
L3 na: 没有本格独立的浏览器逐帧、callback 等待时序或前端 console 证据
L4 na: OAuth 协议本身没有本格独立视觉成品与 craft 比对
L5 na: 本格没有独立用户从 MCP marketplace 发现并完成授权的 discoverability session
```
