# EDGE-161 subagent 墙钟

- 结论：`pass`（L1 subagent own wall-clock）；L2-L5 按当前台架边界记 `na`。
- 预期：从没有父回合 deadline 的路径进入 `Spawn` 时，subagent 仍必须自带 `ChatTurnSec`；阻塞
  provider 到点后收尾为 `cancelled`，子消息 durable 落终态，并把截断原因浮出给父调用方。

## focused subagent timeout

```text
cd backend && mise exec -- go test ./internal/app/subagent \
  -run '^TestSpawn_WallClockTimeout$' -count=1 -race -v
=== RUN   TestSpawn_WallClockTimeout
--- PASS: TestSpawn_WallClockTimeout (1.02s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/subagent 2.967s
```

测试使用永不返回的 fake stream，并将 `ChatTurnSec` 缩为 1 秒。`Spawn` 不依赖父 ctx 的 deadline，
自建 run context 到点取消；结果在有限时间内返回，子 message 是 cancel/error terminal，结果文本
包含 cutoff 注记而不是无限等待。

## real HTTP subagent tree

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestChatR3_SubagentNestedTree$' -count=1 -v -timeout 600s
--- PASS: TestChatR3_SubagentNestedTree (2.48s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 3.047s
```

真实 HTTP 场景确认产品接线：父消息经 `Subagent` 工具派生 general-purpose 子运行，子工具集不含
`Subagent`，子回答回喂父对话，子消息以 `SubagentID` durable 落在父对话树下。该场景使用确定性
provider，不为它虚构独立 managed-gateway Computer Use 录屏。

## 判定边界

本格验证的是运行时保护边界；没有独立完整 App Computer Use 五通道 session，也没有独立视觉、
等待时序或 discoverability 证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为 focused subagent timeout 与真实 HTTP 子树接线证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/动作到首反馈时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
