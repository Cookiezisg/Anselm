# EDGE-144 handler 空 ops edit 抹内存态

- 结论：`pass`（L1 handler env/lifecycle/notification 线缆）；L2-L5 按当前台架边界记 `na`。
- 预期：对已有 Handler 执行空 ops edit 时，不铸新版本，只重建 active env 并重启 resident；成功
  才发 `handler.env_rebuilt`，失败环境停止旧 resident 且不发假成功通知。

## focused service 回归

```text
cd backend && mise exec -- go test ./internal/app/handler -run '^(TestEdit_EmptyOpsRebuildsEnvEmitsNotification|TestEdit_FailedEnvironmentStopsResidentWithoutSecondProvision)$' -count=1 -race -v
=== RUN   TestEdit_EmptyOpsRebuildsEnvEmitsNotification
--- PASS: TestEdit_EmptyOpsRebuildsEnvEmitsNotification (0.07s)
=== RUN   TestEdit_FailedEnvironmentStopsResidentWithoutSecondProvision/empty_ops
--- PASS: TestEdit_FailedEnvironmentStopsResidentWithoutSecondProvision/empty_ops (0.06s)
=== RUN   TestEdit_FailedEnvironmentStopsResidentWithoutSecondProvision/new_version
--- PASS: TestEdit_FailedEnvironmentStopsResidentWithoutSecondProvision/new_version (0.06s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/handler 2.183s
```

成功路径断言 resident spawn 从 1 增至 2 并发出 `handler.env_rebuilt`；失败路径只 provision
一次、停止旧 resident、保留 failed env 状态且不发通知。

## 真实 HTTP + notification + resident state

```text
cd testend && mise exec -- go test ./scenarios -run '^TestContractEntities_HandlerEmptyOpsRebuild$' -count=1 -v
--- PASS: TestContractEntities_HandlerEmptyOpsRebuild (6.55s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 7.044s
```

真实场景创建有内存计数器的 Handler，第一次 `:call` 得到 count=1；空 ops `:edit` 返回 200，
通知 SSE 收到 `handler.env_rebuilt`，GET 仍为同一个 v1 active version，下一次 `:call` 又从
count=1 开始，版本列表仍只有 v1。收台时 sandbox 无残留。

## 判定边界

本格覆盖 Handler 的真实 HTTP、通知耐久帧、版本真相和 resident 内存态；当前没有为本格单独
捕获完整真实 App 的 Computer Use 五通道 session，也没有独立视觉、时序或 discoverability
证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为 focused service + 真实 HTTP/notifications/resident 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
