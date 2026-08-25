# EDGE-168 每租户模板 URL

- 结论：`pass`（L1 resolved URL enters the real OAuth install path）；L2-L5 按当前台架边界记 `na`。
- 预期：Glean 类 `Remote.URLEnv` 条目把租户 URL 作为必填输入；安装前解析 `{ENV}`，随后 OAuth discovery、DCR、PKCE、loopback callback 和 token exchange 都使用解析后的资源 URL。

## focused install-path regression

```text
cd backend && mise exec -- go test ./internal/app/mcp \
  -run '^TestInstallFromRegistry_ExpandsTenantURLBeforeOAuth$' \
  -count=1 -race -v
=== RUN   TestInstallFromRegistry_ExpandsTenantURLBeforeOAuth
--- PASS: TestInstallFromRegistry_ExpandsTenantURLBeforeOAuth (0.00s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/mcp 1.927s
```

该测试使用完整受控 OAuth server，但通过真实 `InstallFromRegistry` 进入安装路径；模板 `{MCP_URL}`
被替换成假 server 的真实 `/mcp` 资源地址。假 server 只接受展开后的资源地址，因此若把占位符
传入 discovery，首个 401/PRM 发现就会失败。测试随后从 fake repository 读取已落盘 server，核对
`URL` 和 OAuth `Resource` 都是展开后的地址，access token 为成功交换所得的 `AT-1`。

## curated catalog contract

```text
cd backend && mise exec -- go test ./internal/infra/mcp \
  -run '^TestCuratedCatalog_GleanOAuthWithURLEnv$' \
  -count=1 -race -v
=== RUN   TestCuratedCatalog_GleanOAuthWithURLEnv
--- PASS: TestCuratedCatalog_GleanOAuthWithURLEnv (0.02s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/infra/mcp 1.265s
```

目录测试确认 `com.glean/mcp` 是 OAuth plan，恰有一个 URL env，且 plan URL 引用该 env；安装
测试确认该字段不是静态目录装饰，而是实际进入 OAuth resource 与最终 server 配置。

## 判定边界

```text
L2 na: 本格是 focused service/infra 与受控 OAuth server，没有独立真实 App 五通道 session
L3 na: 没有本格独立 Computer Use 浏览器授权逐帧记录或时序测量
L4 na: 没有本格独立的租户 URL 表单视觉成品与 craft 比对
L5 na: 没有本格独立的新用户 marketplace → 必填 URL → OAuth 入口 discoverability session
```
