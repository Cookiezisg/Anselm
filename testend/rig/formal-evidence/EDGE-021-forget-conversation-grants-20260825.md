# EDGE-021 · 白名单随对话删除清除

## Verification

`chat.Service.ForgetConversation` is the lifecycle hook called by the conversation-delete
cascade. This verification constructs the real chat service, grants two tools to the conversation
being deleted and one tool to a second live conversation, then invokes the hook. Both grants for
the deleted conversation disappear while the live conversation's grant remains.

Focused verification passed:

```text
go test ./internal/app/chat ./internal/app/humanloop -run 'TestForgetConversationClearsOnlyDeletedConversationGrants|TestForgetDropsConversationGrants' -count=1  PASS
go test -race ./internal/app/chat ./internal/app/humanloop -run 'TestForgetConversationClearsOnlyDeletedConversationGrants|TestForgetDropsConversationGrants' -count=1  PASS
```

The chat-side test locks the integration hook; the humanloop test independently locks the
conversation-prefix deletion behavior and proves neighboring conversation grants survive.

## Five-level applicability

- L1 `pass`: 删除对话的 chat 生命周期钩子清掉该对话全部 `approve_always` 授权，且不影响其他对话；测量法 `measure:edge021-forget-clears-grants`。
- L2 `na`: 本轮未为内存态授权清理单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused/race 回归没有真实 App frame、SSE、后端运行 journal 或 frontend console 观测面。
- L4 `na`: 本条验证删除后的状态边界，不含独立视觉几何、动效或排版 surface。
- L5 `na`: 授权清理是删除生命周期内的不可见安全状态，不是用户可发现的入口。
