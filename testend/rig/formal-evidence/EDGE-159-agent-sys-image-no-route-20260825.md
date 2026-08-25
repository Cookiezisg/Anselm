# EDGE-159 sys: 能力工具无路由

- 结论：`pass`（L1 capability-mount honest absence）；L2-L5 按当前台架边界记 `na`。
- 预期：没有任何可用图像生成路由时，`sys:generate_image` 不能被 agent 挂载或进入工具面；
  创建必须明确拒绝，并告诉用户配置 capable key 或启用免费档，而不是等 invoke 最后一跳才失败。

## focused resolver and health regression

```text
cd backend && mise exec -- go test ./internal/app/tool/mount \
  -run '^TestSysMounts$' -count=1 -race -v
=== RUN   TestSysMounts
--- PASS: TestSysMounts (0.00s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/tool/mount 1.955s
```

该回归先验证可用 sys tool 能 Resolve/healthy，再撤掉路由，确认 Resolve 返回
`ErrMountInvalid`，CheckHealth 返回 unhealthy 并带 `no usable route`；未知 sys 名称也单独拒绝。

## real HTTP agent creation path

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestAgentR2_SysMountWithoutImageRoute$' -count=1 -v -timeout 600s
--- PASS: TestAgentR2_SysMountWithoutImageRoute (2.46s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 3.292s
```

真实 testend workspace 只配置 text-capable llmmock key，没有图像路由；通过产品 HTTP 创建带
`sys:generate_image` 的 agent，得到 `422 AGENT_MOUNT_INVALID`，响应保留 `no usable route`
和配置 capable key/free tier 的修复方向。

## 判定边界

本格没有独立完整 App Computer Use 五通道 session，也没有独立视觉、等待时序或 discoverability
证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为 resolver/HTTP agent 创建证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
