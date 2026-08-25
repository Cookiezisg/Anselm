# EDGE-203 playback lease rejects non-audio

- 结论：`pass`（L1 media-kind authorization）；L2-L5 按当前独立台架边界记 `na`。
- 目标：playback lease 只能为 audio kind 签发；文本、图片、文档等非音频附件必须在签发前明确返回
  `415 Unsupported Media Type`，不能把普通文件暴露到 bearerless playback 路由。

## focused regression

```text
cd backend && mise exec -- go test ./internal/transport/httpapi/handlers \
  -run '^TestAttachmentHandlerPlaybackLeaseRejectsNonAudio$' \
  -count=1 -race -v
=== RUN   TestAttachmentHandlerPlaybackLeaseRejectsNonAudio
--- PASS: TestAttachmentHandlerPlaybackLeaseRejectsNonAudio (0.02s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/transport/httpapi/handlers 1.858s
```

测试上传一个 `text/plain` 附件后调用 playback-lease，handler 在 token 生成和内存 lease 写入之前按
metadata kind 拒绝，响应为 `415`；因此不存在可被后续 bearerless fetch 使用的播放 token。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中用真实 App 与音频/非音频附件完成五通道观察
L3 na: 没有本格独立的非音频签发请求、响应首帧和 token 状态测量
L4 na: 没有本格独立的错误提示、附件类型说明和播放控件视觉 craft 比对
L5 na: 没有本格独立的新用户发现并理解只有音频可播放的 discoverability session
```

## source anchors

- `backend/internal/transport/httpapi/handlers/attachment.go`: `CreatePlaybackLease` 的 kind gate
- `backend/internal/transport/httpapi/handlers/attachment_test.go`: non-audio 返回 415 回归
