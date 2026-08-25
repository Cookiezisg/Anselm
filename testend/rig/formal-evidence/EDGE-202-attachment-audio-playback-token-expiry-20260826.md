# EDGE-202 audio playback token expiry

- 结论：`pass`（L1 bounded bearerless playback lease）；L2-L5 按当前独立台架边界记 `na`。
- 目标：音频播放端点签发短期、仅内存 token；过期后 bearerless fetch 必须返回 404，不能继续泄露音频字节。
  未过期路径仍需支持没有 Authorization/workspace header 的原生播放器访问与 Range seek。

## focused regression

```text
cd backend && mise exec -- go test ./internal/transport/httpapi/handlers \
  -run '^TestAttachmentHandlerPlaybackLease(Expires|ServesAudioWithoutBearerHeader)$' \
  -count=1 -race -v
=== RUN   TestAttachmentHandlerPlaybackLeaseServesAudioWithoutBearerHeader
--- PASS: TestAttachmentHandlerPlaybackLeaseServesAudioWithoutBearerHeader (0.02s)
=== RUN   TestAttachmentHandlerPlaybackLeaseExpires
--- PASS: TestAttachmentHandlerPlaybackLeaseExpires (0.01s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/transport/httpapi/handlers 2.174s
```

测试用可控时钟签发 1 秒 lease，时钟推进 2 秒后 fetch 返回 404；同组正向回归确认未过期 URL 在
没有 bearer/workspace header 时仍返回音频、MIME 正确，并以 `Range: bytes=0-4` 返回 206 和正确片段。
`takePlaybackLease` 每次访问先清除 `ExpiresAt <= now` 的 token，过期 token 不再进入 metadata/blob 读取。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中用真实桌面播放器、跨进程等待和五通道观察 token 过期
L3 na: 没有本格独立的签发、临期、过期 fetch 和 Range seek 时序测量
L4 na: 没有本格独立的音频控件、过期错误提示和 seek 反馈视觉 craft 比对
L5 na: 没有本格独立的新用户发现并理解播放 URL 过期后需要重新播放/重新签发的 discoverability session
```

## source anchors

- `backend/internal/transport/httpapi/handlers/attachment.go`: in-memory playback lease、可控时钟与过期清扫
- `backend/internal/transport/httpapi/handlers/attachment_test.go`: bearerless audio fetch、Range 与 expiry 回归
