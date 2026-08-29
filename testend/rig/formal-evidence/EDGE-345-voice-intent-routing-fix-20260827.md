# EDGE-345 音色登记意图路由修复复验

## 结论

本证据只证明产品入口的 stop-and-fix 已生效：全新对话中，用户仅表达“把这个上传的音频登记成名为
`acceptance-voice` 的声音”，模型直接选择 `enroll_voice`，没有调用 `inspect_media`，并在任何上游写入前
展示 `dangerous` 确认。用户未批准本次测试执行，故本次没有新增受管音色，也不能把本证据写成完整登记链的绿判。

上一轮红证据仍保留：用户同样表达登记意图时，模型先调用 `inspect_media`，并错误地把“无法转录”当成阻塞。
另一个旧对话复验还显示，模型曾仅凭历史成功结果声称新请求“已经完成”，没有重新验证当前请求。

## 修复

- `backend/internal/app/chat/prompt.go` 增加音频意图分流规则：登记/克隆是文件操作，直接使用精确附件 ID，
  不先检查或转录；转录/理解才走 `inspect_media`。
- 同文件增加历史结果规则：新的变更请求不能仅凭相似历史操作报告本次完成，必须重新核验或执行。
- `backend/internal/app/tool/generate/enroll.go` 的工具描述增加同一文件操作边界，避免模型因无原生音频输入而
  误选检查工具。
- `docs/references/backend/foundation/stream-llm.md` 同步记录该产品契约。

## 真实台架

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-203732`
- manifest: 真实 Debug macOS App、conductor 直接启动的 Go sidecar、真实 `https://api.anselm.website`、
  独立 `ssetap`、独立 `llmtap`、窗口录屏均由同一台架持有。
- `rig-check.sh`: 五通道通过；录屏 `189.416667s / 2784x1808 / 60fps`。
- 前端 journal 无 Flutter/Dart/RenderFlex/Unhandled 应用红线；后端 journal 无 panic/fatal/error/warn。
- messages durable seq `1..23`，notifications durable seq `1..2`；LLM tap 中相关 chat 请求均 HTTP 200。
- 新请求的 LLM wire 只出现一次 `enroll_voice` 调用，参数为本次上传附件的精确 ID 和
  `acceptance-voice`；没有 `inspect_media`，也没有 `generate_speech`。
- Computer Use 画面显示 `等待确认 / enroll_voice` 与 `拒绝 / 总是允许 / 允许` 三个动作；实际点击了“拒绝”，
  UI 收口为“已取消注册”，未产生上游写入。

## 仍未宣称的部分

首次自然语言“登记并随后合成”的完整用户目的，需要一个新的、未占用的音色名并点击不可逆的受管登记确认。
本次按资源安全边界没有执行该动作；此前已有音色的真实合成成功证据仍在
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-014259`，但不能替代本次自然语言完整链路。
