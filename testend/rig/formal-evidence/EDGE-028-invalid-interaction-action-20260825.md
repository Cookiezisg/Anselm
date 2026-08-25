# EDGE-028 · interaction 枚举外 action

## Verification

Resolving an interaction with a typo such as `aprove` is rejected before conversation or pending
interaction lookup with the stable `INTERACTION_INVALID_ACTION` error. The structured details expose
the complete closed set `approve`, `approve_always`, `deny`, `accept`, and `decline`, so a typo never
silently becomes a denial of the user's intended approval.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestResolveInteractionRejectsUnknownActionLoudly' -count=1  PASS
go test -race ./internal/app/chat -run 'TestResolveInteractionRejectsUnknownActionLoudly' -count=1  PASS
```

## Five-level applicability

- L1 `pass`: 枚举外 action 先返回 `INTERACTION_INVALID_ACTION`，details 带完整合法动作集；测量法 `measure:edge028-invalid-interaction-action`。
- L2 `na`: 本轮未为 interaction resolve 负路径单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused/race 回归没有真实 App frame、SSE、backend journal 或 frontend console 观测面。
- L4 `na`: 本条验证错误反馈结构，不含独立视觉几何/动效/排版 surface。
- L5 `na`: action 枚举是 interaction 协议边界，不是独立用户导航入口；提示发现性由 chat interaction 旅程覆盖。
