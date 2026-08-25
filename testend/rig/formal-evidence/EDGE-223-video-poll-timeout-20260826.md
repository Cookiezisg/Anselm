# EDGE-223 视频轮询超时诚实话

- 日期：2026-08-26
- 判定：L1 `pass`；L2-L5 `na`
- 法条：`measure:edge223-video-poll-timeout`

## 目标

视频生成是已向上游提交、可能持续数分钟的异步任务。若本地回合墙钟到期或被取消，
不能把“停止等待”伪装成“上游任务已取消”，也不能给用户假进度；必须返回
`VIDEO_GEN_FAILED`，并明确提示上游任务可能仍会完成。

## 可复核命令与结果

```text
cd backend
mise exec -- go test ./internal/app/tool/generate \
  -run 'TestVideo_ContextTimeoutSaysTheUpstreamMayStillComplete|TestVideo_ImpossibleLengthIsClampedNotSpent|TestVideo_ManagedTierRoutesVideo$' \
  -count=1 -race -v
```

结果：3 个测试均 `PASS`。

新增的 `TestVideo_ContextTimeoutSaysTheUpstreamMayStillComplete` 用本地 HTTP server 模拟
网关已经 `202 Accepted` 并返回 opaque handle，随后取消本地 context。它验证：

- 错误可被识别为 `llm.ErrVideoGenFailed`，序列化错误码为 `VIDEO_GEN_FAILED`；
- 错误包含 `may still complete` 的诚实恢复提示；
- 取消发生在首次轮询前，未再发送 GET 轮询请求。

同批回归也确认受管视频时长上限仍为 15 秒，且受管路由仍被正确发现。

## 未声称的等级

本格本轮没有启动真实 App、真实视频生成、Computer Use 录屏、独立 SSE witness、
frontend console 或 LLM wire session，因此 L2（五通道真相）、L3（顺滑）、L4（craft）、
L5（可发现性）均明确为 `na`。
