---
kind: formal-evidence
campaign: WRK-087
date: 2026-08-27
status: green-after-fix
---

# 生图元数据与回合收尾 stop-and-fix

## 红场

正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-010636`
使用真实 App 和真实受管网关完成生图。生成工具的 durable tool-result 正确返回真实
`attachmentId`，但随后用户可见的中文元数据表把该字段显示为“这个输入”。同时，
消息 durable close 已完成而 Composer 仍停在“停止生成”，无法继续发送。

这两项均为产品缺陷：前者让用户无法信任元数据，后者让回合看起来永久进行中。原始
SSE、LLM wire、后端日志和录屏保留在该 session；wire 证明真实附件 ID 来自工具回执，
不是生成上游返回了错误值。

## 修复

- `backend/internal/app/loop/redact.go` 的二列表格脱敏规则现在识别
  `attachmentId`/`imageId`/`mediaId`，并在值变为 opaque 占位后物理移除整行；中文
  占位词也被视为不可用值，不再落成用户可见的元数据。
- `backend/internal/app/loop/redact_test.go` 增加完整文本和跨 provider 分片的回归，
  防止中间 SSE 帧重新泄漏或渲染坏行。
- `frontend/lib/features/chat/model/conversation_transcript.dart` 修正已由 REST
  水化的 user echo 与稍后加入的 optimistic pending bubble 的重叠归并；即使 durable
  节点已在 settled 集合，也必须消费 pending，避免 Composer 永久保持停止态。

## 绿场

Session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-012031` 使用修复后
二进制、真实 Flutter App、真实 managed gateway、Computer Use 逐步操作和全程录屏完成：

- 用户目的达成：真实生成宽幅深蓝夜空/暖黄月亮海报，图片卡显示真实预览、文件名、
  1344×768 和约 1.2 MB；打开工具卡后可继续查看大图。
- 用户可见元数据表只保留 `filename`、`mime`、`width × height`、`sizeBytes`、`aspect`、
  `source`、`provider` 等可读字段，`attachmentId` 机器字段整行消失，不再显示“这个输入”。
- Composer 在消息 close 后恢复可发送状态；App accessibility tree 不再包含“停止生成”。
- LLM tap 记录真实 `/v1/chat/completions`、`/v1/images/generations`、三步
  `/v1/media/uploads` 请求，全部返回成功；tool-result 仍保留真实 attachment ID。
- messages durable seq `1..14` 单调且无缺口，工具调用、工具结果、最终文本和
  `message close(status=completed, stopReason=end_turn)` 均存在；notifications 自动标题
  帧随后到达。
- `rig-check.sh` 在 session 存活期间通过五通道物理检查；录屏为 `115.456667s`，
  `2784×1808 / 60fps`。`backend.log` 无 WARN/ERROR/panic，`frontend.log` 无 Flutter/Dart/
  RenderFlex/Unhandled/Exception 错误，`rig-down.sh` 收台无残留。

## 判定

这是对 `TOOL-119` 生图和 `SURF-070` 媒体卡路径的代码变更后 revalidation；不新增 50 格
批次。红场问题均在绿场消失，opaque ID 仍只存在于 tool-result、审计和 LLM 线缆，不进入
用户 prose；Composer 收尾、App 画面、SSE durable truth 与真实上游请求一致。
