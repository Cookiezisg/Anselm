# EDGE-171 MCP 媒体逐件 best-effort

- 结论：`pass`（L1 per-item media landing contract）；L2-L5 按当前台架边界记 `na`。
- 预期：MCP 一次返回多件 image/audio 时，一件附件落库失败不使整个调用失败；成功件成为一等
  附件并追加 `mcp_media` receipt，失败件保留其原始占位叙事。

## focused per-item failure regression

```text
cd backend && mise exec -- go test ./internal/app/mcp \
  -run '^(TestCallTool_MediaLandsAsReceipt|TestCallTool_MediaUploadBestEffortPerItem)$' \
  -count=1 -race -v
=== RUN   TestCallTool_MediaLandsAsReceipt
--- PASS: TestCallTool_MediaLandsAsReceipt (0.00s)
=== RUN   TestCallTool_MediaUploadBestEffortPerItem
--- PASS: TestCallTool_MediaUploadBestEffortPerItem (0.00s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/mcp 2.202s
```

新增回归让三件媒体按 PNG/MP3/JPEG 顺序上传并故意让第二件失败：调用仍成功、结果保留失败件
`[audio: failed]`，只为两件成功媒体追加 receipt，上传顺序/扩展名和成功 MCP call ledger 均对账。
既有单媒体 receipt 与无 uploader 诚实降级也同步通过。

## real stdio → attachment → vision wire

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestMCP_ArtifactReachesVisionModel$' -count=1 -v -timeout 600s
--- PASS: TestMCP_ArtifactReachesVisionModel (4.84s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 5.486s
```

真实 stdio MCP server 产出 PNG，HTTP 黑盒确认附件内容可读、`mcp_media` call ledger 落账，并由
llmmock 线缆确认同一 PNG 字节以 native image part 到达下一次 vision model 请求。testend 日志中的
free-tier 回环拒绝与 shutdown embedder cancel 是既定隔离/收台行为，不是媒体链失败。

## 判定边界

```text
L2 na: 本格有 focused per-item failure 与真实 stdio/wire，但没有独立真实 App 五通道 session
L3 na: 没有本格独立 Computer Use 多件媒体失败逐帧时序测量
L4 na: 没有本格独立部分成功媒体结果的视觉成品与 craft 比对
L5 na: 没有本格独立的新用户发现媒体失败提示并理解可用部分的 discoverability session
```
