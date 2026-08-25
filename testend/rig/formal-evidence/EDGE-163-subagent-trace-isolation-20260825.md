# EDGE-163 get_subagent_trace 隔离

- 结论：`pass`（L1 trace isolation）；L2-L5 按当前台架边界记 `na`。
- 预期：`get_subagent_trace` 可以由父对话读取自己的子运行，但必须从 subagent 工具面剔除，
  不能让子运行读取父对话中其它 subagent 的隐藏 trace。

## focused trace tool contract

```text
cd backend && mise exec -- go test ./internal/app/tool/subagent \
  -run '^TestTraceTool_' -count=1 -race -v
=== RUN   TestTraceTool_List
--- PASS: TestTraceTool_List (0.00s)
=== RUN   TestTraceTool_Detail
--- PASS: TestTraceTool_Detail (0.00s)
=== RUN   TestTraceTool_NoConversation
--- PASS: TestTraceTool_NoConversation (0.00s)
=== RUN   TestTraceTool_UnknownID
--- PASS: TestTraceTool_UnknownID (0.00s)
=== RUN   TestTraceTool_ValidateInput
--- PASS: TestTraceTool_ValidateInput (0.00s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/tool/subagent 2.062s
```

focused contract 覆盖父对话的 list/detail、无 conversation、未知 run id 与参数校验；trace reader
只读取当前 conversation 的 `SubagentID` 子消息。

## real HTTP isolation and tree witness

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^(TestContractChat_SubagentTraceIsolation|TestChatR3_SubagentNestedTree)$' \
  -count=1 -v -timeout 600s
--- PASS: TestChatR3_SubagentNestedTree (2.51s)
--- PASS: TestContractChat_SubagentTraceIsolation (2.73s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 3.012s
```

真实 HTTP 回归同时确认：父对话能读取自己的 subagent trace；子请求工具列表没有
`get_subagent_trace` 或 `Subagent`；子消息仍以 `SubagentID` 落在父树，结果回喂不泄漏其它
对话的 trace。该确定性 HTTP harness 不冒充独立 Computer Use 视觉证据。

## 判定边界

```text
L2 na: 当前为 trace reader/真实HTTP隔离契约，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧或动作到反馈时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: trace isolation 是内部权限边界，不是用户可发现入口
```
