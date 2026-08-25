# EDGE-027 · ask_user 无交互用户

## Verification

In a workflow/agent-style context with no humanloop broker, `ask_user` fails immediately with the
stable `ASK_NO_INTERACTIVE_USER` unavailable sentinel. It does not block waiting for an impossible
user and does not fabricate an answer; the model can receive the explicit result and proceed without
asking.

Focused verification passed:

```text
go test ./internal/app/tool/ask -run 'TestExecuteWithoutInteractiveUserFailsLoudly' -count=1  PASS
go test -race ./internal/app/tool/ask -run 'TestExecuteWithoutInteractiveUserFailsLoudly' -count=1  PASS
```

## Five-level applicability

- L1 `pass`: 无 broker 时立即返回 `ASK_NO_INTERACTIVE_USER`，不阻塞、不伪造回答；测量法 `measure:edge027-ask-no-interactive-user`。
- L2 `na`: 本轮未为 workflow/agent 非交互 ask 单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused/race 回归没有真实 App frame、SSE、backend journal 或 frontend console 观测面。
- L4 `na`: 本条验证不可用状态反馈，不含独立视觉几何/动效/排版 surface。
- L5 `na`: 这是非交互执行协议错误边界，不是用户可导航入口；可发现性由对应 workflow/agent 旅程覆盖。
