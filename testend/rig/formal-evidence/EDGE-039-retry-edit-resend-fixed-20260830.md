# EDGE-039 `:retry` 编辑重发：入口与版本链修复后真实证据（2026-08-30）

## 结论

**L2 PASS（transport / durable lineage）。** 修复后，最后用户回合的
`Edit and resend` 入口在真实 App 中常显；点击后打开原地编辑面，点击 `Resend`
实际调用 `POST /api/v1/conversations/{id}:retry`，而不是普通消息发送。

## 五通道定位

- Rig session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-163538`
- Workspace：`ws_bf9aed46483af41a`
- Conversation：`cv_71d2ab59657afec1`
- Frame：最后用户回合下方常显 `Edit and resend`；编辑面显示原地文本框与
  `Cancel` / `Resend`；提交后版本指示为 `2/2`，旧回答仍可翻回。
- Backend journal：`16:38:35.442` 记录
  `POST /api/v1/conversations/cv_71d2ab59657afec1:retry`，状态 `202`。
- REST truth：旧 user `msg_f7135bb552878c4c` 的 `supersededBy` 指向新 user
  `msg_c60842c5b4f1fcb7`；旧 assistant `msg_a6748b129ea2526a` 的
  `supersededBy` 指向新 assistant `msg_c89c3de0889fad7a`；新 assistant 的
  `attrs.retryOf` 指向旧 assistant。旧行仍可读，没有删除。
- SSE：messages 流记录 retry 后的新 durable user/assistant 版本及连续终态，
  未出现普通 `/messages` 回合替代版本链。
- LLM wire：retry 回合进入第二次模型请求；请求来自 retry 路由，不是普通发送路由。
- Frontend console / backend redline：本 session 无新增 Flutter 报错、panic 或
  `5xx`；被停止的模型工具链以产品可见 `Stopped` 收口。

## 限制与后续

本 session 使用 Computer Use 的 AX `set_value` 替换文本时，AX 显示值与 Flutter
controller 未同步，导致最终提交文本为“旧文本+编辑后缀”；这属于录制工具的
输入桥限制，不作为“精确文本编辑”视觉/输入金标准证据。编辑重发的 controller
传值已由 `chat_transcript_test.dart` 覆盖；L3 仍需人工使用真实键盘完成全选/改写，
但不会阻塞继续清扫其它自主 coverage。

## 修复

`chat_transcript.dart` 让 `canEdit` 的最后用户回合常显动作排；同步更新了动作排
契约文档，并加入 widget 回归断言，防止入口重新退化为仅 hover 可发现。
