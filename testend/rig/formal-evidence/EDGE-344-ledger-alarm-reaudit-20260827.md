# EDGE-344 账本/警报独立复审

本次登记 `EDGE-344` 的 L2 一个新格。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-220925/`，录屏为 H.264、60fps、
`2784x1808`、`156.893333s`；录屏、backend、SSE、LLM 与 frontend journal 均已封口保存。

## 复核证据

- 全新隔离 workspace 的首次 managed provision 指向关闭回环 gateway，失败日志是构造“无受管
  install”的预期结果；随后 workspace 只创建一条 BYOK qwen key，`model-capabilities` 只有
  `qwen-plus`，无 `anselm` key。
- 真实 App 模型菜单只显示 `自动` 与 `qwen-plus · EDGE-344 BYOK`。两轮生成能力探测均只
  返回普通文本完成态，Composer 可继续使用。
- provider wire 的第二轮在真实请求中记录 13 个基础工具名，明确不含
  `generate_image`、`generate_speech`、`generate_video`；第一轮为零工具请求。SSE 两轮均为
  user/assistant text/completed 链，未出现 tool call/result 或生成附件。
- `rig-check.sh` 通过五通道；backend/frontend 没有应用级 ERROR、panic、fatal 或 Flutter
  运行时红线。预期的两条 free-tier install WARN 与测试前置条件一致，未被当成产品错误。
- `TestGenerateImage_HonestAbsence`、`TestGenerateVideo_HonestAbsenceWithoutAKey`、
  `TestSpeech_HonestAbsence` 定向测试通过；`anchors.py`=`10/10`，`gen_coverage.py --check`=`848/848/0`。

## 警报处置

`alarms.py check` 在新裁决后打开 `gap-too-fast` 与 `discovery-collapse`。前者是连续账本动作
的时间统计，后者是本批没有 fail；独立复核确认两条信号均不代表跳过证据。本复审不修改阈值、
算法、法典、锚点或覆盖范围，只在证据核对完成后按原机制串行 ack；后续新裁决仍重新计算曲线。
