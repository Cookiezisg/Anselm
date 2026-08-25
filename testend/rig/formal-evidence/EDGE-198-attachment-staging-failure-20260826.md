# EDGE-198 attachment staging failure

- 结论：`pass`（L1 explicit failure propagation）；L2-L5 按当前独立台架边界记 `na`。
- 目标：受管 staging 端点失败时，本回合必须大声失败，不能把媒体静默删除、伪装成成功回答，或把该错误
  混成不可交付格式的正常降级。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/attachment \
  -run '^TestToContentParts_ManagedMediaFailureStopsTurn$' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/attachment 1.680s

cd backend && mise exec -- go test ./internal/app/chat -run '^TestLoadHistory_ReportsAttachmentTransportFailure$' \
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/chat 1.870s

cd backend && mise exec -- go test ./internal/app/loop -run '^TestRun_LoadHistoryError$' \
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/loop 2.134s
```

managed uploader 返回 `gateway unavailable` 时，attachment service 原样向上返回 staging error，未生成
任何成功媒体 part。chat history 保留 `render attachments` 上下文；loop 的唯一收尾写入
`StatusError / StopReasonError / INTERNAL_ERROR`，并发出终止帧，不会让流式气泡永远 pending。
这与 HEIC/AVIF 的“上传前发现不可交付、诚实降级”刻意不同：transport failure 是系统故障，必须显式失败、
允许用户重试，而不是假装模型看到了或安静跳过。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中让真实 managed staging 失败并完成 App 五通道录制
L3 na: 没有本格独立的失败首帧、终止帧和重试入口时序测量
L4 na: 没有本格独立的错误卡片、错误码/文案与失败状态视觉 craft 比对
L5 na: 没有本格独立的新用户发现并理解 staging 失败及重试路径的 discoverability session
```
