# EDGE-158 agent 非 OK 终态置空输出

- 结论：`pass`（L1 non-OK declared-output terminal semantics）；L2-L5 按当前台架边界记 `na`。
- 预期：声明 outputs 的 agent 遇到 provider error、max-steps 或 tool-error-storm 等非 OK 终态
  时，`Output` 必须为 nil，不能把最后一段裸叙述当成结构化结果；叙述仍留在 transcript 供
  排查，执行状态和终止原因可审计。

## focused terminal regression

```text
cd backend && mise exec -- go test ./internal/app/agent \
  -run '^TestService_InvokeFailedTerminalNullsDeclaredOutput$' -count=1 -race -v
=== RUN   TestService_InvokeFailedTerminalNullsDeclaredOutput
--- PASS: TestService_InvokeFailedTerminalNullsDeclaredOutput (0.05s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/agent 1.825s
```

该回归让 declared-output agent 先产生 partial narration，再让 provider error 终止；结果非 OK
且 `Output=nil`，不会将 narration 伪装成声明对象。loop 层已有独立 max-steps 与 tool-error-
storm 终态码回归，本格不把它们重复包装成一条假 HTTP 旅程。

## 判定边界

本格没有独立完整 App Computer Use 五通道 session，也没有独立视觉、等待时序或 discoverability
证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为 agent service/loop terminal focused 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
