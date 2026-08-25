# EDGE-193 attachment no-vision degradation

- 结论：`pass`（L1 focused + real HTTP/provider wire）；L2-L5 按当前独立台架边界记 `na`。
- 目标：无 vision 能力的模型收到图片时，附件仍是可下载的持久事实，但模型输入按原顺序降为明确
  的文字占位，不发送 `image_url` 或图片字节，不伪装模型看见了图片。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/attachment \\
  -run '^TestToContentParts_NonVisionDegradesImage$' \\
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/attachment
```

同包既有 multimodal provider 回归还锁定了 text-only parts 在 DeepSeek wire 上必须坍缩为字符串，避免
纯文本端点因数组形 content 得到永久 400；本格的 testend 场景则验证完整聊天入口。

## real HTTP/provider-wire regression

```text
cd testend && mise exec -- go test ./scenarios \\
  -run '^TestChatR3_NonVisionImageDegradesOnWire$' \\
  -count=1 -v -timeout 600s
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 2.809s
```

场景把默认模型切换到 mock provider 未列出的 `text-only-fixture-193`，使模型解析器采用保守的
`Vision=false` 能力；真实上传 `text-only-photo.png` 并发送聊天回合。解析捕获的 provider request
只在真实 `role=user` content 中看到文件名和 `no native vision input` 占位，不含 `image_url` 或 PNG
base64；回合 `completed`，附件 content GET=200 且字节数不变。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成无 vision 图片回合的五通道 App 录制
L3 na: 没有本格独立的降级等待、提示可读性和输入反馈 Computer Use 时序测量
L4 na: 没有本格独立的附件卡片、降级占位与图片不出线的视觉 craft 比对
L5 na: 没有本格独立的新用户发现并理解模型不支持视觉时产品如何处理的 discoverability session
```
