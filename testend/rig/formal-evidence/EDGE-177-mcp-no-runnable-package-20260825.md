# EDGE-177 无可跑 package

- 结论：`pass`（L1 service/domain no-runnable contract）；L2-L5 为产品不可达状态的明确 `na`，不是缺少真实 App 证据的 waiver。
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
必须可规划，故不能把被 overlay 成可运行的条目伪装成该状态。这个状态不会出现在正式 marketplace
或真实 App 的可操作产品空间中：用户只能看到 curated catalog 的可规划条目，安装入口不会提供一个
无可跑 package 的目标。因此不存在可供 Computer Use 操作的真实 App 错误状态，也不存在该状态的
顺滑、视觉 craft 或新用户 discoverability 评价对象；通用 service 路径由构造 fixture 覆盖。

## 判定边界

```text
L2 na: curated catalog 保证所有正式 marketplace 条目可规划；真实 App 不可进入 no-runnable package 状态
L3 na: 不存在可观察的真实 App no-runnable 状态，故没有该状态的用户等待/反馈时序对象
L4 na: 不存在可观察的真实 App no-runnable 表单/错误成品，故没有该状态的视觉 craft 对象
L5 na: 用户无法从正式 marketplace 发现一个被产品暴露的 no-runnable 条目，故没有该状态的 discoverability 对象
```
