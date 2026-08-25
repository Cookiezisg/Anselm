# EDGE-138 handler 孤儿 config key

- 结论：`pass`（L1 handler active schema config 过滤）；L2-L5 按当前台架边界记 `na`。
- 预期：旧版本留下的 config key 在新 active schema 删除对应 init arg 后，不得作为意外 kwarg 传进 `__init__`；spawn 按当前 schema 过滤但不改写持久 config，revert 回旧版本后原值仍可恢复使用。

## 证据

focused filter regression：

```text
cd backend && mise exec -- go test ./internal/app/handler -run '^TestFilterConfigToSchemaDropsOrphans$' -count=1 -race -v
=== RUN   TestFilterConfigToSchemaDropsOrphans
--- PASS: TestFilterConfigToSchemaDropsOrphans (0.00s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/handler 1.983s
```

测试断言 `old_key` 不进入 active schema 过滤结果，`token` 及其值保留，同时输入的持久 config map 不被原地改写。

真实 handler HTTP path：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestContractEntities_HandlerResidentSemantics$' -count=1 -v
--- PASS: TestContractEntities_HandlerResidentSemantics (6.32s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 6.970s
```

真实场景先配置 v1 的 `token` 并成功调用，再 edit 到不声明 token 的 v2，存量 config 保留但 v2 仍成功返回；随后 revert v1，原 token 再次生效。整个路径没有 `__init__` TypeError，HTTP 调用均为 200，收台时 sandbox handles 为 0。

## 判定边界

L2-L5 暂记 `na`：focused -race、真实 HTTP、版本切换和 sandbox spawn 证据已核验，但没有该等级独立 Computer Use 逐帧、测量、视觉和 discoverability 证据；不越级登记。
