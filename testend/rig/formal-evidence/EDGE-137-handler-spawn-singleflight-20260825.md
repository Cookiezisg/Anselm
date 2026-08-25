# EDGE-137 handler spawn 单飞

- 结论：`pass`（L1 handler 冷启动 spawn single-flight）；L2-L5 按当前台架边界记 `na`。
- 预期：chat/HTTP 同一批并发调用同一个冷 handler 时，共享一次 env + process + `__init__` 的 in-flight spawn；所有调用进入同一个 resident，不重复付出启动成本。

## 证据

focused manager regression：

```text
cd backend && mise exec -- go test ./internal/app/handler -run '^TestInstanceManager_SingleFlightColdSpawn$' -count=1 -race -v
=== RUN   TestInstanceManager_SingleFlightColdSpawn
--- PASS: TestInstanceManager_SingleFlightColdSpawn (0.00s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/handler 1.913s
```

测试让第一次 spawn 人为阻塞，再并发发起 5 个 `Get`；阻塞期间断言 spawn 计数始终为 1，释放后 5 个调用全部取得同一个 resident 指针，最终 spawn 计数仍为 1。

真实 handler HTTP path：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestContractEntities_HandlerResidentSemantics$' -count=1 -v
--- PASS: TestContractEntities_HandlerResidentSemantics (7.18s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 7.485s
```

真实场景创建带 1 秒 `__init__` 延迟的 cold handler，并同时发出 5 个 HTTP `:call`；5 个请求全部 `200`，调用台账有 5 行且所有 `instanceId` 去重后只有 1 个，证明真实 sandbox resident 没有重复启动。

## 判定边界

L2-L5 暂记 `na`：manager -race 与真实 HTTP/sandbox/调用台账证据已核验，但没有该等级独立 Computer Use 逐帧、测量、视觉和 discoverability 证据；不越级登记。
