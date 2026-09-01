# EDGE-172 无 uploader 时的 MCP 媒体

- 结论：`pass`（L1 honest no-uploader degradation）；L2-L5 是有明确适用性边界的 `na`，不是缺少验收工作的临时 waiver。
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
L2 na: 本行定义的是未注入可选 MediaUploader 的内部 service/REST 装配；正式桌面 composition root 始终创建 attachment service 并注入 MCP，产品没有产生该装配的用户动作或运行时配置，因此不存在可观察的真实 App 状态
L3 na: 该内部装配没有独立的桌面交互路径，顺滑度不是本行的适用对象；L1 已覆盖调用保持成功与占位保真
L4 na: 该内部装配没有独立的桌面媒体呈现路径，视觉 craft 不是本行的适用对象；若产品 UI 显示媒体则走 attachment receipt 路径
L5 na: 该内部装配没有可供新用户发现的产品入口，discoverability 不是本行的适用对象；可发现性属于有 uploader 的 MCP 媒体能力行
```

这四条是对覆盖行语义的适用性裁决，不是“尚未启动真实 App”的证据缺口：正常产品启动路径没有
可由用户触发的 `uploader=nil` 状态。若未来 composition root 引入可配置的无 uploader 模式，必须撤销
这些 `na`，重新按真实 App 五通道建立独立 session，不得沿用本裁决。
