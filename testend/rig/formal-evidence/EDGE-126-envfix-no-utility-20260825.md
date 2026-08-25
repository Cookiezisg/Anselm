# EDGE-126 未配 utility 模型时的 envfix

- 结论：`pass`（L1 envfix 无 utility 的诚实降级与真实 function 生命周期）；L2-L5 按当前台架边界记 `na`。
- 预期：utility 场景未配置时，环境安装失败应以 `OK=false` 结束；安装器的 stderr/错误必须留在 History 并呈给建构 LLM，不能返回 Go 层崩溃，也不能伪造可运行环境。

## 证据

focused regression：

```text
cd backend && mise exec -- go test ./internal/app/envfix -run '^TestProvision_NoUtilityModelDegrades$' -count=1 -race -v
=== RUN   TestProvision_NoUtilityModelDegrades
--- PASS: TestProvision_NoUtilityModelDegrades (0.00s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/envfix 1.647s
```

该测试让 sandbox 首次安装失败，并让 model picker 返回 `ErrNotConfigured`；断言确认只尝试一次、结果 `OK=false`，不会在没有 utility 修复器时凭空重试。

真实 function 生命周期：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestContractEntities_FunctionEnvLifecycle$' -count=1 -v
--- PASS: TestContractEntities_FunctionEnvLifecycle (5.98s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 6.336s
```

真实 HTTP 日志确认：坏依赖 function 返回 `201` 并可读取 `envStatus=failed`，后端记录 `envfix: dep repair unavailable; stopping retries` 及 `no model configured for scenario`，随后运行返回 `422 FUNCTION_ENV_NOT_READY`。错误不是裸 Go error，失败状态和原因可继续被产品层读取；实体 build 的通知路径也正常收尾。

## 判定边界

L2-L5 暂记 `na`：真实场景证明了 HTTP/状态/错误边界，但当前会话没有独立 Computer Use 逐帧、时延曲线、视觉美观和 discoverability 证据；不把 contract 场景越级当成这些等级的证明。
