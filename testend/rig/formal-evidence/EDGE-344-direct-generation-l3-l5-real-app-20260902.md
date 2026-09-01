# EDGE-344 · 直连生成整体退场 · L3-L5 真实 App 验收

## Session

- session=`/private/tmp/anselm-rig-formal-20260902-14/sessions/20260902-033025`
- workspace=`ws_ac23f070580f235b`
- App=`anselm`，conductor-owned 窗口录屏=`screen.mov`，`3104x1848`，`60fps`，`147.316667s`
- recorder、backend、SSE witness、LLM recorder、Flutter console 均由同一 session 归属；`rig-check.sh` 在真实路径前后全绿，`rig-down.sh` 正常封口。

## Product path

在无 managed install、只配置 BYOK qwen key 的 workspace 中，从真实 App 新建对话，普通键入：

`I want to generate an image. Please explain how to enable it.`

发送后，真实 App 展示原文与明确的中文缺席说明：当前工作区没有可用的图像生成能力，并指向
`Settings → Models & keys → Image generation`。没有生成入口、假成功附件、必败工具卡或内部错误码；Composer
回到可继续输入状态。

## Five-channel cross-check

- Frame: 录屏与最终截图显示稳定的对话终态；用户气泡、助手说明、Composer 和导航均可见，未出现空白加载层、假生成卡或遮挡。
- Backend: `backend.log` 无应用 ERROR、panic、fatal；仅有构造无 managed install 时预期的 free-tier provision WARN。
- SSE: `sse.jsonl` 记录同一 conversation `cv_b38854af0526ab95` 的 user close、assistant text close、assistant message close；durable seq 单调，未出现 tool call/result 或媒体附件。
- Frontend: `frontend.log` 无 Flutter/Dart/RenderFlex/Unhandled/Exception；仅有 macOS 输入法系统诊断 `IMKCFRunLoopWakeUpReliable`。
- LLM wire: `llm-bodies/00002_v1_chat_completions.bin` 经 JSON 解析为 model `qwen3.7-plus`、`stream=true`、`toolCount=13`，最后一条 user content 与 App 原文逐字一致；response status=200。

## Judgement

- L3 smooth / A1: 发送后出现用户气泡并进入生成流程，fixture chat completion status=200；终态 Composer 可继续输入。录屏中未见发送后无反馈或卡死。
- L4 craft / C4: final frame 保持现有圆角尺度阶梯、内容列对齐、单一 Composer 框和稳定留白；没有为“能力缺席”新增不一致控件或视觉噪声。
- L5 discoverability / G1: 普通用户无需知道工具名或内部错误码，助手直接说明缺少能力并给出产品内可导航的 Settings 路径；UI 不暴露一个不可用入口。

## Instrument note

正式路径使用普通键入，并由 App 气泡、SSE close、LLM body 三处逐字复核通过。此前 Computer Use `paste` 桥接探针出现 AX 树显示值与 Flutter 实际 controller 不一致；后端 REST 对照能原样保存 Unicode、下划线，故该探针不计入产品判定。
