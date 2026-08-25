# EDGE-162 subagent 深度守卫

- 结论：`pass`（L1 recursion/tool-set invariant）；L2-L5 按当前台架边界记 `na`。
- 预期：subagent 无论类型都不能再看到或调用 `Subagent`，并且 service 层即使 ctx 已处于子运行
  也必须拒绝递归 Spawn；深度固定为 1，避免递归树失控。

## focused recursion and filtering

```text
cd backend && mise exec -- go test ./internal/app/subagent \
  -run '^(TestFilterTools|TestSpawn_RecursionRefused)$' -count=1 -race -v
=== RUN   TestFilterTools
--- PASS: TestFilterTools (0.00s)
=== RUN   TestSpawn_RecursionRefused
--- PASS: TestSpawn_RecursionRefused (0.01s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/subagent 1.722s
```

`filterTools` 对 Explore/Plan/general-purpose 均剔除 `Subagent`，并额外剔除
`get_subagent_trace`；直接带父 subagent context 调 `Spawn` 也在 service 层拒绝。

## real HTTP tree witness

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestChatR3_SubagentNestedTree$' -count=1 -v -timeout 600s
--- PASS: TestChatR3_SubagentNestedTree (2.48s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 3.047s
```

真实 HTTP 父对话派出 general-purpose 子运行；场景读取 provider request 的子工具列表并断言
不存在 `Subagent`，随后验证子回答回喂父对话且子消息以 `SubagentID` 落在父树中。没有把同一
次确定性 HTTP harness 当作独立 Computer Use 视觉证据。

## 判定边界

```text
L2 na: 递归守卫是 runtime/tool-set invariant，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧或动作到反馈时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 深度守卫不是用户可导航入口，没有本格独立 discoverability session
```
