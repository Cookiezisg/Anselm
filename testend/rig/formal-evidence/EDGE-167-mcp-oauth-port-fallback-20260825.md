# EDGE-167 自带客户端固定端口被占

- 结论：`pass`（L1 loopback callback port fallback）；L2-L5 按当前台架边界记 `na`。
- 预期：BYO OAuth client 首选注册用的 `127.0.0.1:47100/callback`；该端口被占时不能让安装
  失败，必须退到随机 loopback 端口，并仍能收到 code/state callback。

## occupied-port regression

```text
gofmt -w backend/internal/app/mcp/oauth_flow_test.go
cd backend && mise exec -- go test ./internal/app/mcp \
  -run '^TestStartCallbackServer_FallsBackWhenPreferredPortIsBusy$' -count=1 -race -v
=== RUN   TestStartCallbackServer_FallsBackWhenPreferredPortIsBusy
--- PASS: TestStartCallbackServer_FallsBackWhenPreferredPortIsBusy (0.00s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/mcp 1.898s
```

测试先真实监听 `127.0.0.1:47100`，再启动 callback server；server 返回非 47100 的 ephemeral
loopback redirect，并通过该 URI 发送 code/state，确认首个 callback hit 正确交付。固定端口只是
BYO client 注册便利，不应成为 OAuth 可用性的单点故障。

## 判定边界

```text
L2 na: 当前为真实 loopback listener/HTTP callback focused 证据，没有独立 App marketplace session
L3 na: 没有本格独立浏览器逐帧、端口占用到授权反馈的时序测量
L4 na: 没有本格独立 OAuth 设置/错误表面的视觉成品比对
L5 na: 没有本格独立用户发现 BYO OAuth 配置入口的 session
```
