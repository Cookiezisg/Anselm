# EDGE-020 · approve_always 会话白名单

## Verification

`approve_always` 只写入 broker 的 `(conversationID, tool)` 授权键。第一次危险调用仍经过 interaction；
同一会话再次调用同一工具不再弹闸，但换工具或换会话都必须建立自己的批准。越界驻地写另有不可豁免的事实
闸，不被该白名单扩大。

Focused verification passed:

```text
go test ./internal/app/loop -run 'TestDispatchWithGate_(ApproveAlwaysIsScopedToConversationAndTool|BlocksSideEffectUntilApproval)' -count=1  PASS
go test -race ./internal/app/loop -run 'TestDispatchWithGate_(ApproveAlwaysIsScopedToConversationAndTool|BlocksSideEffectUntilApproval)' -count=1  PASS
```

回归实际走 loop gate：同一 `(cv1, deploy)` 第一次记录 approve_always、第二次 `humanApproved=false` 且不
再 surface；`publish` 和 `(cv2, deploy)` 各自再 surface 一次并经批准执行。

## Five-level applicability

- L1 `pass`: 白名单仅作用于同一会话同一工具，授权不扩散；测量法
  `measure:edge020-approve-always-scope`。
- L2 `na`: 本轮未为 chat interaction 单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused gate test 无真实 App interaction frame、等待时延或终端数据。
- L4 `na`: 本条验证授权范围，不含独立视觉几何/动效 surface。
- L5 `na`: 白名单是会话内执行协议，不是用户可导航入口。
