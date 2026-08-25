# EDGE-149 sandbox bootstrap 失败 degraded

- 结论：`pass`（L1 sandbox bootstrap/degraded/retry 语义）；L2-L5 按当前台架边界记 `na`。
- 预期：sandbox 数据根不可写或不可建时，bootstrap 不能假装 ready，也不能把整个 app 启动链
  弄死；必须进入 degraded、保留可解释错误，并允许用户修复磁盘后通过 retry 恢复。

## focused service

```text
cd backend && mise exec -- go test ./internal/app/sandbox -run '^TestBootstrap_DegradedThenRetry$' -count=1 -race -v
=== RUN   TestBootstrap_DegradedThenRetry
--- PASS: TestBootstrap_DegradedThenRetry (0.02s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/sandbox 1.673s
```

测试先删除真实 sandbox root 并在同一路径写入普通文件，使 `os.MkdirAll` 确实失败；断言
`Bootstrap` 返回错误、`IsReady=false`、`BootstrapError` 保留错误。随后移除文件障碍，调用
`RetryBootstrap`，断言 ready 恢复、错误清空且目录重新存在。

## 真实 HTTP 黑盒

```text
cd testend && mise exec -- go test ./scenarios -run '^TestContractPlatform_SandboxGovernanceEdges$' -count=1 -v
--- PASS: TestContractPlatform_SandboxGovernanceEdges (5.21s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 5.494s
```

真实平台场景确认正常装配下 `POST /api/v1/sandbox:retry-bootstrap` 返回 200，且 data 始终为
带 `ok` 键的对象；同时覆盖 sandbox 列表、env 资源和恢复后的对话 scratch 入口。不可写根的
故障注入保留在 focused service 层，以免让 HTTP harness 的启动器先替测试对象修复故障。

## 判定边界

本格没有单独捕获完整真实 App 的 Computer Use 五通道 session，也没有独立视觉、等待时序或
discoverability 证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为 focused service + 真实 HTTP retry 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
