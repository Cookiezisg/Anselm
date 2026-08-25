# EDGE-029 · 重复 resolve interaction

## Verification

After an ask interaction is resolved once through the chat service, resolving the same
conversation/tool-call id again returns `NO_PENDING_INTERACTION`. The second request does not
replay the answer, re-open the interaction, or create another state transition. The broker-level
unknown/already-resolved behavior and the chat conversation-scoped boundary are both covered.

Focused verification passed:

```text
go test ./internal/app/chat ./internal/app/humanloop -run 'TestResolveInteraction_ConversationScoped|TestResolveUnknownIsNoop' -count=1  PASS
go test -race ./internal/app/chat ./internal/app/humanloop -run 'TestResolveInteraction_ConversationScoped|TestResolveUnknownIsNoop' -count=1  PASS
```

## Five-level applicability

- L1 `pass`: 首次 resolve 后再次 resolve 同一 toolCall 返回 `NO_PENDING_INTERACTION`，重复决议安全无副作用；测量法 `measure:edge029-duplicate-resolve-interaction`。
- L2 `na`: 本轮未为重复 interaction resolve 单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused/race 回归没有真实 App frame、SSE、backend journal 或 frontend console 观测面。
- L4 `na`: 本条验证幂等状态边界，不含独立视觉几何/动效/排版 surface。
- L5 `na`: 重复 resolve 是 interaction 协议边界，不是独立用户导航入口；交互反馈由 chat 旅程覆盖。
