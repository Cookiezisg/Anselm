# EDGE-127 env failed 仍创建成功

- 结论：`pass`（L1 function 创建与运行时门控）；L2-L5 按当前台架边界记 `na`。
- 预期：依赖安装失败不能阻断 function 实体创建；实体必须带可见的 `envStatus=failed` 与错误，直到用户修复环境前，`:run` 才明确返回 `FUNCTION_ENV_NOT_READY`，不能把创建失败或运行时缺包混成一个不透明错误。

## 证据

真实 function 生命周期：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestContractEntities_FunctionEnvLifecycle$' -count=1 -v
--- PASS: TestContractEntities_FunctionEnvLifecycle (6.77s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 7.440s
```

该真实 HTTP 场景用不存在的依赖创建 function，断言创建返回 `201`；随后 GET 读取 active version，断言 `envStatus=failed` 且 `envError` 非空；最后调用 `:run`，断言返回 `422 FUNCTION_ENV_NOT_READY`。创建、失败状态可见、运行时门控三段均由产品 API 实际路径完成，而不是只测 repository。

## 判定边界

L2-L5 暂记 `na`：真实 HTTP/状态错误证据不替代该等级独立 Computer Use 逐帧、测量、视觉和 discoverability 证据；不把失败态 API 证据越级登记为完整产品体验通过。
