# EDGE-131 revert 到很老版本后再 trim

- 结论：`pass`（L1 function 版本指针与 trim active 保护）；L2-L5 按当前台架边界记 `na`。
- 预期：revert 是纯指针移动；后续 edit 会让新版本成为 active 并按 cap 裁剪旧的非 active 版本。trim 的底层保护必须独立成立：如果 active 指针确实指向最老版本，即使它低于 cutoff 也不能被删除或回收环境。

## 证据

focused store regression：

```text
cd backend && mise exec -- go test ./internal/infra/store/function -run '^TestVersion_TrimProtectsActive$' -count=1 -race -v
=== RUN   TestVersion_TrimProtectsActive
--- PASS: TestVersion_TrimProtectsActive (0.03s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/infra/store/function 1.630s
```

该回归直接把 active pointer 设为最老的 v1，再按 cap trim；断言 v1 保留、v2 被裁、返回的 reclaim 列表只包含 v2 的 env，证明“active 优先于 cap”不是文字约定。

真实 function HTTP 路径：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestContractEntities_FunctionRevertThenTrimMaintainsActivePointer$' -count=1 -v
--- PASS: TestContractEntities_FunctionRevertThenTrimMaintainsActivePointer (6.31s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 6.915s
```

真实路径创建 v1、edit 到 v50、revert 回 v1、再 edit 到 v51；断言 v51 成为新的 active、版本集合收敛到 cap=50、旧 v1 已不再被错误地当作 active。该路径与 focused store 边界合并覆盖了“回退后新编辑”的用户语义和“最老 active 不得裁”的底层不变量。

## 判定边界

L2-L5 暂记 `na`：应用/HTTP、版本集合、active 指针和 store reclaim 证据已核验，但没有该等级独立 Computer Use 逐帧、测量、视觉和 discoverability 证据；不越级登记。
