# EDGE-157 agent 声明输出回解析

- 结论：`pass`（L1 declared-output parsing and loud failure）；L2-L5 按当前台架边界记 `na`。
- 预期：声明 outputs 后，成功终答必须回解析成声明字段对象；多字段自由文本必须大声失败，
  不把裸文本伪装成结构化输出；非 OK 终态的 Output 必须为 nil，原始叙述仍留在 transcript。

## focused parser and terminal regressions

```text
cd backend && mise exec -- go test ./internal/app/agent \
  -run '^(TestService_InvokeLoudFailsUnstructuredMultiOutput|TestCoerceDeclaredOutputs_FencedJSONWithProse|TestService_InvokeFailedTerminalNullsDeclaredOutput)$' \
  -count=1 -race -v
--- PASS: TestService_InvokeFailedTerminalNullsDeclaredOutput (0.05s)
--- PASS: TestService_InvokeLoudFailsUnstructuredMultiOutput (0.06s)
--- PASS: TestCoerceDeclaredOutputs_FencedJSONWithProse (0.00s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/agent 1.825s
```

覆盖 fenced JSON 前有 prose、裸 JSON、纯 prose 多字段拒绝，以及 provider error 后 declared
output 置空四条形状边界。

## real HTTP agent seat

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestAgentR2_PromptAssembly$' -count=1 -v -timeout 600s
--- PASS: TestAgentR2_PromptAssembly (2.26s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 2.778s
```

真实 agent 通过 HTTP 创建 declared `verdict` output，模型 mock 返回 `{"verdict":"pass"}`，
invoke 成功；同时检查真实 agent prompt 明确要求单一 JSON object，skill/knowledge/input 正确
进入 agent 视角而没有 chat 主视角泄漏。

## 判定边界

本格没有独立完整 App Computer Use 五通道 session，也没有独立视觉、等待时序或 discoverability
证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为 agent parser/HTTP seat 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
