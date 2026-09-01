# EDGE-275 · 文档超 1MB · 真实 App 现场红证据

正式 session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-094330`。

使用真实 API 创建恰好 `1,048,576` bytes 的合法文档 `doc_6f7834307b58d3b0`，再从真实 App
Library 打开。树行和 Inspector 能显示 `EDGE275 Limit Probe` 与 `1048.6k chars`，但中心
编辑区保持空白；App 进程持续约 `100% CPU`，Computer Use 状态读取超时。采样显示 Flutter
主线程持续执行 `BeginFrame`，backend 没有收到编辑保存或 `413`，只有 workspace 轮询。

session 证据：

- `evidence/EDGE-275-document-limit-real-app-red.md`
- `edge275-late-frame.png`
- `edge275-app-sample.txt`
- `screen.mov`

这不是 `DOCUMENT_CONTENT_TOO_LARGE` 的通过结论，而是合法上限文档无法正常呈现的产品红证据。
本格保持开放，不能把 L1 HTTP 合同或 Computer Use 输入桥限制冒充 L2-L5 通过。
