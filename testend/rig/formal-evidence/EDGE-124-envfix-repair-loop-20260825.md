# EDGE-124 envfix 自愈循环

- 结论：`pass`（L1 envfix 状态机与真实 function 生命周期边界）；L2-L5 按当前台架边界记 `na`。
- 预期：首次环境安装失败时，utility LLM 可修正依赖并重试，最多受限次数；成功结果必须保留尝试历史和最终完整依赖。若 utility 未配置，必须诚实停止而不是假装修复。

## 证据

envfix focused regression：

```text
cd backend && mise exec -- go test ./internal/app/envfix -run '^TestProvision_FixSucceeds$' -count=1 -race -v
--- PASS: TestProvision_FixSucceeds (0.00s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/envfix 1.939s
```

该测试让首次安装失败，utility 修正 typo 依赖，第二次安装使用修正后的完整依赖成功；断言 `AttemptsUsed=2`、历史 `[fail, ok]` 和最终依赖没有丢包。

真实 function 生命周期：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestContractEntities_FunctionEnvLifecycle$' -count=1 -v
--- PASS: TestContractEntities_FunctionEnvLifecycle (6.96s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 7.466s
```

真实 HTTP 证明坏依赖 function 仍可创建并显示 `envStatus=failed`，运行时大声返回 `FUNCTION_ENV_NOT_READY`；当前 testend 场景没有配置 utility model，故日志诚实为 `dep repair unavailable; stopping retries`。这确认未配置时不会伪造绿 env，但不能作为真实 utility repair UI 证据。

## 判定边界

L2-L5 暂记 `na`：没有独立 Computer Use 逐帧、时延曲线、视觉美观和 discoverability 证据；focused fake/产品 HTTP 证据不越级替代这些通道。
