# EDGE-139 handler config 不完整

- 结论：`pass`（L1 handler 必填配置门）；L2-L5 按当前台架边界记 `na`。
- 预期：handler 声明必填 init arg 但未配置时，调用在 spawn 前被拒绝为 `HANDLER_CONFIG_INCOMPLETE`，不创建 resident；失败仍写入一条调用审计，补齐配置后才允许启动和调用。

## 证据

focused service regression：

```text
cd backend && mise exec -- go test ./internal/app/handler -run '^TestConfig_GatesSpawn$' -count=1 -race -v
=== RUN   TestConfig_GatesSpawn
--- PASS: TestConfig_GatesSpawn (0.08s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/handler 2.038s
```

focused 测试创建必填 `api_key` 但不配，断言返回 `ErrConfigIncomplete`、runner spawn 计数为 0，SearchCalls 仍有一条 failed 行和 `FailedCount=1`；随后补 config，resident 才进入 running 并成功调用。

真实 handler HTTP path：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestContractEntities_HandlerRevertConfigMergePatchIterate$' -count=1 -v
--- PASS: TestContractEntities_HandlerRevertConfigMergePatchIterate (4.99s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 5.310s
```

真实路径先配置 `a/b` 成功调用，再用 JSON Merge Patch 删除必填 `b`；HTTP `:call` 返回 `422 HANDLER_CONFIG_INCOMPLETE`，config 查询明确列出 `missingConfig=[b]`，补回 `b` 后恢复调用。全程没有错误 resident 被建立，收台时 sandbox handles 为 0。

## 判定边界

L2-L5 暂记 `na`：focused -race、真实 HTTP、spawn 计数和调用审计证据已核验，但没有该等级独立 Computer Use 逐帧、测量、视觉和 discoverability 证据；不越级登记。
