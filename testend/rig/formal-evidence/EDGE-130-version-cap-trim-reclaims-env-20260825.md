# EDGE-130 版本 cap 50 trim 回收 venv

- 结论：`pass`（L1 function 版本上限与环境回收）；L2-L5 按当前台架边界记 `na`。
- 预期：同一 function 连续 edit 超过 50 个版本时，硬删最老的非 active 版本；同时经 `DestroyEnv` 回收被删版本的 venv，active version 不得被误删，也不留下孤儿环境。

## 证据

focused regression：

```text
cd backend && mise exec -- go test ./internal/app/function -run '^TestEdit_ReclaimsTrimmedVersionEnv$' -count=1 -race -v
=== RUN   TestEdit_ReclaimsTrimmedVersionEnv
--- PASS: TestEdit_ReclaimsTrimmedVersionEnv (0.37s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/function 2.083s
```

真实版本生命周期：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestContractEntities_FunctionVersionCapTrimReclaimsEnvs$' -count=1 -v
--- PASS: TestContractEntities_FunctionVersionCapTrimReclaimsEnvs (7.51s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 7.793s
```

真实 HTTP 场景创建 function 后连续执行从 v2 到 v51 的 50 次 edit，随后读取 `/versions` 与 `/sandbox/envs`；断言版本 cap、最老非 active 版本的删除、v1 环境回收及 active env 保留均成立。进程收台时 sandbox 无残留句柄。

## 判定边界

L2-L5 暂记 `na`：真实 HTTP/数据库与 sandbox 列表对账已核验，但没有该等级独立 Computer Use 逐帧、测量、视觉和 discoverability 证据；不越级登记。
