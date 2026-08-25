# EDGE-030 · 生成中再 Send

## Verification

Once the first assistant turn has actually entered the provider stream, a second `Send` for the
same conversation immediately returns `STREAM_IN_PROGRESS`. It is not buffered behind the active
turn. The focused test uses an entry barrier rather than repeated attempts, so the assertion is
deterministic at the real in-flight boundary.

Focused verification passed:

```text
go test ./internal/app/chat -run 'TestSend_StreamInProgress' -count=1  PASS
go test -race ./internal/app/chat -run 'TestSend_StreamInProgress' -count=1  PASS
```

## Five-level applicability

- L1 `pass`: provider stream 已进入后下一条 Send 立即返回 `STREAM_IN_PROGRESS`，不排队；测量法 `measure:edge030-send-while-generating`。
- L2 `na`: 本轮未为生成中重复 Send 单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused/race 回归没有真实 App frame、SSE、backend journal 或 frontend console 观测面。
- L4 `na`: 本条验证并发发送反馈与队列语义，不含独立视觉几何/动效/排版 surface。
- L5 `na`: 这是 chat 回合并发协议边界，不是独立用户导航入口；用户反馈由 composer/chat 旅程覆盖。
