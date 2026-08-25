# EDGE-172 无 uploader 时的 MCP 媒体

- 结论：`pass`（L1 honest no-uploader degradation）；L2-L5 按当前台架边界记 `na`。
- 预期：未装配 attachment uploader 时，MCP 返回图/音的调用仍成功，保留明确占位叙事，不伪造
  `attachmentId` 或 `mcp_media` receipt，也不因可选媒体落地能力缺席而失败整次 MCP 调用。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/mcp \
  -run '^TestCallTool_MediaLandsAsReceipt$' -count=1 -race -v
=== RUN   TestCallTool_MediaLandsAsReceipt
--- PASS: TestCallTool_MediaLandsAsReceipt (0.00s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/mcp 1.657s
```

该回归先验证装配 uploader 时二进制得到 receipt，再用同一 MCP media client 在 `uploader=nil`
的 Service 上调用，断言调用无 error、原始 `[image: image/png]` 占位仍在、结果没有
`attachmentId`。因此这是显式能力缺席下的可解释降级，不是把媒体静默吞掉后谎称落地。

## 判定边界

```text
L2 na: 本格只有 focused service 装配边界，没有独立真实 App 五通道 session
L3 na: 没有本格独立 Computer Use 无 uploader 画面逐帧时序测量
L4 na: 没有本格独立媒体缺席占位的视觉成品与 craft 比对
L5 na: 没有本格独立的新用户发现媒体能力不可用并理解占位语义的 discoverability session
```
