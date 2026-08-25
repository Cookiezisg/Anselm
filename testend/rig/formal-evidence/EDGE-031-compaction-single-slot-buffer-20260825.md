# EDGE-031 · 回合收尾期单槽缓冲

## Verification

After the first assistant message is finalized, synchronous context compaction may still be
running. During that tail window, the queue deliberately accepts exactly one follow-up Send into
its single slot. The follow-up does not start before compaction releases; after release it runs.
This preserves responsiveness without allowing concurrent history/summary mutation.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestSendDuringCompactionUsesSingleBuffer' -count=1  PASS
go test -race ./internal/app/chat -run 'TestSendDuringCompactionUsesSingleBuffer' -count=1  PASS
```

## Five-level applicability

- L1 `pass`: compaction 期间一条后续 Send 进入单槽但不提前启动，释放后才运行；测量法 `measure:edge031-compaction-single-slot-buffer`。
- L2 `na`: 本轮未为 compaction tail window 单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused/race 回归没有真实 App frame、SSE、backend journal 或 frontend console 观测面。
- L4 `na`: 本条验证队列时序与历史一致性，不含独立视觉几何/动效/排版 surface。
- L5 `na`: 这是 chat 内部收尾协议，不是独立用户导航入口；用户反馈由 chat/composer 旅程覆盖。
