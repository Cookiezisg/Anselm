# EDGE-128 空 ops edit 重建 env

- 结论：`pass`（L1 function empty-ops 环境重建与失败边界）；L2-L5 按当前台架边界记 `na`。
- 预期：对 active version 执行空 ops edit 时只重建环境，不铸造新版本；成功重建发 `function.env_rebuilt`。若重建仍失败，active version 保持 failed，不发成功通知。

## 证据

focused regression：

```text
cd backend && mise exec -- go test ./internal/app/function -run '^TestEdit_FailedEmptyOpsDoesNotEmitRebuilt$' -count=1 -race -v
=== RUN   TestEdit_FailedEmptyOpsDoesNotEmitRebuilt
--- PASS: TestEdit_FailedEmptyOpsDoesNotEmitRebuilt (0.03s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/function 1.999s
```

该测试让第二次 provisioning 失败，再对失败环境执行空 ops；断言 active version 仍为 failed，且没有 `function.env_rebuilt` 假成功通知。

真实 function 生命周期：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestContractEntities_FunctionEnvLifecycle$' -count=1 -v
--- PASS: TestContractEntities_FunctionEnvLifecycle (6.77s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 7.440s
```

真实 HTTP 路径先创建可运行 function，再提交空 `ops`：返回仍为 `version=1`，收到 `function.env_rebuilt`，随后版本列表仍只有一行；同一生命周期还验证了失败重建不伪造通知和失败状态可见。

## 判定边界

L2-L5 暂记 `na`：当前证据覆盖应用状态、HTTP、通知与版本真相，但没有该等级独立 Computer Use 逐帧、测量、视觉和 discoverability 证据；不越级登记。
