# EDGE-129 env 被 GC 后重试一次

- 结论：`pass`（L1 function 环境回收后的透明重建重试）；L2-L5 按当前台架边界记 `na`。
- 预期：sandbox GC 回收 function 当前版本的环境后，下一次 `:run` 遇到 `ErrEnvNotFound`，应重建同一 active version 的环境并只重试一次；用户得到原调用的成功结果，不需要手动编辑或重试。

## 证据

真实 function 生命周期：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestContractEntities_FunctionEnvLifecycle$' -count=1 -v
--- PASS: TestContractEntities_FunctionEnvLifecycle (5.56s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 5.880s
```

真实 HTTP 路径创建可运行 function 后调用 `sandbox:gc?olderThanDays=0`，日志确认回收 1 个环境；随后对同一 function 的 `:run` 日志出现 `function env reclaimed; rebuilding then retrying`，最终 HTTP `200` 且运行结果成功。该场景还确认 active version 没有被重新铸造，GC 后恢复是运行时透明动作。

## 判定边界

L2-L5 暂记 `na`：真实 HTTP、sandbox GC 和成功回执已核验，但没有该等级独立 Computer Use 逐帧、测量、视觉和 discoverability 证据；不越级登记。
