# EDGE-177 无可跑 package

- 结论：`pass`（L1 service/domain no-runnable contract）；L2-L5 按当前独立台架边界记 `na`。
- 预期：registry 条目只有不支持的 runtime package、且没有 remote 时，安装计划必须失败为
  `MCP_NO_RUNNABLE_PACKAGE`，不能继续下载、起进程或落半个 server。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/mcp \
  -run '^TestInstall_NoRunnablePackage$' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/mcp 2.040s

cd backend && mise exec -- go test ./internal/infra/mcp \
  -run '^TestCuratedCatalog_AllEntriesPlannable$' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/infra/mcp 1.586s
```

自定义 registry fixture 使用 `unsupported-runtime`，focused app 测试断言返回
`ErrNoRunnablePackage` 且 repository 保持零 server 行；curated catalog 回归同时证明正式 marketplace
白名单不会把不可规划条目暴露给用户。

本格没有真实 marketplace 的 no-runnable HTTP 负路径：curated catalog 的产品契约是所有白名单条目
必须可规划，故不能把被 overlay 成可运行的条目伪装成该状态。该边界已如实保留，通用 service 路径由
构造 fixture 覆盖。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成五通道 App 录制
L3 na: 没有本格独立 Computer Use no-runnable 错误逐帧时序测量
L4 na: 没有本格独立无可跑 package 表单错误的视觉成品与 craft 比对
L5 na: 没有本格独立的新用户发现并理解该安装状态的 discoverability session
```
